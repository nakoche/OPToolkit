//
//  CardImageCell.swift
//  OPToolkit
//
//  カードリスト画面（LazyVGrid 1行5枚）の1マス分。
//  KFImage(Kingfisher)で画像を外部取得し、メモリ/ディスクキャッシュを効かせる。
//  一覧表示は表示コマ数が多いため、.downsampling()でセルサイズに合わせて
//  デコード時点から縮小し、メモリ使用量を抑える。
//

import SwiftUI
import Kingfisher

struct CardImageCell: View {
    let card: Card

    // トレーディングカードの標準比率（63mm×88mm相当）
    private let cardAspectRatio: CGFloat = 63.0 / 88.0

    var body: some View {
        GeometryReader { geometry in
            KFImage(card.imageURL)
                .placeholder { placeholder }
                // 一覧に大量表示するため、セルサイズにダウンサンプリングしてメモリ節約
                .setProcessor(
                    DownsamplingImageProcessor(
                        size: CGSize(width: geometry.size.width * 2, height: geometry.size.height * 2)
                    )
                )
                .cacheOriginalImage() // フル解像度もディスクに保持（詳細画面で再利用できる）
                .fade(duration: 0.15)
                .retry(maxCount: 2, interval: .seconds(1))
                .resizable()
                .aspectRatio(cardAspectRatio, contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(cardAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay(
                ProgressView()
                    .controlSize(.small)
            )
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)) {
        ForEach(Card.samples.prefix(10)) { card in
            CardImageCell(card: card)
        }
    }
    .padding()
}
