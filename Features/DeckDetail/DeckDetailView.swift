//
//  DeckDetailView.swift
//  OPToolkit
//
//  ③デッキ詳細画面
//  リーダー・デッキカードの表示/選択、デッキ名編集、保存、
//  各種集計（枚数内訳・コスト棒グラフ・特徴別枚数）、メモを1画面にまとめる。
//
//  .toolbar(.hidden, for: .tabBar) で、この画面以降（リーダー選択・カード選択を含む）は
//  タブバーを表示しない。想定外の画面遷移を避けるため。
//

import SwiftUI

struct DeckDetailView: View {
    @State var viewModel: DeckDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let thumbnailColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                deckNameField

                leaderSection

                deckCardsSection

                Divider()

                Text("情報")
                    .font(.headline)
                DeckStatsGrid(deck: viewModel.deck)

                Text("コスト")
                    .font(.headline)
                CostBarChart(histogram: viewModel.deck.costHistogram)
                    .frame(maxWidth: .infinity)

                Text("特徴")
                    .font(.headline)
                FeatureCountList(counts: viewModel.deck.featureCounts)

                Text("メモ")
                    .font(.headline)
                memoField
            }
            .padding(16)
        }
        .navigationTitle(viewModel.isNew ? "デッキ作成" : "デッキ編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    if viewModel.save() {
                        dismiss()
                    }
                }
            }
        }
        .alert(
            "保存できません",
            isPresented: Binding(
                get: { viewModel.saveErrorMessage != nil },
                set: { if !$0 { viewModel.saveErrorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.saveErrorMessage = nil }
        } message: {
            Text(viewModel.saveErrorMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.isShowingLeaderSelect) {
            LeaderSelectView(
                viewModel: LeaderSelectViewModel(),
                onSelect: { card in viewModel.setLeader(card) },
                onCancel: { viewModel.isShowingLeaderSelect = false }
            )
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCardSelect) {
            if let leaderColor = viewModel.deck.leaderCard?.color {
                DeckCardSelectView(
                    viewModel: DeckCardSelectViewModel(lockedColor: leaderColor),
                    currentQuantity: { viewModel.currentQuantity(of: $0) },
                    deckEntries: { viewModel.deck.cardEntries },
                    onConfirm: { card, quantity in viewModel.setQuantity(quantity, for: card) },
                    onClose: { viewModel.isShowingCardSelect = false }
                )
            }
        }
    }

    // MARK: - デッキ名

    private var deckNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("デッキ名")
                .font(.headline)
            TextField("デッキ名を入力", text: $viewModel.deck.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - リーダー

    private var leaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リーダー")
                .font(.headline)

            HStack(spacing: 12) {
                cardThumbnail(viewModel.deck.leaderCard, width: 90)

                if viewModel.isNew {
                    Button {
                        viewModel.isShowingLeaderSelect = true
                    } label: {
                        Label(
                            viewModel.deck.leaderCard == nil ? "リーダーカードを選択する" : "リーダーを変更する",
                            systemImage: "person.crop.rectangle"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - デッキカード

    private var deckCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("デッキカード（\(viewModel.deck.totalCardCount)枚）")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isShowingCardSelect = true
                } label: {
                    Label("デッキカードを選択する", systemImage: "rectangle.stack.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.deck.leaderCard == nil)
            }

            if viewModel.deck.cardEntries.isEmpty {
                Text("まだカードが選択されていません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: thumbnailColumns, spacing: 8) {
                    ForEach(viewModel.deck.cardEntries) { entry in
                        cardThumbnail(entry.card, width: 50)
                            .overlay(alignment: .bottomTrailing) {
                                Text("×\(entry.quantity)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(3)
                                    .background(.black.opacity(0.7), in: Capsule())
                                    .foregroundStyle(.white)
                                    .padding(2)
                            }
                    }
                }
            }
        }
    }

    private func cardThumbnail(_ card: Card?, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(uiColor: .systemGray5))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .frame(width: width)
            .overlay {
                if let card {
                    // TODO: 実画像に差し替え（card.imageName）
                    Text(card.name)
                        .font(.system(size: 8))
                        .multilineTextAlignment(.center)
                        .padding(2)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "questionmark")
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - メモ

    private var memoField: some View {
        TextEditor(text: $viewModel.deck.memo)
            .frame(height: 120)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        DeckDetailView(viewModel: DeckDetailViewModel(deck: .sample, isNew: false, onSave: {}))
    }
}
