//
//  SoloPanelDropTiles.swift
//  OPToolkit
//
//  山札パネル・トラッシュパネルの下に並べる、ドロップ先のタイル。
//  パネルの中のカードをタイルへドラッグすると、そのゾーンへ送れる。
//  （手札 / 場に出す / デッキの上 / デッキの下 / ライフの上 / トラッシュ）
//

import SwiftUI

/// パネルのドロップ先の種類
enum SoloPanelTile: String, CaseIterable, Identifiable {
    case hand
    case field
    case deckTop
    case deckBottom
    case lifeTop
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hand: return "手札"
        case .field: return "場に出す"
        case .deckTop: return "デッキの上"
        case .deckBottom: return "デッキの下"
        case .lifeTop: return "ライフの上"
        case .trash: return "トラッシュ"
        }
    }

    var systemImage: String {
        switch self {
        case .hand: return "rectangle.stack"
        case .field: return "square.grid.2x2"
        case .deckTop: return "arrow.up.to.line"
        case .deckBottom: return "arrow.down.to.line"
        case .lifeTop: return "heart"
        case .trash: return "trash"
        }
    }

    /// ドロップされたときの処理先
    var target: SoloDropTarget {
        switch self {
        case .hand: return .zone(.hand)
        case .field: return .field
        case .deckTop: return .zoneAt(.deck, .top)
        case .deckBottom: return .zoneAt(.deck, .bottom)
        case .lifeTop: return .zoneAt(.life, .top)
        case .trash: return .zone(.trash)
        }
    }
}

struct SoloPanelDropTiles: View {
    let viewModel: SoloPlayViewModel
    /// パネルの対象プレイヤー（カードはこの人の盤面にしか動かせない）
    let owner: Perspective
    let tiles: [SoloPanelTile]
    /// カードを動かせたときに呼ばれる（山札パネルが、見ているカードの一覧を更新するために使う）
    var onMoved: (UUID, SoloPanelTile) -> Void = { _, _ in }
    /// 指定すると、タイルの最後に「閉じる」ボタンを並べる（トラッシュパネルの右下の空きに入る）
    var onClose: (() -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tiles) { tile in
                SoloDropZone(onDrop: { drop($0, on: tile) }) {
                    VStack(spacing: 4) {
                        Image(systemName: tile.systemImage)
                            .font(.title3)
                        Text(tile.title)
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if let onClose {
                Button(action: onClose) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.title3)
                        Text("閉じる")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func drop(_ items: [SoloDragItem], on tile: SoloPanelTile) -> Bool {
        let accepted = viewModel.performDrop(items, owner: owner, target: tile.target)
        if accepted {
            SoloHaptics.dropped()
            if let item = items.first, case .card(let id) = item.content {
                onMoved(id, tile)
            }
        } else {
            SoloHaptics.rejected()
        }
        return accepted
    }
}
