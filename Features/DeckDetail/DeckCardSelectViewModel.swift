//
//  DeckCardSelectViewModel.swift
//  OPToolkit
//

import Foundation

@Observable
final class DeckCardSelectViewModel {
    private(set) var allCards: [Card] = []

    /// リーダーの色に固定されたフィルタ条件。色は変更不可。
    var criteria: CardSearchCriteria
    let lockedColor: CardColor

    var isFilterSheetPresented = false

    /// タップされたカード（数量選択モーダルの対象）
    var selectedCard: Card?

    private let repository: CardRepositoryProtocol

    init(lockedColor: CardColor, repository: CardRepositoryProtocol = CardRepository()) {
        self.lockedColor = lockedColor
        self.repository = repository
        var initialCriteria = CardSearchCriteria()
        initialCriteria.selectedColors = [lockedColor]
        self.criteria = initialCriteria
    }

    /// リーダーは選択対象から常に除外する
    var filteredCards: [Card] {
        criteria.apply(to: allCards.filter { $0.type != .leader })
    }

    func loadCards() async {
        allCards = (try? await repository.fetchAll()) ?? []
    }

    func applySearch(_ newCriteria: CardSearchCriteria) {
        var updated = newCriteria
        updated.selectedColors = [lockedColor]   // 念のため色固定を保証
        criteria = updated
    }

    func selectCard(_ card: Card) {
        selectedCard = card
    }
}
