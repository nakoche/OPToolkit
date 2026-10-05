//
//  DeckImageExportView.swift
//  OPToolkit
//
//  「画像作成ボタン」で使う、デッキ内容を1枚の画像にレイアウトするView。
//  ImageRenderer(iOS16+)でこのViewをそのままUIImageに変換する。
//  右下にQRコード（DeckQRPayloadを文字列化したもの）を埋め込む。
//

import SwiftUI
import UIKit
import Kingfisher

struct DeckImageExportView: View {
    let deck: Deck
    let qrImage: UIImage?
    /// カードID -> 事前取得済みの画像。ImageRendererは非同期ロードを待たないため、
    /// KFImageではなく取得済みのUIImageを渡して描画する。
    let cardImages: [String: UIImage]

    private let columnCount = 10
    private let spacing: CGFloat = 4

    /// 枚数分だけ展開したカード一覧を、1行columnCount枚ずつに分けたもの。
    /// （同じカード4枚なら4回並ぶ。以前のLazyVGrid＋ネストしたForEachは、エントリ間でIDが
    ///  重複して後続のカードが描画されなかったため、通常のVStack/HStackで組んでいる）
    private var cardRows: [[Card]] {
        let cards = deck.cardEntries.flatMap { Array(repeating: $0.card, count: max($0.quantity, 0)) }
        return stride(from: 0, to: cards.count, by: columnCount).map {
            Array(cards[$0..<min($0 + columnCount, cards.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.title2.bold())
                    Text("\(deck.totalCardCount)枚")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)   // QRはにじませない
                        .frame(width: 100, height: 100)   // 写真から読み取れるよう、ある程度の大きさを確保する
                }
            }

            if let leader = deck.leaderCard {
                cardThumbnail(leader, width: 90)
            }

            // ImageRendererはLazyVGridの画面外の要素を描画しないことがあるため、遅延しないレイアウトにする
            let rows = cardRows
            VStack(spacing: spacing) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    let row = rows[rowIndex]
                    HStack(spacing: spacing) {
                        ForEach(0..<columnCount, id: \.self) { column in
                            if column < row.count {
                                cardThumbnail(row[column])
                            } else {
                                // 最終行の端数。列幅をそろえるための空きマス
                                Color.clear.aspectRatio(2.5 / 3.5, contentMode: .fit)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }

    /// widthを省略すると、親（HStackの列）が決めた幅いっぱいに表示する
    private func cardThumbnail(_ card: Card, width: CGFloat? = nil) -> some View {
        Color(uiColor: .systemGray5)
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .frame(width: width)
            .overlay {
                if let image = cardImages[card.id] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

enum DeckImageExporter {
    /// デッキをQR付きの1枚の画像として書き出す。
    /// 先にカード画像をKingfisher経由で取得（キャッシュ済みならキャッシュから）してから描画する。
    @MainActor
    static func makeImage(for deck: Deck) async -> UIImage? {
        let qrString = DeckQRPayload(deck: deck).encoded()
        let qrImage = qrString.flatMap { QRCodeService.generate(from: $0) }

        var cards = deck.cardEntries.map(\.card)
        if let leader = deck.leaderCard { cards.append(leader) }
        let cardImages = await loadImages(for: cards)

        let view = DeckImageExportView(deck: deck, qrImage: qrImage, cardImages: cardImages)
            .frame(width: 400)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3   // @3x相当の解像度で固定（UIScreen.mainはiOS26で非推奨のため使わない）
        renderer.isOpaque = true   // 背景は白で塗っているので、アルファチャンネルを持たない画像にする
        return renderer.uiImage
    }

    /// 同じカードは1回だけ取得する。取得に失敗したカードは辞書に入らず、グレーの枠だけで描画される。
    private static func loadImages(for cards: [Card]) async -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        for card in cards where result[card.id] == nil {
            let url: URL? = card.imageURL   // imageURLがOptionalでも非Optionalでも通るように
            guard let url else { continue }
            if let retrieved = try? await KingfisherManager.shared.retrieveImage(with: url) {
                result[card.id] = retrieved.image
            }
        }
        return result
    }
}
