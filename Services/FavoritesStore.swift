//
//  FavoritesStore.swift
//  OPToolkit
//
//  お気に入り（♡）の保存/読み込みを担う層。
//  Application Support/OPToolkit/favorites.json に、カード番号の一覧をJSONで保存する。
//  （DeckStoreのdecks.jsonと同じ場所・同じ考え方）
//
//  - 保存するのはカード番号だけ。パラレルは "OP01-001_p1" のように別の番号なので、
//    ノーマルとパラレルは別々にお気に入りにできる。
//  - 読み込みは init で同期的に行う（小さなファイルなので）。
//  - @Observable にしているので、cardNumbers を読んでいる画面は、♡を切り替えると自動で更新される。
//  - 書き込みに失敗しても、メモリ上の状態は更新したままにする（アプリを閉じるまでは♡が効く）。
//    失敗はログに出すだけで、画面にエラーは出さない。
//  - デッキ画面のDeckStoreと同様、アプリ全体で1つだけ作って共有する（RootViewで作って渡す）。
//

import Foundation

@Observable
final class FavoritesStore {
    private static let currentVersion = 1

    /// お気に入りのカード番号
    private(set) var cardNumbers: Set<String>

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.cardNumbers = Self.load(from: url)
    }

    func isFavorite(_ card: Card) -> Bool {
        cardNumbers.contains(card.cardNumber)
    }

    /// お気に入りに入れる／外すを切り替えて、すぐ保存する
    func toggle(_ card: Card) {
        if cardNumbers.contains(card.cardNumber) {
            cardNumbers.remove(card.cardNumber)
        } else {
            cardNumbers.insert(card.cardNumber)
        }
        persist()
    }

    // MARK: - ファイル入出力

    private struct FavoritesFile: Codable {
        var version: Int
        var cardNumbers: [String]
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("OPToolkit", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }

    private static func load(from url: URL) -> Set<String> {
        // ファイルが無い（初回起動）場合は空で始める
        guard let data = try? Data(contentsOf: url) else { return [] }

        do {
            return Set(try JSONDecoder().decode(FavoritesFile.self, from: data).cardNumbers)
        } catch {
            // 読めない場合、そのままだと次の保存で上書きして消えてしまうので、退避してから空で始める
            print("FavoritesStore: favorites.json を読み込めませんでした: \(error)")
            let backup = url.deletingLastPathComponent().appendingPathComponent("favorites.corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return []
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let file = FavoritesFile(version: Self.currentVersion, cardNumbers: cardNumbers.sorted())
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            print("FavoritesStore: お気に入りの保存に失敗しました: \(error)")
        }
    }
}
