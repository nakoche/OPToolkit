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

    /// 画面を開いた時点（または最後に保存した時点）のデッキ内容。変更があるかの判定に使う。
    private var savedSnapshot: [String]

    init(
        deck: Deck,
        isNew: Bool,
        deckStore: DeckStoreProtocol,   // 一覧と同じインスタンスを必ず渡す（デフォルト引数で生成しない）
        onSave: @escaping () -> Void
    ) {
        self.deck = deck
        self.isNew = isNew
        self.deckStore = deckStore
        self.onSave = onSave
        self.savedSnapshot = Self.snapshot(of: deck)
    }

    /// 保存済みの内容から変更されているか（戻る時に破棄/保存の確認を出すかの判定に使う）
    var hasChanges: Bool {
        Self.snapshot(of: deck) != savedSnapshot
    }

    /// デッキの「中身」だけを比較用の配列にする。
    /// カードの並び順や、DeckEntryの内部IDの違いは変更とみなさない
    /// （カードを外して入れ直しただけで「変更あり」にならないようにするため）。
    private static func snapshot(of deck: Deck) -> [String] {
        ["name:\(deck.name)", "leader:\(deck.leaderCard?.cardNumber ?? "")", "memo:\(deck.memo)"]
            + deck.cardEntries.map { "\($0.card.cardNumber)x\($0.quantity)" }.sorted()
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

        do {
            if isNew {
                try deckStore.save(deck)
            } else {
                try deckStore.update(deck)
            }
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
        savedSnapshot = Self.snapshot(of: deck)
        onSave()
        return true
    }
}
