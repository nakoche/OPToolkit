//
//  CardDetailModal.swift
//  OPToolkit
//
//  カードタップ時に表示する拡大表示。
//  カード情報は出さず、画像のみを大きく見せる「ライトボックス」方式。
//  背景は半透明の黒で、背景をタップすると閉じる（閉じるボタンは置かない）。
//  上下左右どの向きにドラッグしても、一定距離を超えるとスワイプで閉じられる。
//  accessory を渡すと、カード画像の下に追加の部品を並べられる（一人回しの、パワー・コスト変更パネルなど）。
//  渡さなければ、これまでどおり画像だけが中央に出る。
//

import SwiftUI
import Kingfisher

struct CardDetailModal<Accessory: View>: View {
    let card: Card
    let onClose: () -> Void
    /// カード画像の下に出す追加の部品
    let accessory: Accessory

    /// ドラッグに追従させる画像のオフセット
    @State private var dragOffset: CGSize = .zero
    /// 画像の取得に失敗したかどうか（失敗時はカード名入りのプレースホルダーを出す）
    @State private var loadFailed = false
    /// これ以上ドラッグしたら閉じる、とみなす距離（pt）
    private let dismissThreshold: CGFloat = 120

    init(card: Card, onClose: @escaping () -> Void, @ViewBuilder accessory: () -> Accessory) {
        self.card = card
        self.onClose = onClose
        self.accessory = accessory()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85 * backgroundOpacityRatio)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)   // 背景タップでも閉じられるようにしておく

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                cardImage
                    .padding(.horizontal, 32)
                    .offset(dragOffset)
                    .gesture(dragToDismissGesture)

                // 何も渡されていなければ、ここには何も出ない
                accessory

                Spacer(minLength: 0)
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

    // カード画像は公式サイトのURLをKingfisher経由で取得する（CardImageCellと同じ方式）。
    // グリッドで表示済みなら同じURLのキャッシュが使われるので、ほぼ即座に表示される。
    private var cardImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.06))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                if loadFailed {
                    failurePlaceholder
                } else {
                    KFImage(card.imageURL)
                        .placeholder {
                            ProgressView()
                                .tint(.white)
                        }
                        .onFailure { _ in
                            loadFailed = true
                        }
                        .fade(duration: 0.15)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
    }

    private var failurePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
            Text(card.name)
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.6))
    }

}

// accessory なしで使うための初期化（カードリストなど、これまでの呼び出しはそのまま使える）
extension CardDetailModal where Accessory == EmptyView {
    init(card: Card, onClose: @escaping () -> Void) {
        self.init(card: card, onClose: onClose) { EmptyView() }
    }
}

#Preview {
    CardDetailModal(card: .sampleLuffy, onClose: {})
}
