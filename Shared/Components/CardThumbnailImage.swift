//
//  CardThumbnailImage.swift
//  OPToolkit
//
//  カード画像を2.5:3.5の枠いっぱいに表示する共通サムネイル。
//  KFImageは.resizable()を付けないと原寸で描画され枠からはみ出すため、
//  .resizable() + .aspectRatio(.fill) + clipShape を1か所にまとめている。
//  サイズは呼び出し側で .frame(width:) を指定する（高さは比率から決まる）。
//

import SwiftUI
import Kingfisher

struct CardThumbnailImage: View {
    /// nilのときは「？」のプレースホルダーを表示する（リーダー未選択など）
    let card: Card?
    var cornerRadius: CGFloat = 6

    var body: some View {
        Color(uiColor: .systemGray5)
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                if let card {
                    KFImage(card.imageURL)
                        .placeholder { ProgressView() }
                        .fade(duration: 0.15)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "questionmark")
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    HStack {
        CardThumbnailImage(card: .sampleZoro).frame(width: 60)
        CardThumbnailImage(card: nil).frame(width: 60)
    }
    .padding()
}
