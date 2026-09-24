//
//  LeaderSelectView.swift
//  OPToolkit
//
//  「リーダーカードを選択する」ボタンから開く画面。
//  カード一覧画面と同じグリッド表示だが、表示するのはリーダーのみ。
//  フィルタボタンは無し。検索窓の下（元々タブがあった場所）に色フィルタとパラレル表示切替を置く。
//  カードをタップするとそのままリーダーとして選択される。。
//

import SwiftUI

struct LeaderSelectView: View {
    @State var viewModel: LeaderSelectViewModel
    let onSelect: (Card) -> Void
    let onCancel: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.filteredCards) { card in
                        CardImageCell(card: card)
                            .onTapGesture {
                                onSelect(card)
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .navigationTitle("リーダーを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                await viewModel.loadCards()
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            searchField
            colorFilterRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("カード名・番号で検索", text: $viewModel.searchText)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
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

    private var colorFilterRow: some View {
        HStack(spacing: 6) {
            ForEach(CardColor.allCases) { color in
                FilterChip(
                    label: color.rawValue,
                    tint: color.tint,
                    isSelected: viewModel.selectedColors.contains(color)
                ) {
                    if viewModel.selectedColors.contains(color) {
                        viewModel.selectedColors.remove(color)
                    } else {
                        viewModel.selectedColors.insert(color)
                    }
                }
            }

            // パラレル表示切替（星アイコン）。タップで ノーマルのみ→混在→パラレルのみ… と循環する。
            Button {
                viewModel.parallelMode.advance()
            } label: {
                Image(systemName: viewModel.parallelMode.symbolName)
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .systemGray5), in: Circle())
            }
            .accessibilityLabel("パラレル表示切替")
        }
    }
}

#Preview {
    LeaderSelectView(
        viewModel: LeaderSelectViewModel(repository: MockCardRepository()),
        onSelect: { _ in },
        onCancel: {}
    )
}
