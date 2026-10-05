//
//  DeckStore.swift
//  OPToolkit
//
//  デッキの保存/読み込みを担う層。Application Support/OPToolkit/decks.json にJSONで保存する。
//  保存するのはカード番号＋枚数だけ（StoredDeck）。Cardの実体はcards.jsonから復元する。
//
//  使い方:
//  - 保存済みデッキの読み込み自体は init で同期的に行う（小さなファイルなので）。
//  - Cardへの復元にはカードDB（非同期）が必要なので、画面表示時に prepare() を1回呼ぶ。
//    prepare() 完了までの fetchAll() は空配列を返す。
//  - save/update/delete/reorder は、prepare() 前に呼ばれても保存済みデータを壊さない
//    （保存の正は `stored` で、復元済みの `decks` はその写し）。
//

import Foundation

protocol DeckStoreProtocol {
    /// 保存済みデッキをカードDBと突き合わせて復元する。2回目以降は何もしない。
    @MainActor func prepare() async
    func fetchAll() -> [Deck]
    /// 保存系の操作は、ディスクへの書き込みに失敗するとDeckStoreError.writeFailedを投げる。
    /// （メモリ上の状態は更新済みなので、失敗後に画面を再読み込みしても表示は食い違わない）
    func save(_ deck: Deck) throws
    func update(_ deck: Deck) throws
    func delete(_ deck: Deck) throws
    /// 一覧の並び順をまるごと保存する（ドラッグでの入れ替え確定時に呼ぶ）
    func reorder(_ decks: [Deck]) throws
}

enum DeckStoreError: LocalizedError {
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let underlying):
            return "デッキを端末に保存できませんでした。端末の空き容量を確認してください。（\(underlying.localizedDescription)）"
        }
    }
}

final class DeckStore: DeckStoreProtocol {
    private static let currentVersion = 1

    private let cardRepository: CardRepositoryProtocol
    private let fileURL: URL

    /// 永続化の正。カード番号＋枚数だけを持つ。
    private var stored: [StoredDeck]
    /// storedをカードDBと突き合わせて復元したもの（prepare()完了まで空）
    private var decks: [Deck] = []
    private var isPrepared = false
    /// cards.jsonに存在するカード番号（prepare()後に有効）。DBから消えたカードの判定に使う
    private var knownCardNumbers: Set<String> = []

    init(cardRepository: CardRepositoryProtocol = CardRepository(), fileURL: URL? = nil) {
        self.cardRepository = cardRepository
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.stored = Self.loadStored(from: url)
    }

    // MARK: - DeckStoreProtocol

    @MainActor
    func prepare() async {
        guard !isPrepared else { return }

        let cards = (try? await cardRepository.fetchAll()) ?? []
        guard !cards.isEmpty else {
            // カードDBを読めなかった場合は復元しない（復元できないデッキを編集・保存して
            // カード情報を失うのを避けるため）。次回のprepare()でやり直す。
            print("DeckStore: カードDBを読み込めなかったため、デッキを復元できません")
            return
        }

        let cardsByNumber = Dictionary(cards.map { ($0.cardNumber, $0) }, uniquingKeysWith: { first, _ in first })
        // await後の最新のstoredから復元する（待っている間にsave等があっても取りこぼさない）
        decks = stored.map { $0.resolve(using: cardsByNumber) }
        knownCardNumbers = Set(cardsByNumber.keys)
        isPrepared = true
    }

    func fetchAll() -> [Deck] {
        decks
    }

    func save(_ deck: Deck) throws {
        // 書き込みに失敗して再試行された場合などに、同じデッキが二重に追加されないようにする
        if stored.contains(where: { $0.id == deck.id }) {
            try update(deck)
            return
        }
        stored.append(StoredDeck(deck: deck))
        decks.append(deck)
        try persist()
    }

    func update(_ deck: Deck) throws {
        guard let storedIndex = stored.firstIndex(where: { $0.id == deck.id }) else { return }

        var updated = StoredDeck(deck: deck)
        if isPrepared {
            // cards.jsonに存在しないカード番号は画面に出てこず編集もできないので、
            // 保存し直しても消えないよう、元の保存内容からそのまま引き継ぐ
            // （カードがcards.jsonに戻れば、また表示される）。
            let old = stored[storedIndex]
            updated.entries += old.entries.filter { !knownCardNumbers.contains($0.cardNumber) }
            if updated.leaderCardNumber == nil,
               let oldLeader = old.leaderCardNumber,
               !knownCardNumbers.contains(oldLeader) {
                updated.leaderCardNumber = oldLeader
            }
        }
        stored[storedIndex] = updated

        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[index] = deck
        }
        try persist()
    }

    func delete(_ deck: Deck) throws {
        stored.removeAll { $0.id == deck.id }
        decks.removeAll { $0.id == deck.id }
        try persist()
    }

    func reorder(_ newOrder: [Deck]) throws {
        decks = newOrder

        // storedを新しい並びに合わせる。newOrderに含まれないもの（未復元など）は末尾に残す。
        let order = newOrder.map(\.id)
        let known = Set(order)
        let storedById = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        stored = order.compactMap { storedById[$0] } + stored.filter { !known.contains($0.id) }
        try persist()
    }

    // MARK: - ファイル入出力

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("OPToolkit", isDirectory: true)
            .appendingPathComponent("decks.json")
    }

    private static func loadStored(from url: URL) -> [StoredDeck] {
        // ファイルが無い（初回起動）場合は空で始める
        guard let data = try? Data(contentsOf: url) else { return [] }

        do {
            return try JSONDecoder().decode(DeckStoreFile.self, from: data).decks
        } catch {
            // 読めない場合、そのままだと次の保存で上書きして消えてしまうので、退避してから空で始める
            print("DeckStore: decks.json を読み込めませんでした: \(error)")
            let backup = url.deletingLastPathComponent().appendingPathComponent("decks.corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return []
        }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(DeckStoreFile(version: Self.currentVersion, decks: stored))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("DeckStore: デッキの保存に失敗しました: \(error)")
            throw DeckStoreError.writeFailed(error)
        }
    }
}
