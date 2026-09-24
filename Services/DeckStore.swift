//
//  DeckStore.swift
//  OPToolkit
//
//  デッキの保存/読み込みを担う層。
//  TODO: 実際はFileManagerでのJSON永続化 or SwiftDataに差し替える。
//

import Foundation

protocol DeckStoreProtocol {
    func fetchAll() -> [Deck]
    func save(_ deck: Deck)
    func update(_ deck: Deck)
    func delete(_ deck: Deck)
    /// 一覧の並び順をまるごと保存する（ドラッグでの入れ替え確定時に呼ぶ）
    func reorder(_ decks: [Deck])
}

final class DeckStore: DeckStoreProtocol {
    private var decks: [Deck] = [.sample]   // TODO: 永続化層から読み込む

    func fetchAll() -> [Deck] {
        decks
    }

    func save(_ deck: Deck) {
        decks.append(deck)
        // TODO: ディスクへの書き込み
    }

    func update(_ deck: Deck) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index] = deck
        // TODO: ディスクへの書き込み
    }

    func delete(_ deck: Deck) {
        decks.removeAll { $0.id == deck.id }
        // TODO: ディスクへの反映
    }

    func reorder(_ decks: [Deck]) {
        self.decks = decks
        // TODO: ディスクへの反映
    }
}
