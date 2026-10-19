//
//  DeckListView.swift
//  OPToolkit
//
//  ②デッキ画面
//  - 各デッキを1行で表示（左: リーダー画像 / 右上: デッキ名 / 右下: 対戦履歴・画像表示・コピー）
//  - 左スワイプで削除（確認モーダルあり）
//  - 行右端のハンドルをドラッグして並び替え
//  - 右下にデッキ作成ボタン、その上にQR読み込みボタン（画像の配置に合わせたフローティングボタン）
//  - デッキタップでデッキ詳細画面へ
//
//  bodyにmodifierを全部つなげると「型チェックが終わらない」コンパイルエラーになるため、
//  遷移先・アラート・オーバーレイは別のプロパティ／ViewModifierに切り出している。
//

import SwiftUI

/// デッキ一覧からの画面遷移先
enum DeckListRoute: Hashable {
    case existing(Deck)
    case new
    case battleHistory(Deck)
}

struct DeckListView: View {
    @State var viewModel: DeckListViewModel
    @State private var path = NavigationPath()

    // ドラッグハンドルでの並び替え用
    private let rowSwapThreshold: CGFloat = 60
    @State private var dragState: (id: UUID, offset: CGFloat)?

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
                .navigationTitle("デッキ")
                .task {
                    await viewModel.load()
                }
                .navigationDestination(for: DeckListRoute.self) { route in
                    destinationView(for: route)
                }
                .modifier(DeckListAlerts(viewModel: viewModel))
                // QRスキャナー
                .fullScreenCover(isPresented: $viewModel.isShowingScanner) {
                    QRScannerView(
                        onScan: { viewModel.handleScannedQRString($0) },
                        onCancel: { viewModel.isShowingScanner = false }
                    )
                }
                // 画像表示モーダル（保存ボタン付き）
                .overlay { imagePreviewOverlay }
                // 画像生成中のインジケーター（カード画像の取得待ち）
                .overlay { generatingOverlay }
        }
    }

    // MARK: - 本体（一覧＋フローティングボタン）

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            deckListContent
            floatingButtons
        }
    }

    @ViewBuilder
    private var deckListContent: some View {
        if !viewModel.hasLoaded {
            ProgressView()
        } else if viewModel.decks.isEmpty {
            ContentUnavailableView(
                "デッキがありません",
                systemImage: "square.stack.3d.up.slash",
                description: Text("右下の「＋」からデッキを作成できます")
            )
        } else {
            List {
                ForEach(Array(viewModel.decks.enumerated()), id: \.element.id) { index, deck in
                    deckRow(deck: deck, index: index)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - 画面遷移先

    @ViewBuilder
    private func destinationView(for route: DeckListRoute) -> some View {
        switch route {
        case .existing(let deck):
            DeckDetailView(viewModel: makeDetailViewModel(deck: deck, isNew: false))
        case .new:
            DeckDetailView(viewModel: makeDetailViewModel(deck: Deck(name: "新しいデッキ"), isNew: true))
        case .battleHistory(let deck):
            BattleHistoryView(
                viewModel: BattleHistoryViewModel(deck: deck, store: viewModel.historyStore)
            )
        }
    }

    private func makeDetailViewModel(deck: Deck, isNew: Bool) -> DeckDetailViewModel {
        DeckDetailViewModel(
            deck: deck,
            isNew: isNew,
            deckStore: viewModel.store,
            onSave: { viewModel.reloadFromStore() }
        )
    }

    // MARK: - オーバーレイ

    @ViewBuilder
    private var imagePreviewOverlay: some View {
        if let image = viewModel.shareImage {
            DeckImagePreviewModal(image: image) {
                viewModel.shareImage = nil
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var generatingOverlay: some View {
        if viewModel.isGeneratingImage {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("画像を作成中…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 右下のフローティングボタン（QR読み込み・デッキ作成）

    private var floatingButtons: some View {
        VStack(spacing: 14) {
            Button {
                viewModel.isShowingScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color(red: 0.55, green: 0.28, blue: 0.4), in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .accessibilityLabel("QRから作成")

            Button {
                path.append(DeckListRoute.new)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.indigo, in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .accessibilityLabel("デッキ作成")
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - 行

    @ViewBuilder
    private func deckRow(deck: Deck, index: Int) -> some View {
        HStack(spacing: 8) {
            DeckRow(
                deck: deck,
                onOpenDetail: { path.append(DeckListRoute.existing(deck)) },
                onBattleHistory: { path.append(DeckListRoute.battleHistory(deck)) },
                onShowImage: { Task { await viewModel.generateShareImage(for: deck) } },
                onCopy: { viewModel.copyDeck(deck) }
            )

            // 並び替え用ハンドル（ハンバーガーメニューの2本バージョン）。
            // 押しながら上下にドラッグすると、しきい値を超えるたびに隣と入れ替わる。
            Image(systemName: "equal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 44)
                .contentShape(Rectangle())
                .gesture(dragGesture(for: deck, index: index))
        }
        .offset(y: dragState?.id == deck.id ? dragState!.offset : 0)
        .zIndex(dragState?.id == deck.id ? 1 : 0)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(Color.clear)
        // 左スワイプ = 削除（確認モーダル経由）
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.requestDelete(deck)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func dragGesture(for deck: Deck, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragState == nil {
                    dragState = (deck.id, 0)
                }
                dragState?.offset = value.translation.height

                guard let offset = dragState?.offset else { return }
                if offset > rowSwapThreshold, index < viewModel.decks.count - 1 {
                    viewModel.swapAdjacent(index, with: index + 1)
                    dragState?.offset -= rowSwapThreshold
                } else if offset < -rowSwapThreshold, index > 0 {
                    viewModel.swapAdjacent(index, with: index - 1)
                    dragState?.offset += rowSwapThreshold
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragState = nil
                }
            }
    }
}

// MARK: - アラート（保存エラー・削除確認・QR読み込みエラー）

/// デッキ画面の3つのアラートをまとめたmodifier。
/// bodyに直接つなげるとコンパイラの型チェックが終わらなくなるため、切り出している。
private struct DeckListAlerts: ViewModifier {
    let viewModel: DeckListViewModel

    func body(content: Content) -> some View {
        content
            // デッキの保存（ディスクへの書き込み）に失敗したときの通知
            .alert(
                "保存できません",
                isPresented: storageErrorBinding
            ) {
                Button("OK") { viewModel.storageErrorMessage = nil }
            } message: {
                Text(viewModel.storageErrorMessage ?? "")
            }
            // 削除確認モーダル（.confirmationDialogは環境によって行の近く＝画面上部寄りに出てしまうことがあるため、
            // 画面中央に出る.alertを使う。キャンセル(.cancel)を先に書くと自動的に左、削除(.destructive)が右に並ぶ。
            .alert(
                "「\(viewModel.pendingDeleteDeck?.name ?? "")」を削除しますか？",
                isPresented: deleteBinding
            ) {
                Button("キャンセル", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("削除する", role: .destructive) {
                    viewModel.confirmDelete()
                }
            } message: {
                Text("この操作は取り消せません")
            }
            // QR読み込みエラー
            .alert(
                "読み込みエラー",
                isPresented: scanErrorBinding
            ) {
                Button("OK") { viewModel.scanErrorMessage = nil }
            } message: {
                Text(viewModel.scanErrorMessage ?? "")
            }
    }

    private var storageErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.storageErrorMessage != nil },
            set: { if !$0 { viewModel.storageErrorMessage = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeleteDeck != nil },
            set: { if !$0 { viewModel.cancelDelete() } }
        )
    }

    private var scanErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.scanErrorMessage != nil },
            set: { if !$0 { viewModel.scanErrorMessage = nil } }
        )
    }
}

#Preview {
    DeckListView(
        viewModel: DeckListViewModel(
            battleHistoryStore: BattleHistoryStore(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-battle-history.json")
            )
        )
    )
}
