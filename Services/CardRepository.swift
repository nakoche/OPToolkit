//
//  CardRepository.swift
//  OPToolkit
//
//  カードDBの読み込みを担う層。ViewModelはこの中身（JSON/API/DB）を意識しない。
//  Bundle同梱のcards.json（fetch_cards.pyで生成）を読み込む。
//
//  約5000枚のデコードは画面ごと・Repositoryインスタンスごとに繰り返したくないので、
//  プロセス内で共有するキャッシュを持たせている（デコード自体もactor内＝メインスレッド外で行う）。
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
    private static let cache = CardCache()

    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "cards") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func fetchAll() async throws -> [Card] {
        let bundle = self.bundle
        let resourceName = self.resourceName
        let key = "\(bundle.bundlePath)/\(resourceName)"

        return try await Self.cache.cards(for: key) {
            guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
                throw CardRepositoryError.resourceNotFound(resourceName)
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Card].self, from: data)
        }
    }
}

/// デコード済みカードDBのプロセス内キャッシュ。読み込みに失敗した場合はキャッシュしない。
fileprivate actor CardCache {
    private var storage: [String: [Card]] = [:]

    func cards(for key: String, load: @Sendable () throws -> [Card]) throws -> [Card] {
        if let cached = storage[key] { return cached }
        let cards = try load()
        storage[key] = cards
        return cards
    }
}

/// プレビュー・テスト用のダミー実装
final class MockCardRepository: CardRepositoryProtocol {
    var cardsToReturn: [Card] = Card.samples

    func fetchAll() async throws -> [Card] {
        cardsToReturn
    }
}
