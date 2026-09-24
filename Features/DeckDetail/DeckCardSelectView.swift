//
//  DeckCardSelectView.swift
//  OPToolkit
//
//  「デッキカードを選択する」ボタンから開く画面。
//  カード一覧画面と同じグリッド表示。リーダーは除外して表示する。
//  色フィルタはリーダーの色で固定（フィルタシート内では変更不可）。
//  カードをタップすると枚数指定モーダルが出る。
//
//  以前は1枚確定するたびに画面が閉じてデッキ詳細に戻ってしまっていたが、
//  選んだ内容は即座にデッキへ反映されつつ、この画面は開いたままにして
//  続けて何枚でも選べるようにした。画面上部に現在の合計枚数を常に表示し、
//  終わったら「完了」で閉じる（添付の参考画像のように、デッキの状態を
//  見ながらカードリストから選び続けられる形に近づけている）。
//

import SwiftUI

struct DeckCardSelectView: View {
    @State var viewModel: DeckCardSelectViewModel
    let currentQuantity: (Card) -> Int
    /// 現在デッキに入っているカード（画面上部のプレビュー表示用）
    let deckEntries: () -> [DeckEntry]
    let onConfirm: (Card, Int) -> Void
    let onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredCards) { card in
                            CardImageCell(card: card)
                                .overlay(alignment: .bottomTrailing) {
                                    let quantity = currentQuantity(card)
                                    if quantity > 0 {
                                        Text("×\(quantity)")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(4)
                                            .background(.blue, in: Capsule())
                                            .foregroundStyle(.white)
                                            .padding(3)
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        viewModel.selectCard(card)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
                .safeAreaInset(edge: .top) {
                    addedCardsPreview
                }
                .navigationTitle("デッキカードを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完了", action: onClose)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    filterButton
                }
                .fullScreenCover(isPresented: $viewModel.isFilterSheetPresented) {
                    CardSearchSheet(
                        criteria: viewModel.criteria,
                        lockedColors: [viewModel.lockedColor],
                        onSearch: { newCriteria in
                            viewModel.applySearch(newCriteria)
                            viewModel.isFilterSheetPresented = false
                        },
                        onCancel: {
                            viewModel.isFilterSheetPresented = false
                        }
                    )
                }
                .task {
                    await viewModel.loadCards()
                }
            }

            if let card = viewModel.selectedCard {
                CardQuantityModal(
                    card: card,
                    initialQuantity: currentQuantity(card),
                    onConfirm: { quantity in
                        onConfirm(card, quantity)
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.selectedCard = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.selectedCard = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(1)
            }
        }
    }

    /// 画面上部：現在デッキに入っているカードのサムネイルを横スクロールで並べる。
    /// 選んだカードがその場で追加されていくのが見えるようにするための領域。
    private var addedCardsPreview: some View {
        let entries = deckEntries()
        let total = entries.reduce(0) { $0 + $1.quantity }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("現在のデッキ")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(total)/50")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(total == 50 ? .green : .primary)
            }
            .padding(.horizontal, 16)

            if entries.isEmpty {
                Text("まだカードが選択されていません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entries) { entry in
                            addedCardThumbnail(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.top, 10)
        .background(.ultraThinMaterial)
    }

    private func addedCardThumbnail(_ entry: DeckEntry) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(uiColor: .systemGray5))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .frame(width: 44)
            .overlay {
                // TODO: 実画像に差し替え（entry.card.imageName）
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("×\(entry.quantity)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(3)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(2)
            }
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) {
                    viewModel.selectCard(entry.card)
                }
            }
    }

    private var filterButton: some View {
        Button {
            viewModel.isFilterSheetPresented = true
        } label: {
            Image(systemName: "camera.filters")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("フィルタ・並び替え")
    }
}

#Preview {
    DeckCardSelectView(
        viewModel: DeckCardSelectViewModel(lockedColor: .red, repository: MockCardRepository()),
        currentQuantity: { _ in 0 },
        deckEntries: { [DeckEntry(card: .sampleZoro, quantity: 3)] },
        onConfirm: { _, _ in },
        onClose: {}
    )
}
