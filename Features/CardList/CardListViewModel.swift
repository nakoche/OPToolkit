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
    /// パラレル表示の切り替え（検索欄の右のボタン）。
    /// 検索シートの条件（criteria）とは別に持つ。シートで「検索」を押しても変わらない。
    var parallelMode: ParallelDisplayMode = .mixed

    private let repository: CardRepositoryProtocol

    init(repository: CardRepositoryProtocol = CardRepository()) {
        self.repository = repository
    }

    var filteredCards: [Card] {
        // 並び替え済みの結果に対してパラレルだけ絞るので、並び順は変わらない
        criteria.apply(to: allCards).filter { parallelMode.matches($0) }
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
