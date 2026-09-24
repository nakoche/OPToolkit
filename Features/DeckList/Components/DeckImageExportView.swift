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

struct DeckImageExportView: View {
    let deck: Deck
    let qrImage: UIImage?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

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
                        .frame(width: 72, height: 72)
                }
            }

            if let leader = deck.leaderCard {
                cardThumbnail(leader, width: 90)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(deck.cardEntries) { entry in
                    ForEach(0..<entry.quantity, id: \.self) { _ in
                        cardThumbnail(entry.card, width: 56)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }

    private func cardThumbnail(_ card: Card, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(uiColor: .systemGray5))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .frame(width: width)
            .overlay {
                // TODO: 実画像に差し替え（card.imageName）
                Text(card.name)
                    .font(.system(size: 7))
                    .multilineTextAlignment(.center)
                    .padding(2)
                    .foregroundStyle(.secondary)
            }
    }
}

enum DeckImageExporter {
    /// デッキをQR付きの1枚の画像として書き出す
    @MainActor
    static func makeImage(for deck: Deck) -> UIImage? {
        let qrString = DeckQRPayload(deck: deck).encoded()
        let qrImage = qrString.flatMap { QRCodeService.generate(from: $0) }

        let view = DeckImageExportView(deck: deck, qrImage: qrImage)
            .frame(width: 400)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3   // @3x相当の解像度で固定（UIScreen.mainはiOS26で非推奨のため使わない）
        return renderer.uiImage
    }
}
