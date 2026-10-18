//
//  CardQARepository.swift
//  OPToolkit
//
//  公式Q&A（qa.json）の読み込み。カード番号 → そのカードのQ&A一覧 の辞書を返す。
//  qa.jsonは、Tools/fetch_cards.py が cards.json と一緒に生成する（Bundleに同梱する）。
//

import Foundation

protocol CardQARepositoryProtocol {
    /// カード番号 → そのカードのQ&A一覧。Q&Aが無いカードは含まれない
    func fetchAll() async throws -> [String: [CardQA]]
}

struct CardQARepository: CardQARepositoryProtocol {
    func fetchAll() async throws -> [String: [CardQA]] {
        // qa.jsonが同梱されていなければ、Q&Aなしとして扱う（Q&Aのボタンが出ないだけで、アプリは動く）
        guard let url = Bundle.main.url(forResource: "qa", withExtension: "json") else {
            return [:]
        }
        // ファイルの読み込みとデコードは、MainActorの外で行う
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: [CardQA]].self, from: data)
        }.value
    }
}

/// プレビュー用。サンプルのルフィ（OP01-001）にだけQ&Aを返す
struct MockCardQARepository: CardQARepositoryProtocol {
    func fetchAll() async throws -> [String: [CardQA]] {
        ["OP01-001": CardQA.samples]
    }
}
