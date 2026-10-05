//
//  DeckQRPayload.swift
//  OPToolkit
//
//  デッキ内容をQRコードに乗せるための軽量な形式。
//  カードの全データではなく「カード番号＋枚数」だけを持たせ、
//  読み込み側はカードDB（CardRepository）からカード番号を引いて実体を復元する。
//  こうすることでQRコードの情報量を抑えつつ、カードDBの更新にも追従できる。
//
//  QRコードは文字数が多いほど細かくなり、デッキ画像に小さく埋め込んだ状態では
//  写真から読み取れなくなる。そのためJSONではなく、次のような短い形式で書き出す。
//
//      OPTK1
//      デッキ名
//      OP01-001            （リーダーのカード番号。無ければ空行）
//      OP01-025:4,OP01-026:3
//
//  読み込みは、この形式と、以前のJSON形式の両方に対応している。
//

import Foundation

struct DeckQRPayload: Codable {
    struct EntryPayload: Codable {
        var cardNumber: String
        var quantity: Int
    }

    var name: String
    var leaderCardNumber: String?
    var entries: [EntryPayload]

    private static let compactHeader = "OPTK1"

    init(deck: Deck) {
        name = deck.name
        leaderCardNumber = deck.leaderCard?.cardNumber
        entries = deck.cardEntries.map { EntryPayload(cardNumber: $0.card.cardNumber, quantity: $0.quantity) }
    }

    private init(name: String, leaderCardNumber: String?, entries: [EntryPayload]) {
        self.name = name
        self.leaderCardNumber = leaderCardNumber
        self.entries = entries
    }

    /// QRコードに埋め込む文字列（短い独自形式）
    func encoded() -> String? {
        let singleLineName = name.replacingOccurrences(of: "\n", with: " ")
        let entryText = entries
            .map { "\($0.cardNumber):\($0.quantity)" }
            .joined(separator: ",")
        return [Self.compactHeader, singleLineName, leaderCardNumber ?? "", entryText]
            .joined(separator: "\n")
    }

    static func decode(from string: String) -> DeckQRPayload? {
        decodeCompact(from: string) ?? decodeLegacyJSON(from: string)
    }

    private static func decodeCompact(from string: String) -> DeckQRPayload? {
        let lines = string.components(separatedBy: "\n")
        guard lines.count == 4, lines[0] == compactHeader else { return nil }

        var entries: [EntryPayload] = []
        if !lines[3].isEmpty {
            for part in lines[3].split(separator: ",") {
                guard let separatorIndex = part.lastIndex(of: ":"),
                      let quantity = Int(part[part.index(after: separatorIndex)...]) else { return nil }
                entries.append(EntryPayload(cardNumber: String(part[..<separatorIndex]), quantity: quantity))
            }
        }

        return DeckQRPayload(
            name: lines[1],
            leaderCardNumber: lines[2].isEmpty ? nil : lines[2],
            entries: entries
        )
    }

    /// 以前の形式（JSON）。既に作成済みのQR画像も読み込めるように残している。
    private static func decodeLegacyJSON(from string: String) -> DeckQRPayload? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DeckQRPayload.self, from: data)
    }

    /// カードDB(allCards)からカード番号を引いて、実際のDeckを復元する
    func resolve(using allCards: [Card]) -> Deck {
        let cardsByNumber = Dictionary(allCards.map { ($0.cardNumber, $0) }, uniquingKeysWith: { first, _ in first })

        let leader = leaderCardNumber.flatMap { cardsByNumber[$0] }
        let resolvedEntries: [DeckEntry] = entries.compactMap { entry in
            guard let card = cardsByNumber[entry.cardNumber] else { return nil }
            return DeckEntry(card: card, quantity: entry.quantity)
        }

        return Deck(name: name, leaderCard: leader, cardEntries: resolvedEntries)
    }
}
