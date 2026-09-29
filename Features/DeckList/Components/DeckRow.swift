//
//  DeckRow.swift
//  OPToolkit
//
//  デッキ一覧の1行分。
//  左: リーダー画像（行の高さいっぱい） / 右: 上段にデッキ名、下段に機能ボタン。
//  詳細遷移のタップ領域は行全体に広げている。3つのアイコンはButtonなので、
//  その上をタップした場合はSwiftUIがButton側のタップを優先して拾い、
//  行全体のonTapGestureとは競合しない。
//

import SwiftUI
import Kingfisher

struct DeckRow: View {
    let deck: Deck
    let onOpenDetail: () -> Void
    let onBattleHistory: () -> Void
    let onShowImage: () -> Void
    let onCopy: () -> Void

    /// リーダー画像の取得に失敗したかどうか（失敗時はカード名ラベルのプレースホルダーを出す）
    @State private var leaderLoadFailed = false

    private let rowHeight: CGFloat = 100

    var body: some View {
        HStack(spacing: 0) {
            leaderThumbnail

            VStack(alignment: .leading, spacing: 10) {
                Text(deck.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 28) {
                    iconButton("clock.arrow.circlepath", action: onBattleHistory)
                    iconButton("photo.on.rectangle", action: onShowImage)
                    iconButton("doc.on.doc", action: onCopy)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: rowHeight)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())   // 余白部分も含め、行全体をタップ判定の対象にする
        .onTapGesture(perform: onOpenDetail)
    }

    // リーダー画像は公式サイトのURLをKingfisher経由で取得する（CardImageCellと同じ方式）。
    private var leaderThumbnail: some View {
        ZStack {
            Color(uiColor: .systemGray5)
            if let leader = deck.leaderCard {
                if leaderLoadFailed {
                    // 取得失敗時だけカード名を出す
                    VStack {
                        Spacer()
                        Text(leader.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                            .padding(4)
                            .frame(maxWidth: .infinity)
                            .background(.black.opacity(0.5))
                    }
                } else {
                    KFImage(leader.imageURL)
                        .placeholder {
                            ProgressView()
                        }
                        .onFailure { _ in
                            leaderLoadFailed = true
                        }
                        .fade(duration: 0.15)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            } else {
                Image(systemName: "questionmark")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: rowHeight * (2.5 / 3.5), height: rowHeight)
        .clipShape(
            .rect(topLeadingRadius: 10, bottomLeadingRadius: 10, bottomTrailingRadius: 0, topTrailingRadius: 0)
        )
    }

    private func iconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DeckRow(
        deck: .sample,
        onOpenDetail: {},
        onBattleHistory: {},
        onShowImage: {},
        onCopy: {}
    )
    .padding()
    .background(Color.black)
}
