//
//  Card+ReleaseSort.swift
//  OPToolkit
//
//  カードリストのデフォルト表示順（発売順）をまとめたファイル。
//  要件:
//   1. 最新弾（例: OP17）から降順
//   2. 各弾の中では番号順（001から昇順）
//   3. その弾に過去弾からの再録カードが収録されている場合、その弾の一番最後に表示（元の弾がOP01から昇順）
//   4. パラレル（番号が同じもの）はノーマルの後に表示
//   5. パラレルが複数ある場合、レアリティの高い方を後に表示
//
//  「弾」は cardNumber の接頭辞（例: "OP01-001" → "OP01"）ではなく、
//  fetch_cards.py が実際にその弾のページから取得した packCode を使う。
//  再録カードは packCode（今収録されている弾）と cardNumber の接頭辞（元の弾）が食い違うため、
//  これで「再録かどうか」を区別できる。
//

import Foundation

extension CardRarity {
    /// パラレル同士を比べるときの「レアリティの高さ」。値が大きいほど後ろに表示する。
    /// 公式の序列を完全に反映したものではなく、実用上の目安。
    /// 実際の並びと違う場合はここの数値を調整する。
    var rarityRank: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .superRare: return 3
        case .secret: return 4
        case .leader: return 5
        case .promo: return 6
        case .sp: return 7
        case .tr: return 8
        }
    }
}

extension Card {
    /// cardNumberの弾部分（例: "OP01-001_p1" → "OP01"）
    private var originalPackCode: String {
        String(cardNumber.split(separator: "-").first ?? Substring(cardNumber))
    }

    /// 実際に収録されている弾。packCode未設定（同梱データが古い等）ならcardNumberの弾で代用する。
    private var effectivePackCode: String {
        let code = packCode ?? originalPackCode
        return code.isEmpty ? originalPackCode : code
    }

    /// 過去弾からの再録カードかどうか（収録されている弾と、カード番号の弾が食い違う場合）
    var isReprint: Bool {
        effectivePackCode != originalPackCode
    }

    /// cardNumberの「弾内の番号」部分だけを数値にしたもの（"OP01-001_p1" → 1）
    private var cardSequenceNumber: Int {
        guard let dashIndex = cardNumber.firstIndex(of: "-") else { return 0 }
        let afterDash = cardNumber[cardNumber.index(after: dashIndex)...]
        let digits = afterDash.prefix(while: \.isNumber)
        return Int(digits) ?? 0
    }

    /// "OP17" → (prefix: "OP", number: 17) のように分解する
    private static func splitPackCode(_ code: String) -> (prefix: String, number: Int) {
        let digitsPart = code.drop(while: { !$0.isNumber })
        let prefix = String(code.dropLast(digitsPart.count))
        return (prefix, Int(digitsPart) ?? 0)
    }

    /// 弾の種類ごとの表示優先順位。数値が小さいほど先（新しい扱い）。
    /// ここにないプレフィックス（プロモ等、【XX-NN】形式の弾コードを持たないもの）は最後に回る。
    private static let packCategoryOrder: [String: Int] = [
        "OP": 0,   // ブースターパック（最新弾）
        "EB": 1,   // エクストラブースター
        "PRB": 2,  // プレミアムブースター
        "ST": 3,   // スタートデッキ
    ]

    private static func packCategoryRank(_ prefix: String) -> Int {
        packCategoryOrder[prefix] ?? Int.max
    }

    /// デフォルト表示順を決めるための比較キー。CardReleaseOrderで使う。
    fileprivate var releaseSortKey: CardReleaseOrder.Key {
        let (packPrefix, packNumber) = Card.splitPackCode(effectivePackCode)
        let originalNumber = isReprint ? Card.splitPackCode(originalPackCode).number : 0
        return CardReleaseOrder.Key(
            packCategoryRank: Card.packCategoryRank(packPrefix),
            packNumber: packNumber,
            packPrefix: packPrefix,
            isReprint: isReprint,
            originalPackNumber: originalNumber,
            cardSequenceNumber: cardSequenceNumber,
            isParallel: isParallel,
            rarityRank: rarity.rarityRank
        )
    }
}

enum CardReleaseOrder {
    /// 各カードをこのキーで昇順ソートすると、要件どおりの発売順になる。
    struct Key: Comparable {
        let packCategoryRank: Int
        let packNumber: Int
        let packPrefix: String
        let isReprint: Bool
        let originalPackNumber: Int
        let cardSequenceNumber: Int
        let isParallel: Bool
        let rarityRank: Int

        static func < (lhs: Key, rhs: Key) -> Bool {
            // 0. 弾の種類（OP→EB→PRB→ST→その他）
            if lhs.packCategoryRank != rhs.packCategoryRank { return lhs.packCategoryRank < rhs.packCategoryRank }
            // 1. 同じ種類の中では、新しい方（番号が大きい方）を先に
            if lhs.packNumber != rhs.packNumber { return lhs.packNumber > rhs.packNumber }
            // カテゴリ表に無いプレフィックス同士が同じ番号になった場合の保険
            if lhs.packPrefix != rhs.packPrefix { return lhs.packPrefix < rhs.packPrefix }
            // 2. 同じ弾の中では、その弾オリジナルのカードを先、再録カードを後に
            if lhs.isReprint != rhs.isReprint { return !lhs.isReprint }
            // 3. 再録カード同士は、元の弾が古い方（OP01）から昇順
            if lhs.isReprint && lhs.originalPackNumber != rhs.originalPackNumber {
                return lhs.originalPackNumber < rhs.originalPackNumber
            }
            // 番号順（001から昇順）
            if lhs.cardSequenceNumber != rhs.cardSequenceNumber {
                return lhs.cardSequenceNumber < rhs.cardSequenceNumber
            }
            // 4. ノーマルを先、パラレルを後に
            if lhs.isParallel != rhs.isParallel { return !lhs.isParallel }
            // 5. パラレル同士はレアリティが低い方を先、高い方を後に
            return lhs.rarityRank < rhs.rarityRank
        }
    }

    /// 要件どおりの並び順（最新弾から降順、弾内は昇順…）で並び替えた配列を返す。
    /// direction == .ascending のときがこの「要件どおりの並び」そのもの。
    /// .descending は全体を単純に反転した順（最も古い弾から）になる。
    static func sorted(_ cards: [Card], direction: SortDirection) -> [Card] {
        let defaultOrder = cards.sorted { $0.releaseSortKey < $1.releaseSortKey }
        return direction == .ascending ? defaultOrder : defaultOrder.reversed()
    }
}
