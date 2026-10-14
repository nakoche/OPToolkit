//
//  SoloHandView.swift
//  OPToolkit
//
//  プレイヤーの手札。
//  - 手前（視点側）の手札: 表向きで横スクロールに並べる。操作バーの「詳細」ボタンを押してからタップすると詳細表示
//  - 相手側の手札（isHidden = true）: 裏向きで、少しずつ重ねて並べる（中身は見えない）
//  どちらも、長押ししてドラッグすると盤面へ動かせる（スクロールは、すぐ横にスワイプすれば従来どおり）。
//  手札の枠はドロップ先にもなっていて、盤面のカードをその持ち主の手札に戻せる。
//
//  手札の枚数は、枠の端に「手札 N」で重ねて出す（専用の場所は設けず、カードに重なってよい）。
//  点対称の配置に合わせて、自分の手札は枠の左下の角（下の線に沿わせる）、
//  相手の手札は枠の右端（画面の右上）に置く。
//

import SwiftUI

struct SoloHandView: View {
    let viewModel: SoloPlayViewModel
    let hand: [CardInstance]
    /// 手札の持ち主
    let owner: Perspective
    /// 手札のカード1枚の幅
    let cardWidth: CGFloat
    /// true のとき、すべて裏向きで表示する（相手の手札）
    var isHidden = false

    private var cardHeight: CGFloat { cardWidth * 1.4 }

    var body: some View {
        SoloDropZone(onDrop: { drop($0) }) {
            handCards
                .padding(.horizontal, 6)
                .frame(height: cardHeight + 12)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                // 枚数は、カードに重ねる。自分の手札は左下の角（下の線に沿わせる）、相手の手札は右端
                .overlay(alignment: isHidden ? .trailing : .bottomLeading) {
                    countLabel
                        .padding(.horizontal, 6)
                        .padding(.bottom, isHidden ? 0 : 3)
                }
        }
    }

    @ViewBuilder
    private var handCards: some View {
        if isHidden {
            // 相手の手札は枚数が分かればよいので、スクロールさせず左から重ねて並べる
            cards
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                cards
            }
        }
    }

    /// 手札の枚数（「手札」の文字と、大きめの数字）
    private var countLabel: some View {
        VStack(spacing: 0) {
            Text("手札")
                .font(.system(size: 9, weight: .bold))
            Text("\(hand.count)")
                .font(.title3.bold().monospacedDigit())
        }
        .foregroundStyle(.white)
        .frame(width: 38)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }

    private var cards: some View {
        // 裏向きのときは、カード幅の半分ほど重ねる（負のspacing）
        HStack(spacing: isHidden ? -cardWidth * 0.55 : 6) {
            ForEach(hand) { instance in
                cardView(instance)
                    .draggable(SoloDragItem(owner: owner, content: .card(instance.id))) {
                        preview(instance)
                    }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func cardView(_ instance: CardInstance) -> some View {
        if isHidden {
            CardBackImage(cornerRadius: 4)
                .frame(width: cardWidth)
        } else {
            CardThumbnailImage(card: instance.card, cornerRadius: 4)
                .frame(width: cardWidth)
                .onTapGesture {
                    viewModel.showDetailIfNeeded(instance, owner: owner)
                }
        }
    }

    /// ドラッグ中に指についてくる見た目（相手の手札は裏向きのまま）
    @ViewBuilder
    private func preview(_ instance: CardInstance) -> some View {
        if isHidden {
            CardBackImage(cornerRadius: 4).frame(width: cardWidth)
        } else {
            CardThumbnailImage(card: instance.card, cornerRadius: 4).frame(width: cardWidth)
        }
    }

    private func drop(_ items: [SoloDragItem]) -> Bool {
        let accepted = viewModel.performDrop(items, owner: owner, target: .zone(.hand))
        if accepted {
            SoloHaptics.dropped()
        } else {
            SoloHaptics.rejected()
        }
        return accepted
    }
}
