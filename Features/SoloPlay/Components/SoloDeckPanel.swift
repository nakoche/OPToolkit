//
//  SoloDeckPanel.swift
//  OPToolkit
//
//  山札を上から見る（サーチ）パネル。
//  - 開くと、山札の上から N 枚が裏向きで並ぶ（N は 3 / 4 / 5 から選ぶ。最後に選んだ枚数を覚える）
//  - 裏向きのカードをタップすると表になる（もう一度タップすると裏に戻る）
//  - 下のタイルへカードをドラッグして、手札・場・デッキの上/下・ライフの上・トラッシュへ送る
//  - 「1枚追加」で、さらに1枚見る。「全部めくる」で、見ているカードをすべて表にする
//  - 「残りをすべてデッキの下へ」: サーチの定番（1枚を手札に加え、残りをデッキの下へ）を1回で行い、パネルを閉じる
//
//  見ているカードは「開いた時点の上からN枚」で固定する。カードを取り出しても、
//  次のカードが勝手に繰り上がって見えることはない（見たいときは「1枚追加」を使う）。
//  表にしたかどうかは、このパネルの中だけの状態で、閉じると全部裏向きに戻る（山札の並びはそのまま）。
//

import SwiftUI

struct SoloDeckPanel: View {
    let viewModel: SoloPlayViewModel
    let owner: Perspective

    @AppStorage(SettingsStore.Key.soloDeckLookCount) private var lookCount = 5
    /// 見ているカードのid（山札の中の順番は、山札側の並びに従う）
    @State private var viewedIDs: Set<UUID>
    /// 表にしたカードのid
    @State private var revealedIDs: Set<UUID> = []

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let lookCountOptions = [3, 4, 5]

    init(viewModel: SoloPlayViewModel, owner: Perspective) {
        self.viewModel = viewModel
        self.owner = owner

        // 開いた直後から、前回選んだ枚数ぶんを見せる（@AppStorageは init の時点では読めないので直接読む）
        let saved = UserDefaults.standard.object(forKey: SettingsStore.Key.soloDeckLookCount) as? Int ?? 5
        let topIDs = viewModel.current[owner].deck.prefix(max(saved, 0)).map { $0.id }
        _viewedIDs = State(initialValue: Set(topIDs))
    }

    private var board: PlayerBoard { viewModel.current[owner] }

    /// 見ているカード（山札の上から順）
    private var displayed: [CardInstance] {
        board.deck.filter { viewedIDs.contains($0.id) }
    }

    /// まだ見ていない、山札の一番上のカード
    private var nextUnviewed: CardInstance? {
        board.deck.first { !viewedIDs.contains($0.id) }
    }

    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 96 : 64
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            controls
            cardsRow

            Divider()

            SoloPanelDropTiles(
                viewModel: viewModel,
                owner: owner,
                tiles: SoloPanelTile.allCases,
                onMoved: handleMoved
            )

            bottomButtons
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
        .frame(maxWidth: 560)
    }

    // MARK: - 見出し

    private var header: some View {
        HStack {
            Text("山札を見る（\(owner == .playerOne ? "先攻" : "後攻")）")
                .font(.headline)

            Spacer()

            Text("残り \(board.deck.count)枚")
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

    // MARK: - 見る枚数

    private var controls: some View {
        HStack(spacing: 8) {
            Text("見る枚数")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(lookCountOptions, id: \.self) { count in
                Button {
                    selectLookCount(count)
                } label: {
                    Text("\(count)")
                        .font(.subheadline.bold())
                        .frame(width: 36, height: 32)
                        .foregroundStyle(lookCount == count ? Color.white : Color.primary)
                        .background(
                            lookCount == count ? Color.accentColor : Color.secondary.opacity(0.2),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                if let next = nextUnviewed {
                    viewedIDs.insert(next.id)
                }
            } label: {
                Label("1枚追加", systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(nextUnviewed == nil)
        }
    }

    // MARK: - 見ているカード

    private var cardsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(displayed) { instance in
                    cardView(instance)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: cardWidth * 1.4 + 8)
        .overlay {
            if displayed.isEmpty {
                Text("見ているカードはありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }

    private func cardView(_ instance: CardInstance) -> some View {
        let isRevealed = revealedIDs.contains(instance.id)

        return Group {
            if isRevealed {
                CardThumbnailImage(card: instance.card, cornerRadius: 4)
            } else {
                CardBackImage(cornerRadius: 4)
            }
        }
        .frame(width: cardWidth)
        .onTapGesture {
            // 詳細モードなら詳細表示（裏向きのカードは、中身を見せないので表示しない）
            if viewModel.showDetailIfNeeded(instance, owner: owner, isFaceUp: isRevealed) { return }

            if isRevealed {
                revealedIDs.remove(instance.id)
            } else {
                revealedIDs.insert(instance.id)
            }
        }
        .draggable(SoloDragItem(owner: owner, content: .card(instance.id))) {
            Group {
                if isRevealed {
                    CardThumbnailImage(card: instance.card, cornerRadius: 4)
                } else {
                    CardBackImage(cornerRadius: 4)
                }
            }
            .frame(width: cardWidth)
        }
    }

    // MARK: - 下のボタン

    private var bottomButtons: some View {
        HStack(spacing: 8) {
            Button {
                revealedIDs.formUnion(displayed.map { $0.id })
            } label: {
                Text("全部めくる")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(displayed.isEmpty)

            Button {
                // 見ているカードを、今の並びのままデッキの下へ送る（Undoは1回分）
                viewModel.moveCards(displayed.map { $0.id }, owner: owner, to: .deck, position: .bottom)
                viewModel.activePanel = nil
            } label: {
                Text("残りをすべてデッキの下へ")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(displayed.isEmpty)
        }
    }

    // MARK: - 状態の更新

    private func selectLookCount(_ count: Int) {
        lookCount = count
        viewedIDs = Set(board.deck.prefix(count).map { $0.id })
        revealedIDs.formIntersection(viewedIDs)
    }

    /// カードを動かせたあとの後始末。デッキの下へ送ったカードは、もう上から見ている範囲ではないので外す
    /// （手札やトラッシュへ送ったカードは、山札から無くなるので自動的に一覧から消える）。
    private func handleMoved(_ id: UUID, _ tile: SoloPanelTile) {
        if tile == .deckBottom {
            viewedIDs.remove(id)
            revealedIDs.remove(id)
        }
    }
}
