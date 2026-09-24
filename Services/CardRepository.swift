//
//  CardRepository.swift
//  OPToolkit
//
//  カードDBの読み込みを担う層。ViewModelはこの中身（JSON/API/DB）を意識しない。
//  TODO: 同梱JSON読み込み or 外部API呼び出しに差し替える。
//

import Foundation

protocol CardRepositoryProtocol {
    func fetchAll() async throws -> [Card]
}

final class CardRepository: CardRepositoryProtocol {
    func fetchAll() async throws -> [Card] {
        // TODO: 例）Bundle内のcards.jsonをデコードして返す
        // let url = Bundle.main.url(forResource: "cards", withExtension: "json")!
        // let data = try Data(contentsOf: url)
        // return try JSONDecoder().decode([Card].self, from: data)
        Card.samples
    }
}

/// プレビュー・テスト用のダミー実装
final class MockCardRepository: CardRepositoryProtocol {
    var cardsToReturn: [Card] = Card.samples

    func fetchAll() async throws -> [Card] {
        cardsToReturn
    }
}
