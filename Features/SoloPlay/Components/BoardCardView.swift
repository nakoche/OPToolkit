//
//  BoardCardView.swift
//  OPToolkit
//
//  盤面に置かれたカード1枚の見た目。
//  - 表向き/裏向き（山札・ライフは裏向き）
//  - レスト状態: 90度横向きにする（隣のカードに触れすぎないよう少し縮める）
//  - 付与ドン: カードの下に、右下へずらして重ねる。枚数のバッジはドラッグでドンを外せる
//  - パワー（右上）: 詳細画面で変更した増減を加えた数値。持ち主の手番中は、付与されているドン1枚につき
//    +1000もした数値を、色を変えて表示する（相手の手番中は、ドン付与分は加算しない。桁区切りのカンマは付けない）
//  - コスト（左上）
//  パワー・コストは、表向きのときだけ、showsPower / showsCost が true のカードに出す。
//  サイズは width で指定する（高さは2.5:3.5の比率から決まる）。
//  タップやドラッグの操作は、呼び出し側（PlayerBoardView / SoloHandView）で付ける。
//

import SwiftUI

struct BoardCardView: View {
    let instance: CardInstance
    let width: CGFloat
    /// 持ち主（付与ドンのバッジをドラッグするときの、ドラッグ元の情報に使う）
    let owner: Perspective
    /// 右上にパワーを表示するか（リーダー・キャラで使う）
    var showsPower = false
    /// 左上にコストを表示するか（キャラで使う）
    var showsCost = false
    /// 今が、このカードの持ち主の手番か。ドン付与によるパワーアップは、持ち主の手番中だけ反映する
    var isOwnerTurn = false

    private var height: CGFloat { width * 1.4 }
    /// 付与ドン1枚あたりのずらし幅
    private var donOffsetStep: CGFloat { width * 0.08 }
    /// 重なりとして描く付与ドンの最大枚数（それ以上はバッジの数字で分かる）
    private let maxDonLayers = 3

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .topLeading) {
                donLayers
                cardFace
                    .frame(width: width, height: height)
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .rotationEffect(.degrees(instance.isRested ? 90 : 0))
            .scaleEffect(instance.isRested ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.2), value: instance.isRested)

            if instance.attachedDon > 0 {
                donBadge
            }
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) {
            if showsCost && instance.isFaceUp {
                costBadge
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsPower && instance.isFaceUp {
                powerBadge
            }
        }
    }

    // MARK: - パワー（右上）・コスト（左上）

    /// パワーとコストが重ならず、かつ読める大きさ（カード幅の約20%）
    private var badgeFontSize: CGFloat { max(width * 0.2, 8) }

    /// パワー。基本のパワーに、詳細画面で変更した増減を加え、持ち主の手番中はさらに
    /// 付与ドン1枚につき+1000を加える。基本より増えていれば赤、減っていれば青にして、変わっていると分かるようにする。
    private var powerBadge: some View {
        let boost = isOwnerTurn ? instance.attachedDon * 1000 : 0
        let total = instance.effectivePower + boost
        let difference = total - (instance.card.power ?? 0)
        let text = String(total)   // 桁区切りのカンマは付けない
        // 5桁（10000以上）のときは、コストと重ならないよう少しだけ小さくする
        let fontSize = text.count >= 5 ? badgeFontSize * 0.85 : badgeFontSize

        let background: Color
        if difference > 0 {
            background = Color.red.opacity(0.9)
        } else if difference < 0 {
            background = Color.blue.opacity(0.9)
        } else {
            background = Color.black.opacity(0.75)
        }

        return Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 2)
            .padding(.vertical, 0)
            .background(background, in: Capsule())
            .padding(1)
            .allowsHitTesting(false)
    }

    private var costBadge: some View {
        // 詳細画面でコストを変えているときは、色を変えて（オレンジ）、変わっていると分かるようにする
        Text("\(instance.effectiveCost)")
            .font(.system(size: badgeFontSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: badgeFontSize + 4, minHeight: badgeFontSize + 4)
            .background(instance.costModifier != 0 ? Color.orange : Color.blue.opacity(0.9), in: Circle())
            .padding(1)
            .allowsHitTesting(false)
    }

    // MARK: - カード本体

    @ViewBuilder
    private var cardFace: some View {
        if instance.isFaceUp {
            CardThumbnailImage(card: instance.card, cornerRadius: 4)
        } else {
            CardBackImage(cornerRadius: 4)
        }
    }

    // MARK: - 付与ドン（カードの下に、右下へずらして重ねる）

    private var donLayers: some View {
        let layerCount = min(instance.attachedDon, maxDonLayers)
        return ZStack(alignment: .topLeading) {
            // 奥のものほど大きくずらす（最後に描いた本体カードが一番手前になる）
            ForEach(0..<layerCount, id: \.self) { index in
                let distance = CGFloat(layerCount - index)
                CardBackImage(imageName: "DonFront", cornerRadius: 4)
                    .frame(width: width, height: height)
                    .offset(x: donOffsetStep * distance, y: donOffsetStep * distance)
            }
        }
    }

    // MARK: - 付与ドンの枚数バッジ（ドラッグすると、ドンを1枚外せる）

    private var donBadge: some View {
        let size = max(width * 0.42, 22)
        return Text("\(instance.attachedDon)")
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.black.opacity(0.8), in: Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
            .draggable(SoloDragItem(owner: owner, content: .don(.attached(instance.id)))) {
                CardBackImage(imageName: "DonFront", cornerRadius: 4)
                    .frame(width: width * 0.8)
            }
    }
}
