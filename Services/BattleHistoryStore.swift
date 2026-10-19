//
//  BattleHistoryStore.swift
//  OPToolkit
//
//  対戦履歴（大会と対戦記録）の保存/読み込みを担う層。
//  Application Support/OPToolkit/battle_history.json に、全デッキぶんをまとめてJSONで保存する
//  （大会・記録がdeckIDを持つので、デッキごとの履歴は絞り込みで取り出す）。
//
//  - 読み込みは init で同期的に行う（カード番号しか持たない小さなファイルなので、
//    DeckStoreのような prepare() は要らない）。カード実体への復元は、画面側でカードDBを引いて行う。
//  - @Observable にしているので、tournaments / records を読んでいる画面は、変更で自動で更新される。
//  - 保存系の操作は、ディスクへの書き込みに失敗するとBattleHistoryStoreError.writeFailedを投げる。
//    メモリ上の状態は更新済みなので、失敗後に画面を再読み込みしても表示は食い違わない（DeckStoreと同じ）。
//  - FavoritesStore・DeckStoreと同様、アプリ全体で1つだけ作って共有する（RootViewで作って渡す）。
//
//  ファイル形式:
//  - version 2（現行）: { version, tournaments, records }
//  - version 1（大会を持たず、記録が大会名の文字列だけを持っていた初版）: 読み込み時に
//    「デッキ＋大会名」ごとに大会を作り、記録を作成順に1回戦、2回戦…として移行する。
//    移行前のファイルは battle_history.v1.backup.json に残す。
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
    private static let currentVersion = 2

    /// 全デッキぶんの大会（並びは保存順。表示順は tournaments(for:) が決める）
    private(set) var tournaments: [BattleTournament]
    /// 全デッキぶんの記録
    private(set) var records: [BattleRecord]

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        let loaded = Self.load(from: url)
        self.tournaments = loaded.tournaments
        self.records = loaded.records
        // 旧形式から移行したときは、すぐ新形式で保存し直す（移行前のファイルはバックアップ済み）
        if loaded.migrated {
            try? persist()
        }
    }

    // MARK: - 読み取り

    /// そのデッキの大会（新しい大会が先頭）
    func tournaments(for deckID: UUID) -> [BattleTournament] {
        tournaments
            .filter { $0.deckID == deckID }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// その大会の記録（回戦の小さい順。同じ回戦なら記録した順）
    func records(in tournamentID: UUID) -> [BattleRecord] {
        records
            .filter { $0.tournamentID == tournamentID }
            .sorted { lhs, rhs in
                if lhs.round != rhs.round { return lhs.round < rhs.round }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// そのデッキの全記録（成績の集計用。並びは保存順）
    func records(for deckID: UUID) -> [BattleRecord] {
        records.filter { $0.deckID == deckID }
    }

    /// その大会に次に追加する記録の回戦。今ある最大の回戦＋1
    /// （途中の記録を消しても、回戦が重複しないようにするため、件数ではなく最大値で決める）
    func nextRound(in tournamentID: UUID) -> Int {
        let maxRound = records
            .filter { $0.tournamentID == tournamentID }
            .map(\.round)
            .max() ?? 0
        return maxRound + 1
    }

    /// 過去に使った大会名（新しく作ったものが先頭・重複なし）。大会を作るときの選択肢に使う。
    /// デッキをまたいで共通（同じ大会に別のデッキで出ることもあるため）。
    func recentTournamentNames(limit: Int = 30) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for tournament in tournaments.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard !tournament.name.isEmpty, seen.insert(tournament.name).inserted else { continue }
            names.append(tournament.name)
            if names.count >= limit { break }
        }
        return names
    }

    // MARK: - 大会の書き込み

    func addTournament(_ tournament: BattleTournament) throws {
        // 書き込みに失敗して再試行された場合などに、同じ大会が二重に追加されないようにする
        if tournaments.contains(where: { $0.id == tournament.id }) {
            try updateTournament(tournament)
            return
        }
        tournaments.append(tournament)
        try persist()
    }

    func updateTournament(_ tournament: BattleTournament) throws {
        guard let index = tournaments.firstIndex(where: { $0.id == tournament.id }) else { return }
        tournaments[index] = tournament
        try persist()
    }

    /// 大会を削除する。その大会の記録もまとめて消す。
    func deleteTournament(_ tournament: BattleTournament) throws {
        tournaments.removeAll { $0.id == tournament.id }
        records.removeAll { $0.tournamentID == tournament.id }
        try persist()
    }

    // MARK: - 記録の書き込み

    func addRecord(_ record: BattleRecord) throws {
        if records.contains(where: { $0.id == record.id }) {
            try updateRecord(record)
            return
        }
        records.append(record)
        try persist()
    }

    func updateRecord(_ record: BattleRecord) throws {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        try persist()
    }

    func deleteRecord(_ record: BattleRecord) throws {
        records.removeAll { $0.id == record.id }
        try persist()
    }

    /// デッキを削除したときに、そのデッキの大会と記録をまとめて消す
    func deleteAll(for deckID: UUID) throws {
        guard tournaments.contains(where: { $0.deckID == deckID })
                || records.contains(where: { $0.deckID == deckID }) else { return }
        tournaments.removeAll { $0.deckID == deckID }
        records.removeAll { $0.deckID == deckID }
        try persist()
    }

    // MARK: - ファイル入出力

    private struct BattleHistoryFile: Codable {
        var version: Int
        var tournaments: [BattleTournament]
        var records: [BattleRecord]
    }

    /// version 1（初版）の記録。大会名の文字列だけを持っていた。
    private struct LegacyRecord: Codable {
        var id: UUID
        var deckID: UUID
        var tournamentName: String
        var opponentLeaderNumber: String?
        var janken: JankenResult
        var turnOrder: TurnOrder
        var result: MatchResult
        var memo: String
        var createdAt: Date
    }

    private struct LegacyBattleHistoryFile: Codable {
        var version: Int
        var records: [LegacyRecord]
    }

    private struct LoadedHistory {
        var tournaments: [BattleTournament] = []
        var records: [BattleRecord] = []
        var migrated = false
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("OPToolkit", isDirectory: true)
            .appendingPathComponent("battle_history.json")
    }

    private static func load(from url: URL) -> LoadedHistory {
        // ファイルが無い（初回起動）場合は空で始める
        guard let data = try? Data(contentsOf: url) else { return LoadedHistory() }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 現行形式（version 2）
        if let file = try? decoder.decode(BattleHistoryFile.self, from: data) {
            return LoadedHistory(tournaments: file.tournaments, records: file.records)
        }

        // 初版（version 1）の形式なら、大会を作って移行する
        if let legacy = try? decoder.decode(LegacyBattleHistoryFile.self, from: data) {
            let backup = url.deletingLastPathComponent().appendingPathComponent("battle_history.v1.backup.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            return migrate(legacy)
        }

        // どちらでも読めない場合、そのままだと次の保存で上書きして消えてしまうので、退避してから空で始める
        print("BattleHistoryStore: battle_history.json を読み込めませんでした")
        let backup = url.deletingLastPathComponent().appendingPathComponent("battle_history.corrupt.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        return LoadedHistory()
    }

    /// 初版の記録を、「デッキ＋大会名」ごとの大会にまとめ直す。
    /// 回戦は、その大会の中の記録の作成順に、1回戦、2回戦…と振る。大会名が空だったものは「大会名なし」にする。
    private static func migrate(_ legacy: LegacyBattleHistoryFile) -> LoadedHistory {
        struct GroupKey: Hashable {
            let deckID: UUID
            let name: String
        }

        var result = LoadedHistory(migrated: true)
        let grouped = Dictionary(grouping: legacy.records) { GroupKey(deckID: $0.deckID, name: $0.tournamentName) }

        for (key, group) in grouped {
            let ordered = group.sorted { $0.createdAt < $1.createdAt }
            let tournament = BattleTournament(
                deckID: key.deckID,
                name: key.name.isEmpty ? "大会名なし" : key.name,
                createdAt: ordered.first?.createdAt ?? Date()
            )
            result.tournaments.append(tournament)

            for (index, old) in ordered.enumerated() {
                result.records.append(
                    BattleRecord(
                        id: old.id,
                        deckID: old.deckID,
                        tournamentID: tournament.id,
                        round: index + 1,
                        opponentLeaderNumber: old.opponentLeaderNumber,
                        janken: old.janken,
                        turnOrder: old.turnOrder,
                        result: old.result,
                        memo: old.memo,
                        createdAt: old.createdAt
                    )
                )
            }
        }
        return result
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
            let file = BattleHistoryFile(
                version: Self.currentVersion,
                tournaments: tournaments,
                records: records
            )
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            print("BattleHistoryStore: 対戦履歴の保存に失敗しました: \(error)")
            throw BattleHistoryStoreError.writeFailed(error)
        }
    }
}
