//
//  DeckDetailViewModel.swift
//  OPToolkit
//

import Foundation

@Observable
final class DeckDetailViewModel {
    var deck: Deck
    let isNew: Bool   // 新規作成時のみリーダーを選択できる

    var isShowingLeaderSelect = false
    var isShowingCardSelect = false

    private let deckStore: DeckStoreProtocol
    private let onSave: () -> Void

    init(
        deck: Deck,
        isNew: Bool,
        deckStore: DeckStoreProtocol = DeckStore(),
        onSave: @escaping () -> Void
    ) {
        self.deck = deck
        self.isNew = isNew
        self.deckStore = deckStore
        self.onSave = onSave
    }

    func setLeader(_ card: Card) {
        deck.leaderCard = card
        isShowingLeaderSelect = false
    }

    /// デッキカード選択画面の「デッキに追加」から呼ばれる。
    /// 既にデッキに入っていれば枚数を上書き、0ならエントリごと削除する。
    /// 以前はここで選択画面自体を閉じていたが、1枚選ぶたびにデッキ詳細へ
    /// 戻されてしまい不便だったため、画面は閉じずに反映だけ行うようにした。
    /// 選択画面を閉じるのはユーザーが「完了」を押したときだけにする。
    func setQuantity(_ quantity: Int, for card: Card) {
        if let index = deck.cardEntries.firstIndex(where: { $0.card.id == card.id }) {
            if quantity <= 0 {
                deck.cardEntries.remove(at: index)
            } else {
                deck.cardEntries[index].quantity = quantity
            }
        } else if quantity > 0 {
            deck.cardEntries.append(DeckEntry(card: card, quantity: quantity))
        }
    }

    /// 指定したカードが現在デッキに何枚入っているか
    func currentQuantity(of card: Card) -> Int {
        deck.cardEntries.first { $0.card.id == card.id }?.quantity ?? 0
    }

    var canSave: Bool {
        !deck.name.trimmingCharacters(in: .whitespaces).isEmpty && deck.leaderCard != nil
    }

    /// 保存できない場合の理由（保存ボタンを押した時にアラートで表示する）
    var saveErrorMessage: String?

    /// 保存を試みる。成功したらtrueを返し、失敗したらsaveErrorMessageに理由をセットしてfalseを返す。
    @discardableResult
    func save() -> Bool {
        var missingReasons: [String] = []
        if deck.name.trimmingCharacters(in: .whitespaces).isEmpty {
            missingReasons.append("デッキ名")
        }
        if deck.leaderCard == nil {
            missingReasons.append("リーダーカード")
        }

        guard missingReasons.isEmpty else {
            saveErrorMessage = "\(missingReasons.joined(separator: "・"))が未設定のため保存できません"
            return false
        }

        if isNew {
            deckStore.save(deck)
        } else {
            deckStore.update(deck)
        }
        onSave()
        return true
    }
}
