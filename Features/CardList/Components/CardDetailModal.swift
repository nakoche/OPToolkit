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
//  qaItems か favorite を渡すと、画像の下にボタン（アクション行）が出る。縦に、上から ♡、Q&A の順。
//  - ♡（favorite を渡したとき）: お気に入りの切り替え。その場で切り替わる。
//  - Q&A（qaItems が空でないとき）: 押すと、同じモーダルの中で画像が小さくなって上に寄り、
//    その下にQ&Aの一覧（全文）が出る（♡はこのとき消える）。モーダルを重ねたり、画面遷移したりはしない。
//    もう一度ボタンを押すか、小さくなった画像をタップすると、元の大きな画像に戻る。
//  どちらも渡さなければ（一人回しなど）、ボタンは出ず、これまでと同じ見た目・動作のまま。
//
//  今後ボタンを足すときは、actionBar の VStack に並べる。
//

import SwiftUI
import Kingfisher

/// 詳細モーダルの♡ボタンの状態と、押したときの動作
struct FavoriteControl {
    let isFavorite: Bool
    let onToggle: () -> Void
}

struct CardDetailModal<Accessory: View>: View {
    let card: Card
    /// このカードの公式Q&A。空ならQ&Aボタンを出さない
    let qaItems: [CardQA]
    /// 渡すと♡ボタンが出る。nilなら出さない
    let favorite: FavoriteControl?
    let onClose: () -> Void
    /// カード画像の下に出す追加の部品
    let accessory: Accessory

    /// ドラッグに追従させる画像のオフセット
    @State private var dragOffset: CGSize = .zero
    /// 画像の取得に失敗したかどうか（失敗時はカード名入りのプレースホルダーを出す）
    @State private var loadFailed = false
    /// Q&Aを開いているか（開いている間は、画像が小さくなって上に寄り、下にQ&Aの一覧が出る）
    @State private var isQAExpanded = false
    /// Q&A一覧の中身の高さ。Q&Aが短いときに、一覧の枠が余らないように測っておく
    @State private var qaContentHeight: CGFloat = 0
    /// これ以上ドラッグしたら閉じる、とみなす距離（pt）
    private let dismissThreshold: CGFloat = 120

    init(
        card: Card,
        qaItems: [CardQA] = [],
        favorite: FavoriteControl? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.card = card
        self.qaItems = qaItems
        self.favorite = favorite
        self.onClose = onClose
        self.accessory = accessory()
    }

    private var hasQA: Bool { !qaItems.isEmpty }
    /// ♡やQ&Aのボタンを出すか
    private var hasActions: Bool { hasQA || favorite != nil }

    var body: some View {
        // 画像とQ&A一覧の高さを、画面の高さに対する割合で決めるために、全体の大きさを測る
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.85 * backgroundOpacityRatio)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)   // 背景タップでも閉じられるようにしておく

                VStack(spacing: contentSpacing) {
                    Spacer(minLength: 0)

                    cardImage
                        .padding(.horizontal, 32)
                        .frame(maxHeight: imageMaxHeight(in: proxy.size.height))
                        .offset(dragOffset)
                        .gesture(dragToDismissGesture)
                        // Q&Aを開いている間は、小さくなった画像をタップして元に戻せる（閉じているときは何もしない）
                        .onTapGesture {
                            if isQAExpanded { toggleQA() }
                        }
                        // ボタンの分だけ画像が上にずれないよう、上にも同じ高さの余白を足す（タップ・ドラッグの範囲には含まれない）
                        .padding(.top, imageTopPadding)

                    // ♡もQ&Aも無ければ、ここには何も出ない
                    if hasActions {
                        actionSection(screenHeight: proxy.size.height)
                    }

                    // 何も渡されていなければ、ここには何も出ない
                    accessory

                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 画像の位置

    /// ボタンを閉じているときの、ボタン部分（♡の上下の余白を含む）の高さ。actionBar の高さと同じになる
    private var collapsedActionHeight: CGFloat {
        guard hasActions else { return 0 }
        let heartBlock = favorite != nil
            ? max(heartGap - contentSpacing, 0) + heartButtonSize + heartGap
            : 0
        return heartBlock + qaButtonHeight
    }

    /// 画像の上に足す余白。
    /// ボタンを下に足すと、画像とボタンをまとめて中央に置くので、画像が上にずれてしまう。
    /// それを防ぐため、画像の下に足した分（ボタン＋間隔）と同じ高さを上にも取って、画像を元の位置（画面の中央）に保つ。
    /// Q&Aを開いている間は、画像を上に寄せて一覧を出すので0にする。
    private var imageTopPadding: CGFloat {
        (hasActions && !isQAExpanded) ? collapsedActionHeight + contentSpacing : 0
    }

    // MARK: - 画像の大きさ

    /// 画像の高さの上限。
    /// ♡もQ&Aも無いときはnil（これまでどおり、制限しない）。
    /// ボタンがあるときは、閉じている間は画面の高さ（実質、制限なし）、開いている間は画面の3割。
    /// どちらも数値にしているのは、開閉のアニメーションで、画像の大きさが滑らかに変わるようにするため。
    private func imageMaxHeight(in screenHeight: CGFloat) -> CGFloat? {
        guard hasActions else { return nil }
        return isQAExpanded ? screenHeight * 0.30 : screenHeight
    }

    // MARK: - ドラッグで閉じる

    // ドラッグ量に応じて背景を薄くしていく（離した瞬間の判定を視覚的に伝えるため）
    private var backgroundOpacityRatio: CGFloat {
        let progress = dragDistance / dismissThreshold
        return 1 - min(progress, 1) * 0.6
    }

    private var dragDistance: CGFloat {
        (dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height).squareRoot()
    }

    // ドラッグのジェスチャーは画像にだけ付けているので、下のQ&A一覧のスクロールとは競合しない
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

    // MARK: - Q&A

    private func toggleQA() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isQAExpanded.toggle()
        }
    }

    /// ボタン（♡・Q&A）と、その下のQ&A一覧
    private func actionSection(screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            actionBar
            if hasQA {
                qaPanel(maxHeight: screenHeight * 0.45)
            }
        }
    }

    /// ♡ボタンの大きさ
    private let heartButtonSize: CGFloat = 60
    /// ♡の上下の余白。♡が「画像」と「Q&Aボタン」の真ん中に来るよう、上も下も同じ間隔にする
    private let heartGap: CGFloat = 16
    /// Q&Aボタンの高さ。Q&Aが無いカードでも、同じ高さの空きを取っておく（♡の位置がカードによってずれないように）
    private let qaButtonHeight: CGFloat = 40
    /// 画像・ボタン・accessoryを縦に並べるときの間隔
    private let contentSpacing: CGFloat = 12

    /// 画像の下に縦に並べるボタン。上から ♡、Q&A（今後ボタンを足すときは、ここに並べていく）。
    /// ♡の位置が、Q&Aがあるカードと無いカードでずれないよう、Q&Aが無いときも、Q&Aボタンの分の空きは取っておく。
    private var actionBar: some View {
        VStack(spacing: 0) {
            if let favorite {
                heartButton(favorite)
                    // Q&Aを開いている間は消える。高さも余白も0にして、Q&Aの一覧が上に詰まるようにする
                    .frame(height: isQAExpanded ? 0 : heartButtonSize)
                    .clipped()
                    .opacity(isQAExpanded ? 0 : 1)
                    .allowsHitTesting(!isQAExpanded)
                    // 上の余白: 画像との間にはVStackの間隔（contentSpacing）も入るので、その分を引いて、上下を同じ間隔にする
                    .padding(.top, isQAExpanded ? 0 : max(heartGap - contentSpacing, 0))
                    .padding(.bottom, isQAExpanded ? 0 : heartGap)
            }

            if hasQA {
                Button(action: toggleQA) {
                    Label("Q&A（\(qaItems.count)）", systemImage: "questionmark.bubble")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: qaButtonHeight)
                        .background(
                            isQAExpanded ? Color.accentColor : Color.white.opacity(0.15),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isQAExpanded ? "Q&Aを閉じる" : "Q&Aを表示")
            } else if favorite != nil {
                // Q&Aが無いカード: ボタンは出さず、空きだけ取っておく
                Color.clear.frame(height: qaButtonHeight)
            }
        }
    }

    /// ♡（お気に入り）ボタン。お気に入りのときは塗りつぶしのピンクになる
    private func heartButton(_ favorite: FavoriteControl) -> some View {
        Button(action: favorite.onToggle) {
            Image(systemName: favorite.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(favorite.isFavorite ? Color.pink : Color.white)
                .frame(width: heartButtonSize, height: heartButtonSize)
                .background(Color.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: favorite.isFavorite)
        .accessibilityLabel(favorite.isFavorite ? "お気に入りから外す" : "お気に入りに追加")
    }

    /// Q&A一覧。閉じている間は高さ0（透明で、タップも受けない）にしておき、開くときに高さを広げる。
    /// 高さは、中身の高さ（短いときは枠が余らないように）か、上限のどちらか小さいほう。上限を超えたら中でスクロールする。
    private func qaPanel(maxHeight: CGFloat) -> some View {
        let height = qaContentHeight > 0 ? min(qaContentHeight, maxHeight) : maxHeight

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(qaItems) { item in
                    qaRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                qaContentHeight = newHeight
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .frame(height: isQAExpanded ? height : 0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // iPadなどの広い画面で、横に伸びすぎないようにする
        .frame(maxWidth: 560)
        .padding(.horizontal, 20)
        .padding(.top, isQAExpanded ? 10 : 0)
        .opacity(isQAExpanded ? 1 : 0)
        .allowsHitTesting(isQAExpanded)
    }

    /// Q&A 1件。Q番号と更新日、質問、回答の全文を出す
    private func qaRow(_ item: CardQA) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.id)
                    .font(.caption.weight(.bold))
                if let date = item.displayDate {
                    Text("\(date)更新")
                        .font(.caption)
                }
            }
            .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Q")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                Text(item.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("A")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.mint)
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - カード画像

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
    init(
        card: Card,
        qaItems: [CardQA] = [],
        favorite: FavoriteControl? = nil,
        onClose: @escaping () -> Void
    ) {
        self.init(card: card, qaItems: qaItems, favorite: favorite, onClose: onClose) { EmptyView() }
    }
}

#Preview("Q&Aなし") {
    CardDetailModal(card: .sampleLuffy, onClose: {})
}

#Preview("Q&Aあり") {
    CardDetailModal(card: .sampleLuffy, qaItems: CardQA.samples, onClose: {})
}

#Preview("♡とQ&Aあり") {
    CardDetailModal(
        card: .sampleLuffy,
        qaItems: CardQA.samples,
        favorite: FavoriteControl(isFavorite: true, onToggle: {}),
        onClose: {}
    )
}

#Preview("♡のみ") {
    CardDetailModal(
        card: .sampleZoro,
        favorite: FavoriteControl(isFavorite: false, onToggle: {}),
        onClose: {}
    )
}
