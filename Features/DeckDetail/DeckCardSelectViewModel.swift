//
//  DeckCardSelectViewModel.swift
//  OPToolkit
//

import Foundation

@Observable
final class DeckCardSelectViewModel {
    private(set) var allCards: [Card] = []

    /// リーダーの色に固定されたフィルタ条件。色は変更不可。
    /// リーダーが2色の場合は、どちらかの色を持つカードが対象になる。
    var criteria: CardSearchCriteria
    let lockedColors: Set<CardColor>

    var isFilterSheetPresented = false

    /// パラレル表示の切り替え（フィルタボタンの下のボタン）。
    /// フィルタシートの条件（criteria）とは別に持つ。シートで「検索」を押しても変わらない。
    var parallelMode: ParallelDisplayMode = .mixed

    /// タップされたカード（数量選択モーダルの対象）
    var selectedCard: Card?

    private let repository: CardRepositoryProtocol

    init(lockedColors: Set<CardColor>, repository: CardRepositoryProtocol = CardRepository()) {
        self.lockedColors = lockedColors
        self.repository = repository
        var initialCriteria = CardSearchCriteria()
        initialCriteria.selectedColors = lockedColors
        self.criteria = initialCriteria
    }

    /// リーダーは選択対象から常に除外する
    var filteredCards: [Card] {
        // 並び替え済みの結果に対してパラレルだけ絞るので、並び順は変わらない
        criteria.apply(to: allCards.filter { $0.type != .leader })
            .filter { parallelMode.matches($0) }
    }

    func loadCards() async {
        allCards = (try? await repository.fetchAll()) ?? []
    }

    func applySearch(_ newCriteria: CardSearchCriteria) {
        var updated = newCriteria
        updated.selectedColors = lockedColors   // 念のため色固定を保証
        criteria = updated
    }

    func selectCard(_ card: Card) {
        selectedCard = card
    }
}
