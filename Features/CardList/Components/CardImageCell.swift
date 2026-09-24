//
//  CardImageCell.swift
//  OPToolkit
//
//  グリッド1マス分のカード画像セル。
//  カード比率(約2.5:3.5)を保ったまま、GridItem(.flexible())の幅に追従する。
//

import SwiftUI

struct CardImageCell: View {
    let card: Card

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.secondary.opacity(0.15))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                // TODO: 実画像に差し替え（card.imageName を AsyncImage や Image(_:) で表示）
                if let imageName = card.imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                        Text(card.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 2)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("\(card.cost)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .background(.black.opacity(0.6), in: Circle())
                    .foregroundStyle(.white)
                    .padding(3)
            }
            .contentShape(Rectangle())   // 透明部分もタップ判定に含める
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
        ForEach(Card.samples) { card in
            CardImageCell(card: card)
        }
    }
    .padding()
}
