//
//  CardImageCell.swift
//  OPToolkit
//
//  カードリスト画面（LazyVGrid 1行5枚）の1マス分。
//  KFImage(Kingfisher)で画像を外部取得し、メモリ/ディスクキャッシュを効かせる。
//  一覧表示は表示コマ数が多いため、.downsampling()でセルサイズに合わせて
//  デコード時点から縮小し、メモリ使用量を抑える。
//

//import SwiftUI
//import Kingfisher
//
//struct CardImageCell: View {
//    let card: Card
//
//    // トレーディングカードの標準比率（63mm×88mm相当）
//    private let cardAspectRatio: CGFloat = 63.0 / 88.0
//
//    var body: some View {
//        GeometryReader { geometry in
//            KFImage(card.thumbnailImageURL)
//                .placeholder { placeholder }
//                // 一覧に大量表示するため、セルサイズにダウンサンプリングしてメモリ節約
//                .setProcessor(
//                    DownsamplingImageProcessor(
//                        size: CGSize(width: geometry.size.width * 2, height: geometry.size.height * 2)
//                    )
//                )
//                .cacheOriginalImage() // フル解像度もディスクに保持（詳細画面で再利用できる）
//                .fade(duration: 0.15)
//                .retry(maxCount: 2, interval: .seconds(1))
//                .resizable()
//                .aspectRatio(cardAspectRatio, contentMode: .fit)
//                .frame(width: geometry.size.width, height: geometry.size.height)
//        }
//        .aspectRatio(cardAspectRatio, contentMode: .fit)
//        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: 6, style: .continuous)
//                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
//        )
//    }
//
//    private var placeholder: some View {
//        RoundedRectangle(cornerRadius: 6, style: .continuous)
//            .fill(Color(uiColor: .secondarySystemBackground))
//            .overlay(
//                ProgressView()
//                    .controlSize(.small)
//            )
//    }
//}
//
//#Preview {
//    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)) {
//        ForEach(Card.samples.prefix(10)) { card in
//            CardImageCell(card: card)
//        }
//    }
//    .padding()
//}


//
//  CardImageCell.swift
//  OPToolkit
//
//  グリッド1マス分のカード画像セル。
//  カード比率(約2.5:3.5)を保ったまま、GridItem(.flexible())の幅に追従する。
//
//
//import SwiftUI
//
//struct CardImageCell: View {
//    let card: Card
//    
//    var body: some View {
//        RoundedRectangle(cornerRadius: 6)
//            .fill(.secondary.opacity(0.15))
//            .aspectRatio(2.5 / 3.5, contentMode: .fit)
//            .overlay {
//                // TODO: 実画像に差し替え（card.imageName を AsyncImage や Image(_:) で表示）
//                if let imageName = card.imageName {
//                    Image(imageName)
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .clipShape(RoundedRectangle(cornerRadius: 6))
//                } else {
//                    VStack(spacing: 4) {
//                        Image(systemName: "photo")
//                            .foregroundStyle(.secondary)
//                        Text(card.name)
//                            .font(.system(size: 9))
//                            .foregroundStyle(.secondary)
//                            .lineLimit(2)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal, 2)
//                    }
//                }
//            }
//            .overlay(alignment: .topTrailing) {
//                Text("\(card.cost)")
//                    .font(.system(size: 10, weight: .bold))
//                    .padding(4)
//                    .background(.black.opacity(0.6), in: Circle())
//                    .foregroundStyle(.white)
//                    .padding(3)
//            }
//            .contentShape(Rectangle())   // 透明部分もタップ判定に含める
//    }
//}
//
//#Preview {
//    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
//        ForEach(Card.samples) { card in
//            CardImageCell(card: card)
//        }
//    }
//    .padding()
//}
