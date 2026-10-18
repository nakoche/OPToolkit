//
//  BattleHistoryStore.swift
//  OPToolkit
//
//  対戦履歴の保存/読み込みを担う層。
//  Application Support/OPToolkit/battle_history.json に、全デッキぶんの記録をまとめてJSONで保存する
//  （各記録がdeckIDを持つので、デッキごとの履歴は絞り込みで取り出す）。
//
//  - 読み込みは init で同期的に行う（カード番号しか持たない小さなファイルなので、
//    DeckStoreのような prepare() は要らない）。カード実体への復元は、画面側でカードDBを引いて行う。
//  - @Observable にしているので、records を読んでいる画面は、追加・編集・削除で自動で更新される。
//  - 保存系の操作は、ディスクへの書き込みに失敗するとBattleHistoryStoreError.writeFailedを投げる。
//    メモリ上の状態は更新済みなので、失敗後に画面を再読み込みしても表示は食い違わない（DeckStoreと同じ）。
//  - FavoritesStore・DeckStoreと同様、アプリ全体で1つだけ作って共有する（RootViewで作って渡す）。
//

import Foundation

enum BattleHistoryStoreError: LocalizedError {
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let underlying):
            return "対戦履歴を端末に保存できませんでした。端末の空き容量を確認してください。（\(underlying.localizedDescription)）"
        }
    }
}

@Observable
final class BattleHistoryStore {
    private static let currentVersion = 1

    /// 全デッキぶんの記録（並びは保存順。表示順は呼び出し側でcreatedAtから決める）
    private(set) var records: [BattleRecord]

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.records = Self.load(from: url)
    }

    // MARK: - 読み取り

    func records(for deckID: UUID) -> [BattleRecord] {
        records.filter { $0.deckID == deckID }
    }

    /// 過去に使った大会名（新しく使ったものが先頭・重複なし・空は除く）。大会名の選択肢に使う。
    /// デッキをまたいで共通（同じ大会に別のデッキで出ることもあるため）。
    func recentTournamentNames(limit: Int = 30) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for record in records.sorted(by: { $0.createdAt > $1.createdAt }) {
            let name = record.tournamentName
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            names.append(name)
            if names.count >= limit { break }
        }
        return names
    }

    // MARK: - 書き込み

    func add(_ record: BattleRecord) throws {
        // 書き込みに失敗して再試行された場合などに、同じ記録が二重に追加されないようにする
        if records.contains(where: { $0.id == record.id }) {
            try update(record)
            return
        }
        records.append(record)
        try persist()
    }

    func update(_ record: BattleRecord) throws {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        try persist()
    }

    func delete(_ record: BattleRecord) throws {
        records.removeAll { $0.id == record.id }
        try persist()
    }

    /// デッキを削除したときに、そのデッキの履歴をまとめて消す
    func deleteAll(for deckID: UUID) throws {
        guard records.contains(where: { $0.deckID == deckID }) else { return }
        records.removeAll { $0.deckID == deckID }
        try persist()
    }

    // MARK: - ファイル入出力

    private struct BattleHistoryFile: Codable {
        var version: Int
        var records: [BattleRecord]
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("OPToolkit", isDirectory: true)
            .appendingPathComponent("battle_history.json")
    }

    private static func load(from url: URL) -> [BattleRecord] {
        // ファイルが無い（初回起動）場合は空で始める
        guard let data = try? Data(contentsOf: url) else { return [] }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BattleHistoryFile.self, from: data).records
        } catch {
            // 読めない場合、そのままだと次の保存で上書きして消えてしまうので、退避してから空で始める
            print("BattleHistoryStore: battle_history.json を読み込めませんでした: \(error)")
            let backup = url.deletingLastPathComponent().appendingPathComponent("battle_history.corrupt.json")
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
            encoder.dateEncodingStrategy = .iso8601
            let file = BattleHistoryFile(version: Self.currentVersion, records: records)
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            print("BattleHistoryStore: 対戦履歴の保存に失敗しました: \(error)")
            throw BattleHistoryStoreError.writeFailed(error)
        }
    }
}
