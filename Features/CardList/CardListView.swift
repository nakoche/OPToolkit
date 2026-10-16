//
//  CardListView.swift
//  OPToolkit
//
//  ①カードリスト画面。ロジックは全てCardListViewModelに委譲する。
//  1行5枚のグリッドでカード画像を並べる。
//
//  画面下部（タブバーのすぐ上）に固定フッターを置き、
//  1段目にフィルタボタン、2段目にカード名・番号の検索欄を配置する。
//  .searchable（ナビゲーションバー内蔵の検索欄）ではなく自前のフッターにしているのは、
//  「タブバーの真上のライン」という指定の位置に検索欄を固定するため。
//  criteria.searchTextに直接バインドしているので、入力するたびに
//  即座にfilteredCardsへ反映される（シート経由の確定操作は不要）。
//
//  カード詳細は下から出るモーダルではなく、その場にふっと浮かび上がる形で表示する。
//  Q&Aがあるカードは、詳細モーダルの中のQ&Aボタンで、画像が小さくなってQ&Aの一覧に切り替わる。
//  詳細モーダルの♡ボタンでお気に入りを切り替え、フィルタ画面の「♡」で絞り込める。
//

import SwiftUI

struct CardListView: View {
    @State var viewModel: CardListViewModel

    // 1行5枚。列間・行間のspacingはCardImageCell側の見た目に合わせて調整。
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredCards) { card in
                            CardImageCell(card: card)
                                // お気に入りのカードには、左下に♡の印を付ける
                                .overlay(alignment: .bottomLeading) {
                                    if viewModel.isFavorite(card) {
                                        favoriteMark
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
                .navigationTitle("カードリスト")
                // ScrollViewの外側（safeAreaInset）に固定フッターを敷くことで、
                // スクロールしても位置が動かず、タブバーのすぐ上に張り付く。
                .safeAreaInset(edge: .bottom) {
                    bottomBar
                }
                // .sheetではなく.fullScreenCoverを使う。
                // .sheetは「下スワイプで閉じる」ジェスチャー認識器が常駐しており、
                // interactiveDismissDisabled(true)にしても“閉じない”だけで判定処理は残るため、
                // Form内のスクロール開始が一瞬遅延する（判定待ちのラグ）原因になっていた。
                // fullScreenCoverにはそもそも閉じるジェスチャーが存在しないため、この競合が起きない。
                .fullScreenCover(isPresented: $viewModel.isSearchSheetPresented) {
                    CardSearchSheet(
                        criteria: viewModel.criteria,
                        showsFavoriteFilter: true,
                        onSearch: { newCriteria in
                            viewModel.applySearch(newCriteria)
                            viewModel.isSearchSheetPresented = false
                        },
                        onCancel: {
                            viewModel.isSearchSheetPresented = false
                        }
                    )
                }
                .task {
                    await viewModel.loadCards()
                }
            }

            // カード詳細: システムのシート/フルスクリーンカバーは使わず、
            // その場にオーバーレイとしてフェード＋拡大で出す（下からのスライドにしない）。
            if let card = viewModel.selectedCard {
                // 画像の下に、♡（お気に入り）ボタンと、Q&Aボタン（Q&Aがあるカードだけ）が出る。
                // パラレルのQ&Aは、自分の番号に無ければ元のカードのものを使う。
                CardDetailModal(
                    card: card,
                    qaItems: viewModel.qaItems(for: card),
                    favorite: FavoriteControl(
                        isFavorite: viewModel.isFavorite(card),
                        onToggle: { viewModel.toggleFavorite(card) }
                    ),
                    onClose: {
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

    /// グリッド上のカード画像の左下に付ける、お気に入りの印
    private var favoriteMark: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.pink)
            .padding(4)
            .background(.black.opacity(0.6), in: Circle())
            .padding(3)
    }

    // MARK: - 下部固定フッター（1段目: フィルタボタン、2段目: 検索欄）

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                filterButton
            }
            // 検索欄の右にパラレル表示切替を置く（検索欄はボタンの分だけ縮む）
            HStack(spacing: 10) {
                searchField
                ParallelModeButton(mode: $viewModel.parallelMode, size: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    private var filterButton: some View {
        Button {
            viewModel.isSearchSheetPresented = true
        } label: {
            Image(systemName: "camera.filters")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.tint, in: Circle())
        }
        .accessibilityLabel("フィルタ・並び替え")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("カード名・番号で検索", text: $viewModel.criteria.searchText)
            if !viewModel.criteria.searchText.isEmpty {
                Button {
                    viewModel.criteria.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }
}

#Preview {
    CardListView(
        viewModel: CardListViewModel(
            repository: MockCardRepository(),
            qaRepository: MockCardQARepository(),
            // プレビューでは実際の保存ファイルを触らないよう、一時ファイルを指すストアを使う
            favoritesStore: FavoritesStore(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-favorites.json")
            )
        )
    )
}
