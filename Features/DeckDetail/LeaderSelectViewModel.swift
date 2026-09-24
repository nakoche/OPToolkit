//
//  LeaderSelectViewModel.swift
//  OPToolkit
//

import Foundation

/// パラレル表示の3状態
enum ParallelDisplayMode: CaseIterable {
    case normalOnly    // ノーマルのみ
    case mixed         // ノーマル＋パラレル混在（初期状態）
    case parallelOnly  // パラレルのみ

    mutating func advance() {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        self = all[(index + 1) % all.count]
    }

    /// 対応する星アイコンのSF Symbol名
    var symbolName: String {
        switch self {
        case .normalOnly: return "star"
        case .mixed: return "star.leadinghalf.filled"
        case .parallelOnly: return "star.fill"
        }
    }

    func matches(_ card: Card) -> Bool {
        switch self {
        case .normalOnly: return !card.isParallel
        case .mixed: return true
        case .parallelOnly: return card.isParallel
        }
    }
}

@Observable
final class LeaderSelectViewModel {
    private(set) var allCards: [Card] = []

    var searchText = ""
    var selectedColors: Set<CardColor> = []
    var parallelMode: ParallelDisplayMode = .mixed

    private let repository: CardRepositoryProtocol

    init(repository: CardRepositoryProtocol = CardRepository()) {
        self.repository = repository
    }

    var filteredCards: [Card] {
        var cards = allCards.filter { $0.type == .leader }

        if !searchText.isEmpty {
            cards = cards.filter {
                $0.name.matchesSearch(searchText) || $0.cardNumber.matchesSearch(searchText)
            }
        }

        if !selectedColors.isEmpty {
            cards = cards.filter { selectedColors.contains($0.color) }
        }

        cards = cards.filter { parallelMode.matches($0) }

        return cards
    }

    func loadCards() async {
        allCards = (try? await repository.fetchAll()) ?? []
    }
}
