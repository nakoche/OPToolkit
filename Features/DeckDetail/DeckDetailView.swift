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

    private enum Field: Hashable {
        case name, memo
    }
    @FocusState private var focusedField: Field?

    /// 変更がある状態で戻ろうとしたときの確認（破棄 / 保存 / キャンセル）
    @State private var isShowingDiscardAlert = false

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
            // キーボード以外の場所をタップしたらキーボードを閉じる
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
        .scrollDismissesKeyboard(.interactively)
        // 下に浮かせた保存ボタンがメモに重なって見えなくならないよう、スクロール末尾に余白を足す
        .contentMargins(.bottom, 88, for: .scrollContent)
        .overlay(alignment: .bottom) {
            saveButton
        }
        .navigationTitle(viewModel.isNew ? "デッキ作成" : "デッキ編集")
        .navigationBarTitleDisplayMode(.inline)
        // 変更がある場合に確認を出すため、標準の戻るボタンは使わず、自前の戻るボタンにする
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: handleBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .fontWeight(.semibold)
                        Text("戻る")
                    }
                }
            }
        }
        // 左端からのスワイプで戻る操作も、変更があるときは確認を出す
        .background {
            BackSwipeInterceptor(
                isEnabled: viewModel.hasChanges,
                onIntercept: { isShowingDiscardAlert = true }
            )
        }
        .alert("変更内容があります", isPresented: $isShowingDiscardAlert) {
            Button("保存して戻る") {
                if viewModel.save() {
                    dismiss()
                }
            }
            Button("破棄して戻る", role: .destructive) {
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("保存せずに戻ると、変更内容は破棄されます")
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
            if let leader = viewModel.deck.leaderCard {
                DeckCardSelectView(
                    viewModel: DeckCardSelectViewModel(lockedColors: Set(leader.colors)),
                    currentQuantity: { viewModel.currentQuantity(of: $0) },
                    deckEntries: { viewModel.deck.cardEntries },
                    onConfirm: { card, quantity in viewModel.setQuantity(quantity, for: card) },
                    onClose: { viewModel.isShowingCardSelect = false }
                )
            }
        }
    }

    // MARK: - 戻る・保存

    private func handleBack() {
        if viewModel.hasChanges {
            isShowingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    /// 下の中央に浮かせた保存ボタン。キーボードの入力中は、入力欄に重ならないよう隠す。
    @ViewBuilder
    private var saveButton: some View {
        if focusedField == nil {
            Button {
                if viewModel.save() {
                    dismiss()
                }
            } label: {
                Text("保存")
                    .font(.headline)
                    .frame(width: 160)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .shadow(radius: 4, y: 2)
            .padding(.bottom, 20)
        }
    }

    // MARK: - デッキ名

    private var deckNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("デッキ名")
                .font(.headline)
            TextField("デッキ名を入力", text: $viewModel.deck.name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
        }
    }

    // MARK: - リーダー

    private var leaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("リーダー")
                .font(.headline)

            cardThumbnail(viewModel.deck.leaderCard, width: 90)

            if viewModel.isNew {
                Button {
                    viewModel.isShowingLeaderSelect = true
                } label: {
                    Label(
                        viewModel.deck.leaderCard == nil ? "リーダーカードを選択する" : "リーダーを変更する",
                        systemImage: "person.crop.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - デッキカード

    private var deckCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("デッキカード（\(viewModel.deck.totalCardCount)枚）")
                .font(.headline)

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

            Button {
                viewModel.isShowingCardSelect = true
            } label: {
                Label("デッキカードを選択する", systemImage: "rectangle.stack.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.deck.leaderCard == nil)
        }
    }

    private func cardThumbnail(_ card: Card?, width: CGFloat) -> some View {
        CardThumbnailImage(card: card, cornerRadius: 6)
            .frame(width: width)
    }

    // MARK: - メモ

    private var memoField: some View {
        TextEditor(text: $viewModel.deck.memo)
            .focused($focusedField, equals: .memo)
            .frame(height: 120)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        DeckDetailView(
            viewModel: DeckDetailViewModel(
                deck: .sample,
                isNew: false,
                // プレビューでは実際の保存ファイルを触らないよう、一時ファイルを指すストアを使う
                deckStore: DeckStore(
                    cardRepository: MockCardRepository(),
                    fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-decks.json")
                ),
                onSave: {}
            )
        )
    }
}
