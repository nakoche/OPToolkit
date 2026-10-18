//
//  BattleHistoryViewModel.swift
//  OPToolkit
//

import Foundation

/// 大会名ごとにまとめた記録
struct BattleRecordGroup: Identifiable {
    /// 空文字は「大会名なし」
    let tournamentName: String
    /// 新しい順
    let records: [BattleRecord]

    var id: String { tournamentName }
    var title: String { tournamentName.isEmpty ? "大会名なし" : tournamentName }
    var summary: BattleSummary { BattleSummary(records: records) }
}

/// 記録の追加・編集画面を開くための対象（fullScreenCover(item:)に渡す）
struct BattleEditorTarget: Identifiable {
    let record: BattleRecord
    let isNew: Bool

    var id: UUID { record.id }
}

@Observable
final class BattleHistoryViewModel {
    let deck: Deck

    /// 追加・編集画面（nilなら閉じている）
    var editorTarget: BattleEditorTarget?
    /// 削除確認アラート用
    var pendingDelete: BattleRecord?
    /// 保存失敗の通知用
    var errorMessage: String?

    /// 相手リーダーのカード番号 → Card（行の画像・名前の表示用。読み込み完了までは空）
    private(set) var leadersByNumber: [String: Card] = [:]

    private let store: BattleHistoryStore
    private let cardRepository: CardRepositoryProtocol

    init(
        deck: Deck,
        store: BattleHistoryStore,
        cardRepository: CardRepositoryProtocol = CardRepository()
    ) {
        self.deck = deck
        self.store = store
        self.cardRepository = cardRepository
    }

    // MARK: - 表示用

    /// このデッキの全記録
    var records: [BattleRecord] {
        store.records(for: deck.id)
    }

    /// このデッキの通算成績
    var summary: BattleSummary {
        BattleSummary(records: records)
    }

    /// 大会名ごとのグループ。グループは最後に記録した順（新しい大会が上）、
    /// グループ内も新しい順。同時刻のときは並びが入れ替わらないようidで決める。
    var groups: [BattleRecordGroup] {
        Dictionary(grouping: records, by: \.tournamentName)
            .map { name, records in
                BattleRecordGroup(tournamentName: name, records: records.sorted(by: Self.isNewer))
            }
            .sorted { lhs, rhs in
                guard let l = lhs.records.first, let r = rhs.records.first else { return false }
                return Self.isNewer(l, r)
            }
    }

    /// 大会名の選択肢（過去に使った大会名）
    var tournamentNames: [String] {
        store.recentTournamentNames()
    }

    func leader(for record: BattleRecord) -> Card? {
        record.opponentLeaderNumber.flatMap { leadersByNumber[$0] }
    }

    private static func isNewer(_ lhs: BattleRecord, _ rhs: BattleRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    // MARK: - 読み込み

    func loadLeaders() async {
        let cards = (try? await cardRepository.fetchAll()) ?? []
        leadersByNumber = Dictionary(
            cards.filter { $0.type == .leader }.map { ($0.cardNumber, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - 追加・編集

    /// 新しい記録を始める。大会中に続けて記録しやすいよう、
    /// このデッキで最後に記録した大会名を最初から入れておく（消せば「大会名なし」になる）。
    func beginAdd() {
        let lastTournamentName = records.max(by: { Self.isNewer($1, $0) })?.tournamentName ?? ""
        let record = BattleRecord(deckID: deck.id, tournamentName: lastTournamentName)
        editorTarget = BattleEditorTarget(record: record, isNew: true)
    }

    func beginEdit(_ record: BattleRecord) {
        editorTarget = BattleEditorTarget(record: record, isNew: false)
    }

    func save(_ record: BattleRecord, isNew: Bool) {
        var record = record
        // 前後の空白だけ違う大会名が別グループになるのを防ぐ
        record.tournamentName = record.tournamentName.trimmingCharacters(in: .whitespacesAndNewlines)
        perform {
            if isNew {
                try store.add(record)
            } else {
                try store.update(record)
            }
        }
        editorTarget = nil
    }

    func cancelEditing() {
        editorTarget = nil
    }

    // MARK: - 削除

    func requestDelete(_ record: BattleRecord) {
        pendingDelete = record
    }

    func confirmDelete() {
        guard let record = pendingDelete else { return }
        perform { try store.delete(record) }
        pendingDelete = nil
    }

    func cancelDelete() {
        pendingDelete = nil
    }

    // MARK: - 保存エラーの共通処理

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
