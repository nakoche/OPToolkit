//
//  Deck.swift
//  OPToolkit
//

import Foundation

struct Deck: Identifiable, Codable, Hashable {
    /// 同じカード（同じカード番号）をデッキに入れられる上限枚数
    static let maxCopiesPerCard = 4

    let id: UUID
    var name: String
    var leaderCard: Card?
    var cardEntries: [DeckEntry]
    var memo: String

    init(
        id: UUID = UUID(),
        name: String,
        leaderCard: Card? = nil,
        cardEntries: [DeckEntry] = [],
        memo: String = ""
    ) {
        self.id = id
        self.name = name
        self.leaderCard = leaderCard
        self.cardEntries = cardEntries
        self.memo = memo
    }

    var totalCardCount: Int {
        cardEntries.reduce(0) { $0 + $1.quantity }
    }
}

struct DeckEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var card: Card
    var quantity: Int
}

// MARK: - デッキ詳細画面で使う集計値
// リーダーは含めず、cardEntries（デッキ本体の50枚）だけを対象に集計する。

extension Deck {
    var characterCount: Int { count(of: .character) }
    var eventCount: Int { count(of: .event) }
    var stageCount: Int { count(of: .stage) }

    private func count(of type: CardType) -> Int {
        cardEntries
            .filter { $0.card.type == type }
            .reduce(0) { $0 + $1.quantity }
    }

    var counter1000Count: Int {
        cardEntries
            .filter { $0.card.counter == 1000 }
            .reduce(0) { $0 + $1.quantity }
    }

    var counter2000Count: Int {
        cardEntries
            .filter { $0.card.counter == 2000 }
            .reduce(0) { $0 + $1.quantity }
    }

    /// カウンターを持たないキャラクターカードの枚数
    var counterlessCount: Int {
        cardEntries
            .filter { $0.card.type == .character && $0.card.counter == nil }
            .reduce(0) { $0 + $1.quantity }
    }

    /// カウンター値×枚数の合計（例: 1000×2枚 + 2000×1枚 = 4000）
    var totalCounterValue: Int {
        cardEntries.reduce(0) { $0 + ($1.card.counter ?? 0) * $1.quantity }
    }

    var blockerCount: Int {
        cardEntries
            .filter { $0.card.hasBlocker }
            .reduce(0) { $0 + $1.quantity }
    }

    var triggerCount: Int {
        cardEntries
            .filter { $0.card.hasTrigger }
            .reduce(0) { $0 + $1.quantity }
    }

    /// コスト0〜10ごとの枚数（棒グラフ用）。コスト11以上はグラフの対象外。
    var costHistogram: [Int: Int] {
        var result: [Int: Int] = [:]
        for cost in 0...10 { result[cost] = 0 }
        for entry in cardEntries where (0...10).contains(entry.card.cost) {
            result[entry.card.cost, default: 0] += entry.quantity
        }
        return result
    }

    /// 特徴（"／"区切りのタグ）ごとの合計枚数。0枚のものは含まれない。
    /// 出現数の多い順で返す。枚数が同じ特徴は、デッキ内で先に出てきた順に並べる。
    /// （Dictionaryの並びは再計算のたびに変わるため、同数の特徴の順番が入れ替わらないよう
    ///  同数のときの順番を明示している。メモ入力などで画面が再描画されても並びは変わらない）
    var featureCounts: [(feature: String, count: Int)] {
        var counts: [String: Int] = [:]
        var firstSeenOrder: [String: Int] = [:]
        for entry in cardEntries {
            for tag in entry.card.featureTags {
                counts[tag, default: 0] += entry.quantity
                if firstSeenOrder[tag] == nil {
                    firstSeenOrder[tag] = firstSeenOrder.count
                }
            }
        }
        return counts
            .map { (feature: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return (firstSeenOrder[lhs.feature] ?? 0) < (firstSeenOrder[rhs.feature] ?? 0)
            }
    }
}

extension Deck {
    static let sample = Deck(
        name: "赤ルフィ",
        leaderCard: .sampleLuffy,
        cardEntries: [DeckEntry(card: .sampleZoro, quantity: 4)]
    )
}
