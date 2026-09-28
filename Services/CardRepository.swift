//
//  CardRepository.swift
//  OPToolkit
//
//  カードDBの読み込みを担う層。ViewModelはこの中身（JSON/API/DB）を意識しない。
//  Bundle同梱のcards.json（fetch_cards.pyで生成）を読み込む。
//

import Foundation

protocol CardRepositoryProtocol {
    func fetchAll() async throws -> [Card]
}

enum CardRepositoryError: LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "\(name).json がアプリに含まれていません（Target Membershipを確認してください）"
        }
    }
}

final class CardRepository: CardRepositoryProtocol {
    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "cards") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func fetchAll() async throws -> [Card] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CardRepositoryError.resourceNotFound(resourceName)
        }
        // 2000枚規模でもデコードは数十ミリ秒程度なので、そのまま読み込んで問題ない
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Card].self, from: data)
    }
}

/// プレビュー・テスト用のダミー実装
final class MockCardRepository: CardRepositoryProtocol {
    var cardsToReturn: [Card] = Card.samples

    func fetchAll() async throws -> [Card] {
        cardsToReturn
    }
}
