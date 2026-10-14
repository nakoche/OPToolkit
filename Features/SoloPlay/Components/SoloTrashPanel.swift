//
//  SoloTrashPanel.swift
//  OPToolkit
//
//  トラッシュの一覧パネル。
//  - 並び順は、デフォルトが「落ちた順」（新しいカードが先頭）。
//    「同名まとめ・一覧順」に切り替えると、同名のカードを揃えて、カード一覧画面と同じ発売順に並べる。
//  - カードを下のタイルへドラッグして、手札・場・デッキの上/下・ライフの上へ戻せる。
//  - 「詳細」ボタンを押してからカードをタップすると、詳細を表示する。
//

import SwiftUI

struct SoloTrashPanel: View {
    let viewModel: SoloPlayViewModel
    let owner: Perspective

    /// true: 同名まとめ・一覧順、false: 落ちた順
    @State private var isGroupedByName = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var trash: [CardInstance] { viewModel.current[owner].trash }

    private var displayed: [CardInstance] {
        isGroupedByName ? Self.groupedByName(trash) : trash
    }

    private var columnCount: Int {
        horizontalSizeClass == .regular ? 8 : 5
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            Picker("並び順", selection: $isGroupedByName) {
                Text("落ちた順").tag(false)
                Text("同名まとめ・一覧順").tag(true)
            }
            .pickerStyle(.segmented)

            cardGrid

            Divider()

            SoloPanelDropTiles(
                viewModel: viewModel,
                owner: owner,
                // トラッシュの中から、トラッシュへ送る意味はないので除く
                tiles: SoloPanelTile.allCases.filter { $0 != .trash },
                // タイルは5つなので、右下の空きに「閉じる」を置く
                onClose: { viewModel.activePanel = nil }
            )
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
        .frame(maxWidth: 560)
    }

    // MARK: - 見出し

    private var header: some View {
        HStack {
            Text("トラッシュ（\(owner == .playerOne ? "先攻" : "後攻")）")
                .font(.headline)

            Spacer()

            Text("\(trash.count)枚")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.activePanel = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("閉じる")
        }
    }

    // MARK: - カード一覧

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount),
                spacing: 6
            ) {
                ForEach(displayed) { instance in
                    CardThumbnailImage(card: instance.card, cornerRadius: 4)
                        .onTapGesture {
                            viewModel.showDetailIfNeeded(instance, owner: owner)
                        }
                        .draggable(SoloDragItem(owner: owner, content: .card(instance.id))) {
                            CardThumbnailImage(card: instance.card, cornerRadius: 4)
                                .frame(width: 64)
                        }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 120, maxHeight: 320)
        .overlay {
            if trash.isEmpty {
                Text("トラッシュにカードはありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 同名まとめ・一覧順

    /// 同名のカードを揃え、カード一覧画面と同じ発売順（CardReleaseOrder）に並べる。
    /// - グループの並び: 各名前の中で、一覧順がいちばん先のカードの位置に従う
    /// - 同じ名前の中: 一覧順。同じカード同士は、落ちた順のまま
    private static func groupedByName(_ trash: [CardInstance]) -> [CardInstance] {
        let distinctCards = Array(Set(trash.map { $0.card }))
        let sortedCards = CardReleaseOrder.sorted(distinctCards, direction: .ascending)

        var cardRank: [String: Int] = [:]   // カード番号 → 一覧での順位
        var nameRank: [String: Int] = [:]   // 名前 → その名前の最初のカードの順位
        for (index, card) in sortedCards.enumerated() {
            cardRank[card.cardNumber] = index
            if nameRank[card.name] == nil {
                nameRank[card.name] = index
            }
        }

        return trash.enumerated()
            .sorted { lhs, rhs in
                let lName = nameRank[lhs.element.card.name] ?? 0
                let rName = nameRank[rhs.element.card.name] ?? 0
                if lName != rName { return lName < rName }

                let lCard = cardRank[lhs.element.card.cardNumber] ?? 0
                let rCard = cardRank[rhs.element.card.cardNumber] ?? 0
                if lCard != rCard { return lCard < rCard }

                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }
}
