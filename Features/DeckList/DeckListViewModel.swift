//
//  DeckListViewModel.swift
//  OPToolkit
//

import SwiftUI
import UIKit

@Observable
final class DeckListViewModel {
    private(set) var decks: [Deck] = []

    // 削除確認モーダル用
    var pendingDeleteDeck: Deck?

    // QR読み込み用
    var isShowingScanner = false
    var scanErrorMessage: String?

    // 画像共有用
    var shareImage: UIImage?

    private let deckStore: DeckStoreProtocol
    private let cardRepository: CardRepositoryProtocol

    /// DeckDetailViewModelに同じ保存先を渡すために公開しておく
    var store: DeckStoreProtocol { deckStore }

    init(
        deckStore: DeckStoreProtocol = DeckStore(),
        cardRepository: CardRepositoryProtocol = CardRepository()
    ) {
        self.deckStore = deckStore
        self.cardRepository = cardRepository
        self.decks = deckStore.fetchAll()
    }

    // MARK: - コピー

    func copyDeck(_ deck: Deck) {
        let newName = nextCopyName(basedOn: deck.name)
        let newDeck = Deck(
            name: newName,
            leaderCard: deck.leaderCard,
            cardEntries: deck.cardEntries,
            memo: deck.memo
        )
        deckStore.save(newDeck)
        decks = deckStore.fetchAll()
    }

    /// 「〇〇」→「〇〇コピー1」、既に「〇〇コピー1」があれば「〇〇コピー2」…と採番する
    private func nextCopyName(basedOn originalName: String) -> String {
        // 既に「コピーN」が付いている名前をコピーした場合は、元の名前（コピー部分を除いた部分）を基準にする
        let baseName = baseNameStrippingCopySuffix(originalName)

        let existingNumbers = decks
            .map(\.name)
            .compactMap { copyNumber($0, baseName: baseName) }

        let nextNumber = (existingNumbers.max() ?? 0) + 1
        return "\(baseName)コピー\(nextNumber)"
    }

    private func baseNameStrippingCopySuffix(_ name: String) -> String {
        guard let range = name.range(of: "コピー[0-9]+$", options: .regularExpression) else {
            return name
        }
        return String(name[name.startIndex..<range.lowerBound])
    }

    private func copyNumber(_ name: String, baseName: String) -> Int? {
        guard name.hasPrefix(baseName + "コピー") else { return nil }
        let suffix = name.dropFirst((baseName + "コピー").count)
        return Int(suffix)
    }

    // MARK: - 削除

    func requestDelete(_ deck: Deck) {
        pendingDeleteDeck = deck
    }

    func confirmDelete() {
        guard let deck = pendingDeleteDeck else { return }
        deckStore.delete(deck)
        decks = deckStore.fetchAll()
        pendingDeleteDeck = nil
    }

    func cancelDelete() {
        pendingDeleteDeck = nil
    }

    // MARK: - 並び替え

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        decks.move(fromOffsets: source, toOffset: destination)
        deckStore.reorder(decks)
    }

    /// ドラッグハンドルでの隣接入れ替え用
    func swapAdjacent(_ index: Int, with otherIndex: Int) {
        guard decks.indices.contains(index), decks.indices.contains(otherIndex) else { return }
        decks.swapAt(index, otherIndex)
        deckStore.reorder(decks)
    }

    // MARK: - 画像作成

    func generateShareImage(for deck: Deck) {
        shareImage = DeckImageExporter.makeImage(for: deck)
    }

    // MARK: - QRからデッキ作成

    func handleScannedQRString(_ string: String) {
        isShowingScanner = false

        guard let payload = DeckQRPayload.decode(from: string) else {
            scanErrorMessage = "読み取ったQRコードはデッキ情報として認識できませんでした"
            return
        }

        Task {
            let allCards = (try? await cardRepository.fetchAll()) ?? []
            let deck = payload.resolve(using: allCards)
            deckStore.save(deck)
            decks = deckStore.fetchAll()
        }
    }

    // MARK: - デッキ詳細からの反映

    func reloadFromStore() {
        decks = deckStore.fetchAll()
    }
}
