//
//  CardListViewModel.swift
//  OPToolkit
//

import Foundation

@Observable
final class CardListViewModel {
    private(set) var allCards: [Card] = []
    /// カード番号 → 公式Q&A（qa.json）。ファイルが無い・読めないときは空のまま
    private(set) var qaByCardNumber: [String: [CardQA]] = [:]

    var criteria = CardSearchCriteria()
    var isSearchSheetPresented = false
    var selectedCard: Card?   // nilでない間、詳細表示が出る
    /// パラレル表示の切り替え（検索欄の右のボタン）。
    /// 検索シートの条件（criteria）とは別に持つ。シートで「検索」を押しても変わらない。
    var parallelMode: ParallelDisplayMode = .mixed

    private let repository: CardRepositoryProtocol
    private let qaRepository: CardQARepositoryProtocol
    /// お気に入り（♡）の保存先。アプリ全体で共有する（RootViewで作って渡す）
    private let favoritesStore: FavoritesStore

    init(
        repository: CardRepositoryProtocol = CardRepository(),
        qaRepository: CardQARepositoryProtocol = CardQARepository(),
        favoritesStore: FavoritesStore = FavoritesStore()
    ) {
        self.repository = repository
        self.qaRepository = qaRepository
        self.favoritesStore = favoritesStore
    }

    var filteredCards: [Card] {
        // 並び替え済みの結果に対してパラレルだけ絞るので、並び順は変わらない
        criteria
            .apply(to: allCards, favoriteCardNumbers: favoritesStore.cardNumbers)
            .filter { parallelMode.matches($0) }
    }

    /// お気に入り（♡）か。パラレルとノーマルは別々に扱う
    func isFavorite(_ card: Card) -> Bool {
        favoritesStore.isFavorite(card)
    }

    func toggleFavorite(_ card: Card) {
        favoritesStore.toggle(card)
    }

    func loadCards() async {
        do {
            allCards = try await repository.fetchAll()
        } catch {
            // TODO: エラー状態をViewに伝えるプロパティを用意する
            print("カード読み込みに失敗: \(error)")
        }
        await loadQA()
    }

    /// Q&Aは、読めなくてもカード一覧に影響しないよう、カードとは別に読む。一度読めたら再読み込みしない。
    private func loadQA() async {
        guard qaByCardNumber.isEmpty else { return }
        do {
            qaByCardNumber = try await qaRepository.fetchAll()
        } catch {
            print("Q&A読み込みに失敗: \(error)")
        }
    }

    /// そのカードのQ&A。無ければ空（詳細モーダルのQ&Aボタンが出ない）。
    /// パラレル（"OP01-001_p1"など）は、自分の番号にQ&Aが無ければ、元のカード番号（"OP01-001"）のものを使う。
    func qaItems(for card: Card) -> [CardQA] {
        if let items = qaByCardNumber[card.cardNumber], !items.isEmpty {
            return items
        }
        guard card.isParallel else { return [] }
        return qaByCardNumber[Self.baseCardNumber(of: card.cardNumber)] ?? []
    }

    /// "OP01-001_p1" → "OP01-001"
    private static func baseCardNumber(of cardNumber: String) -> String {
        cardNumber.replacingOccurrences(of: "_p\\d+$", with: "", options: .regularExpression)
    }

    /// 検索シートで「検索」を押したときにまとめて反映する。
    func applySearch(_ newCriteria: CardSearchCriteria) {
        criteria = newCriteria
    }

    func selectCard(_ card: Card) {
        selectedCard = card
    }
}
