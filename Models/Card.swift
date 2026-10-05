//
//  Card.swift
//  OPToolkit
//
//  純粋なデータ構造のみ。ロジックはViewModel/Servicesに置く。
//

import Foundation

enum CardColor: String, CaseIterable, Identifiable, Codable {
    case red = "赤"
    case green = "緑"
    case blue = "青"
    case purple = "紫"
    case black = "黒"
    case yellow = "黄"

    var id: String { rawValue }
}

enum CardType: String, CaseIterable, Identifiable, Codable {
    case leader = "リーダー"
    case character = "キャラクター"
    case event = "イベント"
    case stage = "ステージ"

    var id: String { rawValue }
}

/// 攻撃属性
enum CardAttribute: String, CaseIterable, Identifiable, Codable {
    case strike = "打"
    case special = "特"
    case ranged = "射"
    case wisdom = "知"
    case slash = "斬"

    var id: String { rawValue }
}

/// レアリティ
enum CardRarity: String, CaseIterable, Identifiable, Codable {
    case common = "C"
    case uncommon = "UC"
    case rare = "R"
    case superRare = "SR"
    case secret = "SEC"
    case promo = "P"
    case leader = "L"
    case sp = "SP"
    case tr = "TR"

    var id: String { rawValue }
}

/// ブロックアイコン（リーダーカードが持つ、ブロック可能なコストを示す番号）
enum CardBlockIcon: String, CaseIterable, Identifiable, Codable {
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case x = "X"

    var id: String { rawValue }
}

struct Card: Identifiable, Codable, Hashable {
    /// カード番号がそのまま一意なID（パラレル版は "OP01-001_p1" のように別番号になる）
    var id: String { cardNumber }
    var name: String
    var cardNumber: String   // 例: "OP01-001"
    /// 色。2色のカードは2つ入る（常に1つ以上）
    var colors: [CardColor]
    var type: CardType
    var cost: Int
    var power: Int?
    var imageName: String?

    // 検索・フィルタ用の追加情報
    var feature: String?          // 特徴（例: "超新星／麦わらの一味"のようなキーワードのまとまり。"／"区切りで複数持てる）
    /// 属性。2つ持つカードは2つ入る。イベント/ステージなど、属性を持たないカードは空
    var attributes: [CardAttribute]
    var counter: Int?             // 1000 / 2000 / なし(nil)
    var rarity: CardRarity
    var blockIcon: CardBlockIcon? // 主にリーダーカードが持つ。持たない種別はnil
    var hasBlocker: Bool          // ブロッカーを持つか（デッキ詳細の集計で使用）
    var hasTrigger: Bool          // トリガーを持つか（デッキ詳細の集計で使用）
    var isParallel: Bool          // パラレル版カードかどうか（リーダー選択画面のパラレル表示切替で使用）
    var packCode: String?         // 実際に収録されている弾（例: "OP17"）。過去弾からの再録カードだと
                                   // cardNumberの弾（例: "OP01"）と食い違う。nilならcardNumberの弾＝再録ではないとみなす

    /// 先頭の色。色を1つだけ表示したい場面用。
    /// 「この色を持つか」の判定には、2色目も見られるよう colors を使うこと。
    var color: CardColor { colors[0] }
    /// 先頭の属性（無ければnil）。「この属性を持つか」の判定には attributes を使うこと。
    var attribute: CardAttribute? { attributes.first }

    init(
        name: String,
        cardNumber: String,
        colors: [CardColor],
        type: CardType,
        cost: Int,
        power: Int? = nil,
        imageName: String? = nil,
        feature: String? = nil,
        attributes: [CardAttribute] = [],
        counter: Int? = nil,
        rarity: CardRarity = .common,
        blockIcon: CardBlockIcon? = nil,
        hasBlocker: Bool = false,
        hasTrigger: Bool = false,
        isParallel: Bool = false,
        packCode: String? = nil
    ) {
        precondition(!colors.isEmpty, "Cardのcolorsは1つ以上が必要です")
        self.name = name
        self.cardNumber = cardNumber
        self.colors = colors
        self.type = type
        self.cost = cost
        self.power = power
        self.imageName = imageName
        self.feature = feature
        self.attributes = attributes
        self.counter = counter
        self.rarity = rarity
        self.blockIcon = blockIcon
        self.hasBlocker = hasBlocker
        self.hasTrigger = hasTrigger
        self.isParallel = isParallel
        self.packCode = packCode
    }

    /// 1色・1属性のカードを作るための簡易イニシャライザ（サンプルデータ・プレビュー用）
    init(
        name: String,
        cardNumber: String,
        color: CardColor,
        type: CardType,
        cost: Int,
        power: Int? = nil,
        imageName: String? = nil,
        feature: String? = nil,
        attribute: CardAttribute? = nil,
        counter: Int? = nil,
        rarity: CardRarity = .common,
        blockIcon: CardBlockIcon? = nil,
        hasBlocker: Bool = false,
        hasTrigger: Bool = false,
        isParallel: Bool = false,
        packCode: String? = nil
    ) {
        self.init(
            name: name,
            cardNumber: cardNumber,
            colors: [color],
            type: type,
            cost: cost,
            power: power,
            imageName: imageName,
            feature: feature,
            attributes: attribute.map { [$0] } ?? [],
            counter: counter,
            rarity: rarity,
            blockIcon: blockIcon,
            hasBlocker: hasBlocker,
            hasTrigger: hasTrigger,
            isParallel: isParallel,
            packCode: packCode
        )
    }

    // MARK: - Codable
    // cards.jsonは、色を colors（配列）、属性を attributes（配列）で持つ。
    // 以前の形式（color / attribute の1つだけ）のcards.jsonでも読めるようにしてある
    // （アプリとcards.jsonの更新順がずれても、カードDBが空にならないようにするため）。

    private enum CodingKeys: String, CodingKey {
        case name, cardNumber, color, colors, type, cost, power, imageName, feature
        case attribute, attributes, counter, rarity, blockIcon, hasBlocker, hasTrigger, isParallel, packCode
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        cardNumber = try c.decode(String.self, forKey: .cardNumber)

        if let decoded = try c.decodeIfPresent([CardColor].self, forKey: .colors), !decoded.isEmpty {
            colors = decoded
        } else {
            colors = [try c.decode(CardColor.self, forKey: .color)]
        }

        type = try c.decode(CardType.self, forKey: .type)
        cost = try c.decode(Int.self, forKey: .cost)
        power = try c.decodeIfPresent(Int.self, forKey: .power)
        imageName = try c.decodeIfPresent(String.self, forKey: .imageName)
        feature = try c.decodeIfPresent(String.self, forKey: .feature)

        if let decoded = try c.decodeIfPresent([CardAttribute].self, forKey: .attributes) {
            attributes = decoded
        } else if let single = try c.decodeIfPresent(CardAttribute.self, forKey: .attribute) {
            attributes = [single]
        } else {
            attributes = []
        }

        counter = try c.decodeIfPresent(Int.self, forKey: .counter)
        rarity = try c.decode(CardRarity.self, forKey: .rarity)
        blockIcon = try c.decodeIfPresent(CardBlockIcon.self, forKey: .blockIcon)
        hasBlocker = try c.decodeIfPresent(Bool.self, forKey: .hasBlocker) ?? false
        hasTrigger = try c.decodeIfPresent(Bool.self, forKey: .hasTrigger) ?? false
        isParallel = try c.decodeIfPresent(Bool.self, forKey: .isParallel) ?? false
        packCode = try c.decodeIfPresent(String.self, forKey: .packCode)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(cardNumber, forKey: .cardNumber)
        try c.encode(colors, forKey: .colors)
        try c.encode(type, forKey: .type)
        try c.encode(cost, forKey: .cost)
        try c.encodeIfPresent(power, forKey: .power)
        try c.encodeIfPresent(imageName, forKey: .imageName)
        try c.encodeIfPresent(feature, forKey: .feature)
        try c.encode(attributes, forKey: .attributes)
        try c.encodeIfPresent(counter, forKey: .counter)
        try c.encode(rarity, forKey: .rarity)
        try c.encodeIfPresent(blockIcon, forKey: .blockIcon)
        try c.encode(hasBlocker, forKey: .hasBlocker)
        try c.encode(hasTrigger, forKey: .hasTrigger)
        try c.encode(isParallel, forKey: .isParallel)
        try c.encodeIfPresent(packCode, forKey: .packCode)
    }

    /// "／"区切りの特徴を個別のタグ配列にしたもの（デッキ詳細の特徴別集計で使用）
    var featureTags: [String] {
        guard let feature, !feature.isEmpty else { return [] }
        return feature
            .components(separatedBy: "／")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - サンプルデータ（プレビュー・動作確認用。実データ接続後は削除してOK）

extension Card {
    static let sampleLuffy = Card(
        name: "モンキー・D・ルフィ",
        cardNumber: "OP01-001",
        color: .red,
        type: .leader,
        cost: 0,
        power: 5000,
        feature: "麦わらの一味",
        attribute: .strike,
        rarity: .leader,
        blockIcon: .four
    )

    static let sampleLuffyParallel = Card(
        name: "モンキー・D・ルフィ",
        cardNumber: "OP01-001_p1",
        color: .red,
        type: .leader,
        cost: 0,
        power: 5000,
        feature: "麦わらの一味",
        attribute: .strike,
        rarity: .leader,
        blockIcon: .four,
        isParallel: true
    )

    static let sampleZoro = Card(
        name: "ロロノア・ゾロ",
        cardNumber: "OP01-025",
        color: .red,
        type: .character,
        cost: 3,
        power: 5000,
        feature: "麦わらの一味／剣士",
        attribute: .slash,
        counter: 1000,
        rarity: .superRare,
        hasBlocker: true
    )

    static let samples: [Card] = [.sampleLuffy, .sampleLuffyParallel, .sampleZoro] + generatedSamples

    /// 動作確認用に100枚規模のダミーデータを機械的に生成する。
    /// 実データ接続後はこの生成ロジックごと削除してOK。
    private static let generatedSamples: [Card] = (1...98).map { index in
        let colors = CardColor.allCases
        let types = CardType.allCases
        let attributes = CardAttribute.allCases
        let rarities = CardRarity.allCases
        let blockIcons = CardBlockIcon.allCases
        let features = ["麦わらの一味", "海軍", "王下七武海", "超新星", "革命軍", "百獣海賊団"]

        let color = colors[index % colors.count]
        let type = types[index % types.count]
        let cost = index % 11              // 0...10
        let power = type == .event || type == .stage ? nil : (index % 14) * 1000
        let counter: Int? = index % 3 == 0 ? nil : (index % 2 == 0 ? 1000 : 2000)

        return Card(
            name: "サンプルカード\(String(format: "%03d", index))",
            cardNumber: "OP01-\(String(format: "%03d", index + 200))",
            color: color,
            type: type,
            cost: cost,
            power: power,
            feature: features[index % features.count],
            attribute: (type == .event || type == .stage) ? nil : attributes[index % attributes.count],
            counter: (type == .character) ? counter : nil,
            rarity: rarities[index % rarities.count],
            blockIcon: (type == .leader) ? blockIcons[index % blockIcons.count] : nil,
            hasBlocker: type == .character && index % 4 == 0,
            hasTrigger: index % 5 == 0,
            isParallel: index % 6 == 0
        )
    }
}
