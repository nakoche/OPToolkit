//
//  CardListViewModel.swift
//  OPToolkit
//

import Foundation

@Observable
final class CardListViewModel {
    private(set) var allCards: [Card] = []

    var criteria = CardSearchCriteria()
    var isSearchSheetPresented = false
    var selectedCard: Card?   // nilでない間、詳細表示が出る

    private let repository: CardRepositoryProtocol

    init(repository: CardRepositoryProtocol = CardRepository()) {
        self.repository = repository
    }

    var filteredCards: [Card] {
        criteria.apply(to: allCards)
    }

    func loadCards() async {
        do {
            allCards = try await repository.fetchAll()
        } catch {
            // TODO: エラー状態をViewに伝えるプロパティを用意する
            print("カード読み込みに失敗: \(error)")
        }
    }

    /// 検索シートで「検索」を押したときにまとめて反映する。
    func applySearch(_ newCriteria: CardSearchCriteria) {
        criteria = newCriteria
    }

    func selectCard(_ card: Card) {
        selectedCard = card
    }
}
