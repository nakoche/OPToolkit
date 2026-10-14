//
//  SoloMulliganView.swift
//  OPToolkit
//
//  マリガンの選択画面。先攻 → 後攻の順に、その人の手札（5枚）を見せる。
//  「引き直す」は何回でも押せて、気に入った手札になったら「このまま」で次の人へ進む。
//  後攻が「このまま」を押すと対戦が始まる（ViewModel側で処理）。
//  手札のカードをタップすると、拡大して確認できる。
//

import SwiftUI

struct SoloMulliganView: View {
    let viewModel: SoloPlayViewModel

    /// タップして拡大中のカード
    @State private var zoomedCard: Card?

    /// いま選んでいるプレイヤー
    private var player: Perspective {
        switch viewModel.phase {
        case .mulligan(let current): return current
        default: return viewModel.perspective
        }
    }

    private var playerName: String {
        player == .playerOne ? "先攻" : "後攻"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                if let leader = viewModel.visibleBoard.leader {
                    VStack(spacing: 4) {
                        CardThumbnailImage(card: leader.card, cornerRadius: 8)
                            .frame(width: 90)

                        // このリーダーのライフ値（マリガンのあと、この枚数のライフが置かれる）
                        Text(leader.card.soloPlayStartingLifeText)
                            .font(.caption)
                            .foregroundStyle(leader.card.life == nil ? Color.orange : Color.secondary)
                    }
                }

                VStack(spacing: 6) {
                    Text("\(playerName)のマリガン")
                        .font(.title2.bold())
                    Text("何回でも引き直せます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 手札5枚を1行に並べる（幅に合わせて自動で大きさが決まる）
                HStack(spacing: 8) {
                    ForEach(viewModel.visibleBoard.hand) { instance in
                        CardThumbnailImage(card: instance.card)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    zoomedCard = instance.card
                                }
                            }
                    }
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button {
                        viewModel.confirmMulligan()
                    } label: {
                        Text("このまま")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        // 手札が入れ替わったことが分かるよう、少しアニメーションさせる
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.redrawMulliganHand()
                        }
                    } label: {
                        Text("引き直す")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // 拡大表示（カードリストと同じ、その場に浮かび上がるオーバーレイ）
            if let card = zoomedCard {
                CardDetailModal(card: card) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        zoomedCard = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(1)
            }
        }
    }
}
