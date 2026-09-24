//
//  BoardArea.swift
//  OPToolkit
//
//  盤面表示（プレースホルダー）。TODO: 実際のカード配置UIに置き換え。
//

import SwiftUI

struct BoardArea: View {
    let board: PlayerBoard
    let perspective: Perspective

    var body: some View {
        VStack(spacing: 16) {
            Text(perspective == .playerOne ? "プレイヤー1 視点" : "プレイヤー2 視点")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                StatBadge(title: "デッキ", value: "\(board.deckCount)")
                StatBadge(title: "ライフ", value: "\(board.lifeCount)")
                StatBadge(title: "ドン", value: "\(board.donCount)")
                StatBadge(title: "手札", value: "\(board.hand.count)")
            }

            // TODO: 場のカード（board.field）をグリッド等で表示
            RoundedRectangle(cornerRadius: 12)
                .fill(.secondary.opacity(0.1))
                .overlay(Text("フィールド表示エリア").foregroundStyle(.secondary))
                .padding()
        }
        .padding()
    }
}

#Preview {
    BoardArea(board: PlayerBoard(), perspective: .playerOne)
}
