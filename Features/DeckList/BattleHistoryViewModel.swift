//
//  BattleHistoryViewModel.swift
//  OPToolkit
//

import Foundation

/// 大会1つぶんの表示用のまとまり（大会＋その中の記録）
struct BattleTournamentSection: Identifiable {
    let tournament: BattleTournament
    /// 回戦の小さい順
    let records: [BattleRecord]
    /// 「対戦を記録」を押したときに入る回戦
    let nextRound: Int

    var id: UUID { tournament.id }
    var summary: BattleSummary { BattleSummary(records: records) }
}

/// 全画面で開く編集画面の種類（大会の作成・名前変更／対戦記録の追加・編集）。
/// .fullScreenCover(item:) を2つ並べると競合しうるので、1つのenumにまとめて1か所で出す。
enum BattleHistorySheet: Identifiable {
    case tournament(tournament: BattleTournament, isNew: Bool)
    case record(record: BattleRecord, isNew: Bool, tournamentName: String)

    /// idはどの種類でも同じ固定値にしている。
    /// 大会を作成した直後に、同じ全画面表示のまま「1回戦の記録」へ中身だけ切り替えるため
    /// （idが変わると、閉じて開き直す動きになり、表示が不安定になりやすい）。
    var id: String { "battle-history-editor" }
}

/// 削除確認アラートの対象
enum BattlePendingDeletion {
    case record(BattleRecord)
    case tournament(BattleTournament, recordCount: Int)
}

@Observable
final class BattleHistoryViewModel {
    let deck: Deck

    /// 開いている編集画面（nilなら閉じている）
    var activeSheet: BattleHistorySheet?
    /// 削除確認アラート用
    var pendingDeletion: BattlePendingDeletion?
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

    /// このデッキの大会ごとのまとまり（新しい大会が上。大会の中は回戦の順）
    var sections: [BattleTournamentSection] {
        store.tournaments(for: deck.id).map { tournament in
            BattleTournamentSection(
                tournament: tournament,
                records: store.records(in: tournament.id),
                nextRound: store.nextRound(in: tournament.id)
            )
        }
    }

    /// このデッキの通算成績
    var summary: BattleSummary {
        BattleSummary(records: store.records(for: deck.id))
    }

    /// 大会名の選択肢（過去に作った大会名）
    var tournamentNames: [String] {
        store.recentTournamentNames()
    }

    func leader(for record: BattleRecord) -> Card? {
        record.opponentLeaderNumber.flatMap { leadersByNumber[$0] }
    }

    // MARK: - 読み込み

    func loadLeaders() async {
        let cards = (try? await cardRepository.fetchAll()) ?? []
        leadersByNumber = Dictionary(
            cards.filter { $0.type == .leader }.map { ($0.cardNumber, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - 大会の作成・名前変更

    func beginAddTournament() {
        let tournament = BattleTournament(deckID: deck.id, name: "")
        activeSheet = .tournament(tournament: tournament, isNew: true)
    }

    func beginRenameTournament(_ tournament: BattleTournament) {
        activeSheet = .tournament(tournament: tournament, isNew: false)
    }

    func saveTournament(_ tournament: BattleTournament, isNew: Bool) {
        var tournament = tournament
        // 前後の空白だけ違う大会名が別の大会になるのを防ぐ
        tournament.name = tournament.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tournament.name.isEmpty else { return }

        perform {
            if isNew {
                try store.addTournament(tournament)
            } else {
                try store.updateTournament(tournament)
            }
        }

        if isNew {
            // 大会を作ったら、そのまま1回戦の記録に進む（大会作成後に「1回戦の対戦を記録」を押す手間を省く）。
            // 1回戦の画面でキャンセルしても、大会は残る（あとから「1回戦の対戦を記録」で追加できる）。
            beginAddRecord(to: tournament)
        } else {
            activeSheet = nil
        }
    }

    // MARK: - 対戦記録の追加・編集

    /// 大会の中に新しい記録を追加する。回戦は、その大会の次の回戦が自動で入る。
    func beginAddRecord(to tournament: BattleTournament) {
        let record = BattleRecord(
            deckID: deck.id,
            tournamentID: tournament.id,
            round: store.nextRound(in: tournament.id)
        )
        activeSheet = .record(record: record, isNew: true, tournamentName: tournament.name)
    }

    func beginEditRecord(_ record: BattleRecord, in tournament: BattleTournament) {
        activeSheet = .record(record: record, isNew: false, tournamentName: tournament.name)
    }

    func saveRecord(_ record: BattleRecord, isNew: Bool) {
        perform {
            if isNew {
                try store.addRecord(record)
            } else {
                try store.updateRecord(record)
            }
        }
        activeSheet = nil
    }

    func cancelEditing() {
        activeSheet = nil
    }

    // MARK: - 削除

    func requestDeleteRecord(_ record: BattleRecord) {
        pendingDeletion = .record(record)
    }

    func requestDeleteTournament(_ tournament: BattleTournament) {
        let count = store.records(in: tournament.id).count
        pendingDeletion = .tournament(tournament, recordCount: count)
    }

    func confirmDelete() {
        guard let deletion = pendingDeletion else { return }
        switch deletion {
        case .record(let record):
            perform { try store.deleteRecord(record) }
        case .tournament(let tournament, _):
            perform { try store.deleteTournament(tournament) }
        }
        pendingDeletion = nil
    }

    func cancelDelete() {
        pendingDeletion = nil
    }

    /// 削除確認アラートの見出し
    var deletionTitle: String {
        switch pendingDeletion {
        case .record(let record)?:
            return "\(record.round)回戦の記録を削除しますか？"
        case .tournament(let tournament, _)?:
            return "「\(tournament.name)」を削除しますか？"
        case nil:
            return ""
        }
    }

    /// 削除確認アラートの説明
    var deletionMessage: String {
        switch pendingDeletion {
        case .tournament(_, let recordCount)? where recordCount > 0:
            return "この大会の対戦記録\(recordCount)件もすべて削除されます。この操作は取り消せません"
        default:
            return "この操作は取り消せません"
        }
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
