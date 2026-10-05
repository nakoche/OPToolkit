//
//  StoredDeck.swift
//  OPToolkit
//
//  デッキをディスクに保存するための形式。Card実体ではなく「カード番号＋枚数」だけを持つ。
//  こうしておくと、Cardにフィールドを追加しても保存済みデッキが読めなくなることがなく、
//  cards.jsonの更新にも追従できる（DeckQRPayloadと同じ考え方）。
//

import Foundation

/// 保存ファイル（decks.json）全体。将来の形式変更に備えてversionを持たせる。
struct DeckStoreFile: Codable {
    var version: Int
    var decks: [StoredDeck]
}

struct StoredDeck: Codable {
    struct Entry: Codable {
        var cardNumber: String
        var quantity: Int
    }

    var id: UUID
    var name: String
    var leaderCardNumber: String?
    var entries: [Entry]
    var memo: String

    init(deck: Deck) {
        id = deck.id
        name = deck.name
        leaderCardNumber = deck.leaderCard?.cardNumber
        entries = deck.cardEntries.map { Entry(cardNumber: $0.card.cardNumber, quantity: $0.quantity) }
        memo = deck.memo
    }

    /// カードDBからカード番号を引いてDeckを復元する。DBに存在しないカード番号は復元結果から外れる。
    func resolve(using cardsByNumber: [String: Card]) -> Deck {
        Deck(
            id: id,
            name: name,
            leaderCard: leaderCardNumber.flatMap { cardsByNumber[$0] },
            cardEntries: entries.compactMap { entry in
                guard let card = cardsByNumber[entry.cardNumber] else { return nil }
                return DeckEntry(card: card, quantity: entry.quantity)
            },
            memo: memo
        )
    }
}
