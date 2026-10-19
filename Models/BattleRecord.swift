//
//  BattleRecord.swift
//  OPToolkit
//
//  対戦履歴のモデル。「大会（BattleTournament）」の中に「対戦記録（BattleRecord）」が並ぶ。
//  - 大会は、大会名を決めて先に作る。対戦記録は、その大会の中に追加していく。
//  - 対戦記録には「何回戦目か」（round）を持たせる。追加するときは自動で次の回戦が入る。
//  - 勝敗・先攻後攻・じゃんけんは、どれも未選択（nil）にできる。
//    初期値を入れてしまうと、押し忘れたときに間違った内容が記録され、「記録しない」ことも選べないため。
//    未選択のものは、集計に含めず、履歴の行にも出さない。
//  - 相手のリーダーはCardの実体ではなくカード番号で持つ（StoredDeckと同じ考え方。
//    Cardにフィールドを足したり、cards.jsonを更新したりしても、保存済みの履歴が読めなくなることがない）。
//  - createdAtは画面には出さず、表示順（大会は新しい順）を決めるためだけに自動で保存する。
//
//  どの型にも nonisolated を付けている（Default Actor IsolationがMainActorのため）。
//  並べ替えの closure など、MainActor以外とみなされる文脈から使っても警告が出ないようにしている。
//

import Foundation

/// じゃんけんの結果（あいこは再度行うので、勝ち・負けの2つだけ）
nonisolated enum JankenResult: String, Codable, CaseIterable, Identifiable {
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
nonisolated enum TurnOrder: String, Codable, CaseIterable, Identifiable {
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

/// 対戦の勝敗（勝ち・負け・両負けの3つ）
nonisolated enum MatchResult: String, Codable, CaseIterable, Identifiable {
    case win
    case lose
    case doubleLoss

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win: return "勝ち"
        case .lose: return "負け"
        case .doubleLoss: return "両負け"
        }
    }

    var shortLabel: String {
        switch self {
        case .win: return "勝"
        case .lose: return "負"
        case .doubleLoss: return "両"
        }
    }

    /// 保存済みのデータを読む。以前は勝敗に「引き分け」（保存値 "draw"）があったので、
    /// 勝ち負けのつかない結果として、両負けに読み替える。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "win":
            self = .win
        case "lose":
            self = .lose
        case "doubleLoss", "draw":
            self = .doubleLoss
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "MatchResultとして読めない値です: \(raw)"
            )
        }
    }
}

/// 大会（対戦記録をまとめる入れ物）。デッキごとに持つ。
nonisolated struct BattleTournament: Identifiable, Codable, Hashable {
    let id: UUID
    /// どのデッキの大会か（履歴はデッキごとに持つ）
    var deckID: UUID
    var name: String
    /// 作成日時。大会の表示順（新しい順）のためだけに使う（画面には出さない）
    let createdAt: Date

    init(id: UUID = UUID(), deckID: UUID, name: String, createdAt: Date = Date()) {
        self.id = id
        self.deckID = deckID
        self.name = name
        self.createdAt = createdAt
    }
}

/// 1戦ぶんの記録
nonisolated struct BattleRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var deckID: UUID
    /// どの大会の記録か
    var tournamentID: UUID
    /// 何回戦目か（追加時に自動で次の回戦が入る。必要なら編集画面で直せる）
    var round: Int
    /// 対戦相手のリーダーのカード番号（未設定ならnil）
    var opponentLeaderNumber: String?
    /// じゃんけん・先攻後攻・勝敗は、未選択（nil）なら記録しない
    var janken: JankenResult?
    var turnOrder: TurnOrder?
    var result: MatchResult?
    var memo: String
    /// 記録した日時。同じ回戦が並んだときの順番のためだけに使う（画面には出さない）
    let createdAt: Date

    init(
        id: UUID = UUID(),
        deckID: UUID,
        tournamentID: UUID,
        round: Int,
        opponentLeaderNumber: String? = nil,
        janken: JankenResult? = nil,
        turnOrder: TurnOrder? = nil,
        result: MatchResult? = nil,
        memo: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.deckID = deckID
        self.tournamentID = tournamentID
        self.round = round
        self.opponentLeaderNumber = opponentLeaderNumber
        self.janken = janken
        self.turnOrder = turnOrder
        self.result = result
        self.memo = memo
        self.createdAt = createdAt
    }
}

// MARK: - 成績の集計

nonisolated struct BattleSummary: Equatable {
    private(set) var wins = 0
    private(set) var losses = 0
    private(set) var doubleLosses = 0

    /// 勝敗が未選択の記録は、集計に含めない
    init(records: [BattleRecord]) {
        for record in records {
            switch record.result {
            case .win?: wins += 1
            case .lose?: losses += 1
            case .doubleLoss?: doubleLosses += 1
            case nil: break
            }
        }
    }

    /// 勝率。勝ち ÷ 勝敗のついた試合数。両負けは、自分にとっては負けなので、試合数に含める。
    /// 勝敗のついた試合が無ければnil
    var winRate: Double? {
        let decided = wins + losses + doubleLosses
        return decided == 0 ? nil : Double(wins) / Double(decided)
    }

    /// 例: 「3勝1敗」「3勝2敗（両負け1）」。両負けは敗にも数える（両負けの内数を括弧で出す）
    var text: String {
        let defeats = losses + doubleLosses
        return "\(wins)勝\(defeats)敗" + (doubleLosses > 0 ? "（両負け\(doubleLosses)）" : "")
    }

    /// 例: 「勝率 75%」
    var winRateText: String? {
        guard let winRate else { return nil }
        return "勝率 \(Int((winRate * 100).rounded()))%"
    }
}
