//
//  CardDetailModal.swift
//  OPToolkit
//
//  カードタップ時に表示する拡大表示。
//  カード情報は出さず、画像のみを大きく見せる「ライトボックス」方式。
//  背景は半透明の黒、閉じるボタンは画面下部中央（親指が届く位置）に固定。
//  上下左右どの向きにドラッグしても、一定距離を超えるとスワイプで閉じられる。
//

import SwiftUI

struct CardDetailModal: View {
    let card: Card
    let onClose: () -> Void

    /// ドラッグに追従させる画像のオフセット
    @State private var dragOffset: CGSize = .zero
    /// これ以上ドラッグしたら閉じる、とみなす距離（pt）
    private let dismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            Color.black.opacity(0.85 * backgroundOpacityRatio)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)   // 背景タップでも閉じられるようにしておく

            VStack {
                Spacer()

                cardImage
                    .padding(.horizontal, 32)
                    .offset(dragOffset)
                    .gesture(dragToDismissGesture)

                Spacer()

                closeButton
                    .padding(.bottom, 24)   // safeAreaとは別に、親指がさらに届きやすいよう余白を厚めに
            }
        }
    }

    // ドラッグ量に応じて背景を薄くしていく（離した瞬間の判定を視覚的に伝えるため）
    private var backgroundOpacityRatio: CGFloat {
        let progress = dragDistance / dismissThreshold
        return 1 - min(progress, 1) * 0.6
    }

    private var dragDistance: CGFloat {
        (dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height).squareRoot()
    }

    private var dragToDismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if dragDistance > dismissThreshold {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var cardImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.06))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                // TODO: 実画像に差し替え（card.imageName）
                if let imageName = card.imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                        Text(card.name)
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.15), in: Circle())
        }
        .accessibilityLabel("閉じる")
    }
}

#Preview {
    CardDetailModal(card: .sampleLuffy, onClose: {})
}
