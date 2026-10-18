//
//  BattleRecord.swift
//  OPToolkit
//
//  対戦履歴の1戦ぶんの記録。
//  - 相手のリーダーはCardの実体ではなくカード番号で持つ（StoredDeckと同じ考え方。
//    Cardにフィールドを足したり、cards.jsonを更新したりしても、保存済みの履歴が読めなくなることがない）。
//  - createdAtは画面には出さず、表示順（新しい順）を決めるためだけに自動で保存する。
//  - 大会名は空文字なら「大会名なし」として扱う。
//

import Foundation

/// じゃんけんの結果（あいこは再度行うので、勝ち・負けの2つだけ）
enum JankenResult: String, Codable, CaseIterable, Identifiable {
    case win
    case lose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win: return "勝ち"
        case .lose: return "負け"
        }
    }

    var shortLabel: String {
        switch self {
        case .win: return "勝"
        case .lose: return "負"
        }
    }
}

/// 先攻・後攻
enum TurnOrder: String, Codable, CaseIterable, Identifiable {
    case first
    case second

    var id: String { rawValue }

    var label: String {
        switch self {
        case .first: return "先攻"
        case .second: return "後攻"
        }
    }
}

/// 対戦の勝敗（大会では時間切れの引き分けがあるので、引き分けも持つ）
enum MatchResult: String, Codable, CaseIterable, Identifiable {
    case win
    case lose
    case draw

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win: return "勝ち"
        case .lose: return "負け"
        case .draw: return "引き分け"
        }
    }

    var shortLabel: String {
        switch self {
        case .win: return "勝"
        case .lose: return "負"
        case .draw: return "分"
        }
    }
}

struct BattleRecord: Identifiable, Codable, Hashable {
    let id: UUID
    /// どのデッキで戦ったか（履歴はデッキごとに持つ）
    var deckID: UUID
    /// 大会名。空文字は「大会名なし」
    var tournamentName: String
    /// 対戦相手のリーダーのカード番号（未設定ならnil）
    var opponentLeaderNumber: String?
    var janken: JankenResult
    var turnOrder: TurnOrder
    var result: MatchResult
    var memo: String
    /// 記録した日時。表示順のためだけに使う（画面には出さない）
    let createdAt: Date

    init(
        id: UUID = UUID(),
        deckID: UUID,
        tournamentName: String = "",
        opponentLeaderNumber: String? = nil,
        janken: JankenResult = .win,
        turnOrder: TurnOrder = .first,
        result: MatchResult = .win,
        memo: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.deckID = deckID
        self.tournamentName = tournamentName
        self.opponentLeaderNumber = opponentLeaderNumber
        self.janken = janken
        self.turnOrder = turnOrder
        self.result = result
        self.memo = memo
        self.createdAt = createdAt
    }
}

// MARK: - 成績の集計

struct BattleSummary: Equatable {
    private(set) var wins = 0
    private(set) var losses = 0
    private(set) var draws = 0

    init(records: [BattleRecord]) {
        for record in records {
            switch record.result {
            case .win: wins += 1
            case .lose: losses += 1
            case .draw: draws += 1
            }
        }
    }

    /// 勝率。引き分けは分母に含めない（勝ち ÷ (勝ち＋負け)）。勝敗がついた試合が無ければnil
    var winRate: Double? {
        let decided = wins + losses
        return decided == 0 ? nil : Double(wins) / Double(decided)
    }

    /// 例: 「3勝1敗」「3勝1敗1分」
    var text: String {
        "\(wins)勝\(losses)敗" + (draws > 0 ? "\(draws)分" : "")
    }

    /// 例: 「勝率 75%」
    var winRateText: String? {
        guard let winRate else { return nil }
        return "勝率 \(Int((winRate * 100).rounded()))%"
    }
}
