//
//  CardSearchCriteria.swift
//  OPToolkit
//
//  カードリストの検索・フィルタ・並び替え条件をまとめた型。
//  CardListViewModelとCardSearchSheetの間でこれ1つをやり取りする。
//

import Foundation

/// コストフィルタの選択肢
enum CostOption: Hashable, Identifiable {
    case value(Int)

    var id: String {
        if case .value(let v) = self { return "\(v)" }
        return ""
    }

    var label: String { id }

    /// コスト0〜10の11個
    static let all: [CostOption] = (0...10).map { .value($0) }
}

/// カウンターフィルタの選択肢
enum CounterOption: String, CaseIterable, Identifiable, Hashable {
    case counter1000 = "1000"
    case counter2000 = "2000"
    case none = "なし"

    var id: String { rawValue }

    func matches(_ counter: Int?) -> Bool {
        switch self {
        case .counter1000: return counter == 1000
        case .counter2000: return counter == 2000
        case .none: return counter == nil
        }
    }
}

struct CardSearchCriteria: Equatable {
    var searchText: String = ""
    var selectedColors: Set<CardColor> = []
    var selectedTypes: Set<CardType> = []
    var featureQuery: String = ""
    var selectedCosts: Set<CostOption> = []
    var selectedPowers: Set<Int> = []
    var selectedAttributes: Set<CardAttribute> = []
    var selectedCounters: Set<CounterOption> = []
    var selectedRarities: Set<CardRarity> = []
    var selectedBlockIcons: Set<CardBlockIcon> = []
    var sortKey: CardSortKey = .name
    var sortDirection: SortDirection = .ascending

    /// フィルタ・検索を適用したカード一覧を返す
    func apply(to cards: [Card]) -> [Card] {
        var result = cards

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.matchesSearch(searchText) || $0.cardNumber.matchesSearch(searchText)
            }
        }

        if !selectedColors.isEmpty {
            result = result.filter { selectedColors.contains($0.color) }
        }

        if !selectedTypes.isEmpty {
            result = result.filter { selectedTypes.contains($0.type) }
        }

        if !featureQuery.isEmpty {
            result = result.filter { card in
                guard let feature = card.feature else { return false }
                return feature.matchesSearch(featureQuery)
            }
        }

        let costValues: Set<Int> = Set(selectedCosts.compactMap {
            if case .value(let v) = $0 { return v } else { return nil }
        })
        if !costValues.isEmpty {
            result = result.filter { costValues.contains($0.cost) }
        }

        if !selectedPowers.isEmpty {
            result = result.filter { card in
                guard let power = card.power else { return false }
                return selectedPowers.contains(power)
            }
        }

        if !selectedAttributes.isEmpty {
            result = result.filter { card in
                guard let attribute = card.attribute else { return false }
                return selectedAttributes.contains(attribute)
            }
        }

        if !selectedCounters.isEmpty {
            result = result.filter { card in
                selectedCounters.contains { $0.matches(card.counter) }
            }
        }

        if !selectedRarities.isEmpty {
            result = result.filter { selectedRarities.contains($0.rarity) }
        }

        if !selectedBlockIcons.isEmpty {
            result = result.filter { card in
                guard let blockIcon = card.blockIcon else { return false }
                return selectedBlockIcons.contains(blockIcon)
            }
        }

        result.sort { lhs, rhs in
            let isAscending: Bool
            switch sortKey {
            case .name: isAscending = lhs.name < rhs.name
            case .cost: isAscending = lhs.cost < rhs.cost
            case .power: isAscending = (lhs.power ?? -1) < (rhs.power ?? -1)
            }
            return sortDirection == .ascending ? isAscending : !isAscending
        }

        return result
    }
}
