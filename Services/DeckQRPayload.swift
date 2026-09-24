//
//  DeckQRPayload.swift
//  OPToolkit
//
//  デッキ内容をQRコードに乗せるための軽量な形式。
//  カードの全データではなく「カード番号＋枚数」だけを持たせ、
//  読み込み側はカードDB（CardRepository）からカード番号を引いて実体を復元する。
//  こうすることでQRコードの情報量を抑えつつ、カードDBの更新にも追従できる。
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

    init(deck: Deck) {
        name = deck.name
        leaderCardNumber = deck.leaderCard?.cardNumber
        entries = deck.cardEntries.map { EntryPayload(cardNumber: $0.card.cardNumber, quantity: $0.quantity) }
    }

    /// QRコードに埋め込む文字列（JSONをそのまま使う。必要ならBase64等で圧縮してもよい）
    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from string: String) -> DeckQRPayload? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DeckQRPayload.self, from: data)
    }

    /// カードDB(allCards)からカード番号を引いて、実際のDeckを復元する
    func resolve(using allCards: [Card]) -> Deck {
        let cardsByNumber = Dictionary(uniqueKeysWithValues: allCards.map { ($0.cardNumber, $0) })

        let leader = leaderCardNumber.flatMap { cardsByNumber[$0] }
        let resolvedEntries: [DeckEntry] = entries.compactMap { entry in
            guard let card = cardsByNumber[entry.cardNumber] else { return nil }
            return DeckEntry(card: card, quantity: entry.quantity)
        }

        return Deck(name: name, leaderCard: leader, cardEntries: resolvedEntries)
    }
}
