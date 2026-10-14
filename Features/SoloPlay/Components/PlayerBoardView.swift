//
//  PlayerBoardView.swift
//  OPToolkit
//
//  1人分の盤面。公式プレイマットの配置に合わせた、3段のレイアウト（7列のグリッド）。
//  カード1枚の幅を1列として、次のように並べる。
//
//  「先攻」「後攻」の文字は、2段目のリーダーの横の空きに出す（手番・ドン枚数・手札枚数の情報行は無い。
//  手番は画面の背景色、手札枚数は手札の枠、ドンの枚数はコストエリアの一番端のドンに出す）。
//
//    ライフ │ キャラエリア（6列分に、5つのスロットを均等に並べる）
//    縦積み │ 2段目:
//           │   リーダー = 盤面の横幅（ライフ列を含む全体）のど真ん中
//           │   ステージ = 右から2番目（4番目）のキャラの真下
//           │   デッキ   = 右端（5番目）のキャラの真下
//    ドンデッキ │ コストエリア（5列分。ドンを1枚ずつ重ねて並べる） │ トラッシュ
//
//  3段目（ドン・トラッシュ）は、高さをカードの約7割にして、画面に収まるようにしている。
//  相手側は、自分側を180°回した配置（点対称）にする。上下の段が入れ替わり、左右も逆になる
//  （自分から見て、相手のライフは右、デッキは左。キャラのスロットや、ドンの並びも逆順）。
//  カードそのものは、読みやすいよう回転させない。
//
//  操作:
//   - リーダー・キャラ・ステージ: タップでレスト⇄アクティブ
//   - キャラ: 空いているスロットへドラッグで移動、埋まっているスロットへドラッグで入れ替え
//   - リーダー・キャラの右上にパワー（ドン付与分の加算は、持ち主の手番中のみ）、キャラの左上にコストを表示
//   - ライフ: タップで表⇄裏
//   - 詳細は、操作バーの「詳細」ボタンを押してからカードをタップする（詳細モード中のタップは、レスト等をせず詳細表示だけ行う）
//   - コストエリアのドン: 1枚ずつ、タップでレスト⇄アクティブ。ドラッグで付与したり、ドンデッキへ戻したりできる
//   - ドンデッキのタップ: アクティブなドンを1枚、コストエリアに追加
//   - ドラッグ&ドロップでカード・ドンを動かす（置けない場所は拒否して触覚で知らせる）
//   - 山札・ライフへドロップしたカードは、あとで「上/下」を選ぶ（BoardArea側のダイアログ）
//   - デッキ・トラッシュのタップで、確認パネルを開く（山札を上から見る／トラッシュの一覧）
//

import SwiftUI

struct PlayerBoardView: View {
    let viewModel: SoloPlayViewModel
    let board: PlayerBoard
    let owner: Perspective
    /// 画面の上側（相手側）に置くか
    let isOpponentSide: Bool
    /// 今の手番のプレイヤーか
    let isActive: Bool
    /// カード1枚の幅
    let cardWidth: CGFloat

    private let spacing: CGFloat = 4

    /// 3段目（ドン・トラッシュ）のカードの大きさの、1段目・2段目に対する比率
    static let bottomRowScale: CGFloat = 0.7

    private var w: CGFloat { cardWidth }
    private var h: CGFloat { cardWidth * 1.4 }
    /// 3段目のカード1枚の幅と、段の高さ
    private var bottomCardWidth: CGFloat { cardWidth * Self.bottomRowScale }
    private var bottomRowHeight: CGFloat { h * Self.bottomRowScale }

    private var totalWidth: CGFloat { w * 7 + spacing * 6 }
    /// ライフを除く、右側6列分の幅
    private var rightBlockWidth: CGFloat { w * 6 + spacing * 5 }
    /// コストエリアの幅（ドンデッキとトラッシュの間の5列分）
    private var costAreaWidth: CGFloat { w * 5 + spacing * 4 }
    private var lifeColumnHeight: CGFloat { h * 2 + spacing }
    /// キャラの5つのスロットの間隔（6列分の幅に、5つを均等に並べたときのすき間）
    private var slotSpacing: CGFloat {
        (rightBlockWidth - w * CGFloat(PlayerBoard.maxCharacters)) / CGFloat(PlayerBoard.maxCharacters - 1)
    }

    /// キャラのスロットを左から並べる順。相手側は点対称なので、逆順（スロット0が右端）
    private var slotOrder: [Int] {
        let slots = Array(0..<PlayerBoard.maxCharacters)
        return isOpponentSide ? slots.reversed() : slots
    }

    // 2段目の左端から測った、リーダー・ステージ・デッキの左端の位置（自分側。ライフ列は左にある）
    /// リーダー: 盤面の横幅（ライフ列を含む全体）の、ど真ん中に置く
    private var leaderX: CGFloat { totalWidth / 2 - w / 2 - (w + spacing) }
    /// ステージ: 右から2番目（4番目）のキャラの真下
    private var stageX: CGFloat { 3 * (w + slotSpacing) }
    /// デッキ: 右端（5番目）のキャラの真下
    private var deckX: CGFloat { 4 * (w + slotSpacing) }
    /// 相手側のリーダー: 盤面の横幅のど真ん中（ライフ列が右にあるので、2段目の左端から測る）
    private var opponentLeaderX: CGFloat { totalWidth / 2 - w / 2 }

    var body: some View {
        VStack(spacing: spacing) {
            // 自分側: キャラの段が上、ドンの段が下。相手側は、向かい合うので上下を入れ替える。
            // リーダーなどに付与したドンの重なりが、隣の段に隠れないよう、上にある段を手前に描く。
            if isOpponentSide {
                bottomRow.zIndex(1)
                topBlock.zIndex(0)
            } else {
                topBlock.zIndex(1)
                bottomRow.zIndex(0)
            }
        }
        .frame(width: totalWidth)
    }

    // MARK: - 段

    /// 1段目・2段目: ライフ（2段分の高さ）と、キャラエリア・リーダー/ステージ/デッキの段
    private var topBlock: some View {
        HStack(alignment: .top, spacing: spacing) {
            // 自分側はライフが左、相手側は点対称なので右
            if isOpponentSide {
                rowsBlock
                lifeColumn
            } else {
                lifeColumn
                rowsBlock
            }
        }
    }

    /// ライフを除く、キャラエリアの段とリーダー・ステージ・デッキの段
    private var rowsBlock: some View {
        VStack(spacing: spacing) {
            if isOpponentSide {
                middleRow.zIndex(1)
                characterRow.zIndex(0)
            } else {
                characterRow.zIndex(1)
                middleRow.zIndex(0)
            }
        }
    }

    /// 1段目: キャラエリア。6列分の幅に、5つのスロットを均等に並べる
    private var characterRow: some View {
        // スロットとスロットのすき間にドロップしたときは、一番左の空きスロットへ置く扱い。
        // 満杯のときは、そこへの新しいカードは置けないので、赤く光らせる。
        SoloDropZone(
            isInvalid: board.characters.count >= PlayerBoard.maxCharacters,
            onDrop: { drop($0, .zone(.characters)) }
        ) {
            HStack(spacing: slotSpacing) {
                ForEach(slotOrder, id: \.self) { slot in
                    if let instance = board.characterSlots[slot] {
                        characterCell(instance, slot: slot)
                    } else {
                        emptyCharacterSlot(slot)
                    }
                }
            }
            .frame(width: rightBlockWidth, height: h)
        }
    }

    /// 2段目: リーダーを盤面の横幅のど真ん中、ステージを右から2番目（4番目）のキャラの真下、
    /// デッキを右端（5番目）のキャラの真下に置く。リーダーの左は空ける（マットのフェイズ表の位置）。
    private var middleRow: some View {
        HStack(spacing: 0) {
            if isOpponentSide {
                // 自分側を180°回した配置: 左から、デッキ、ステージ、リーダー（リーダーは盤面のど真ん中のまま）。
                // 「先攻」「後攻」の文字は、点対称なので、リーダーの右の空きに出す（相手から見て左側）
                deckCell
                Color.clear
                    .frame(width: slotSpacing, height: h)
                stageCell
                Color.clear
                    .frame(width: max(opponentLeaderX - (w + slotSpacing + w), 0), height: h)
                leaderCell
                sideLabel
                    .frame(width: max(rightBlockWidth - (opponentLeaderX + w), 0), height: h)
            } else {
                // 「先攻」「後攻」の文字は、リーダーの左の空きに出す
                sideLabel
                    .frame(width: max(leaderX, 0), height: h)
                leaderCell
                Color.clear
                    .frame(width: max(stageX - (leaderX + w), 0), height: h)
                stageCell
                Color.clear
                    .frame(width: max(deckX - (stageX + w), 0), height: h)
                deckCell
            }
        }
        .frame(width: rightBlockWidth, height: h, alignment: .leading)
    }

    /// 「先攻」「後攻」の文字
    private var sideLabel: some View {
        Text(owner == .playerOne ? "先攻" : "後攻")
            .font(.system(size: max(w * 0.36, 14), weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.75))
    }

    /// 3段目: ドンデッキ、コストエリア、トラッシュ
    private var bottomRow: some View {
        HStack(spacing: spacing) {
            // 相手側は点対称なので、左右が逆（左からトラッシュ、コストエリア、ドンデッキ）
            if isOpponentSide {
                trashCell
                costArea
                donDeckCell
            } else {
                donDeckCell
                costArea
                trashCell
            }
        }
        .frame(height: bottomRowHeight)
    }

    // MARK: - キャラ（空きスロット・埋まっているスロット）

    /// 空きスロット。ここへカードをドロップすると、そのスロットに置く（場のキャラなら移動）
    private func emptyCharacterSlot(_ slot: Int) -> some View {
        SoloDropZone(onDrop: { drop($0, .characterSlot(slot)) }) {
            placeholder(slot == 0 ? "キャラ" : "")
        }
    }

    /// 埋まっているスロット。ドンならこのキャラへ付与、カードならこのスロットへ（場のキャラなら入れ替え）
    private func characterCell(_ instance: CardInstance, slot: Int) -> some View {
        SoloDropZone(
            onDrop: { drop($0, .characterCard(id: instance.id, slot: slot)) }
        ) {
            BoardCardView(
                instance: instance,
                width: w,
                owner: owner,
                showsPower: true,
                showsCost: true,
                isOwnerTurn: isActive
            )
                .onTapGesture {
                    if !viewModel.showDetailIfNeeded(instance, owner: owner) {
                        viewModel.toggleRest(instance.id, owner: owner)
                    }
                }
                .draggable(SoloDragItem(owner: owner, content: .card(instance.id))) {
                    dragPreview(instance)
                }
        }
    }

    // MARK: - リーダー（動かせない。レストとドン付与だけ）

    @ViewBuilder
    private var leaderCell: some View {
        if let leader = board.leader {
            SoloDropZone(
                onDrop: { drop($0, .cardTarget(id: leader.id, fallbackZone: nil)) }
            ) {
                BoardCardView(instance: leader, width: w, owner: owner, showsPower: true, isOwnerTurn: isActive)
                    .onTapGesture {
                        if !viewModel.showDetailIfNeeded(leader, owner: owner) {
                            viewModel.toggleRest(leader.id, owner: owner)
                        }
                    }
            }
        } else {
            placeholder("リーダー").frame(width: w, height: h)
        }
    }

    // MARK: - ステージ（1枚まで）

    private var stageCell: some View {
        SoloDropZone(
            isInvalid: board.stage != nil,
            onDrop: { drop($0, .zone(.stage)) }
        ) {
            if let stage = board.stage {
                BoardCardView(instance: stage, width: w, owner: owner)
                    .onTapGesture {
                        if !viewModel.showDetailIfNeeded(stage, owner: owner) {
                            viewModel.toggleRest(stage.id, owner: owner)
                        }
                    }
                    .draggable(SoloDragItem(owner: owner, content: .card(stage.id))) {
                        dragPreview(stage)
                    }
            } else {
                placeholder("ステージ").frame(width: w, height: h)
            }
        }
    }

    // MARK: - ライフ（自分側は列の一番下から上へ、相手側は一番上から下へ重ねていく）

    private var lifeColumn: some View {
        SoloDropZone(onDrop: { drop($0, .zone(.life)) }) {
            ZStack(alignment: .top) {
                if board.life.isEmpty {
                    placeholder("ライフ").frame(width: w, height: lifeColumnHeight)
                } else {
                    lifeStack
                }
            }
            .frame(width: w, height: lifeColumnHeight, alignment: .top)
        }
    }

    private var lifeStack: some View {
        let count = board.life.count
        // 1枚ごとのずらし幅。全部が列の高さに収まるように縮める
        let step = count > 1 ? min(h * 0.45, (lifeColumnHeight - h) / CGFloat(count - 1)) : 0

        // 自分側: 底のカードを列の一番下に置き、1枚ごとに上へ重ねる（一番上のカードが一番上）。
        // 相手側: 向かい側から見た向きにするため、底のカードを列の一番上に置き、1枚ごとに下へ重ねる。
        let stackAlignment: Alignment = isOpponentSide ? .top : .bottom
        let direction: CGFloat = isOpponentSide ? 1 : -1

        return ZStack(alignment: stackAlignment) {
            // 底のカードから先に描き、一番上のカードを最後（一番手前）にする
            ForEach(board.life.indices.reversed(), id: \.self) { index in
                let card = board.life[index]
                BoardCardView(instance: card, width: w, owner: owner)
                    .offset(y: direction * step * CGFloat(count - 1 - index))
                    .onTapGesture {
                        if !viewModel.showDetailIfNeeded(card, owner: owner, isFaceUp: card.isFaceUp) {
                            viewModel.flipLifeCard(card.id, owner: owner)
                        }
                    }
                    .draggable(SoloDragItem(owner: owner, content: .card(card.id))) {
                        dragPreview(card)
                    }
            }
        }
        .frame(width: w, height: lifeColumnHeight, alignment: stackAlignment)
        .overlay(alignment: isOpponentSide ? .bottomTrailing : .topTrailing) {
            countBadge(count)
        }
    }

    // MARK: - デッキ（2段目の右端）

    private var deckCell: some View {
        SoloDropZone(onDrop: { drop($0, .zone(.deck)) }) {
            ZStack(alignment: .topTrailing) {
                if board.deck.isEmpty {
                    placeholder("デッキ")
                } else {
                    CardBackImage(cornerRadius: 4)
                        .onTapGesture { viewModel.activePanel = .deck(owner) }
                    countBadge(board.deck.count)
                }
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - 3段目（ドンデッキ・コストエリア・トラッシュ）

    private var donDeckCell: some View {
        SoloDropZone(onDrop: { drop($0, .donDeck) }) {
            ZStack {
                if board.donDeck > 0 {
                    CardBackImage(imageName: "DonBack", cornerRadius: 3)
                        .frame(width: bottomCardWidth)
                        // タップで、アクティブなドンを1枚、コストエリアに追加する
                        .onTapGesture {
                            viewModel.moveDon(owner: owner, from: .donDeck, to: .costArea)
                        }
                        .draggable(SoloDragItem(owner: owner, content: .don(.donDeck))) {
                            CardBackImage(imageName: "DonBack", cornerRadius: 3).frame(width: bottomCardWidth)
                        }
                        .overlay(alignment: .topTrailing) {
                            countBadge(board.donDeck)
                        }
                } else {
                    placeholder("ドンデッキ", width: bottomCardWidth, height: bottomRowHeight)
                }
            }
            .frame(width: w, height: bottomRowHeight)
        }
    }

    private var trashCell: some View {
        SoloDropZone(onDrop: { drop($0, .zone(.trash)) }) {
            ZStack {
                if let top = board.trash.first {
                    CardThumbnailImage(card: top.card, cornerRadius: 3)
                        .frame(width: bottomCardWidth)
                        // 詳細モードのときは一番上のカードの詳細、通常は一覧パネルを開く
                        .onTapGesture {
                            if !viewModel.showDetailIfNeeded(top, owner: owner) {
                                viewModel.activePanel = .trash(owner)
                            }
                        }
                        .draggable(SoloDragItem(owner: owner, content: .card(top.id))) {
                            CardThumbnailImage(card: top.card, cornerRadius: 3).frame(width: bottomCardWidth)
                        }
                        .overlay(alignment: .topTrailing) {
                            countBadge(board.trash.count)
                        }
                } else {
                    placeholder("トラッシュ", width: bottomCardWidth, height: bottomRowHeight)
                }
            }
            .frame(width: w, height: bottomRowHeight)
        }
    }

    /// コストエリア。ドンを1枚ずつ、左から重ねて並べる（最大10枚。多いときは重なりが深くなる）。
    /// レストのドンは横向き。1枚ずつ、タップでレスト⇄アクティブ、ドラッグで付与・ドンデッキへ戻す。
    private var costArea: some View {
        SoloDropZone(onDrop: { drop($0, .costArea) }) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))

                if board.costDon.isEmpty {
                    Text("コストエリア")
                        .font(.system(size: max(w * 0.2, 8)))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    costDonFan
                }
            }
            .frame(width: costAreaWidth, height: bottomRowHeight)
        }
    }

    private var costDonFan: some View {
        let count = board.costDon.count
        let sideMargin: CGFloat = 4
        // 1枚ごとのずらし幅。少ないうちは少し間をあけ、多いときは全部が収まるように重ねる
        let available = costAreaWidth - bottomCardWidth - sideMargin * 2
        let step = count > 1 ? min(bottomCardWidth + 3, available / CGFloat(count - 1)) : 0

        // 自分側は左から、相手側（点対称）は右から並べていく
        let alignment: Alignment = isOpponentSide ? .trailing : .leading
        let direction: CGFloat = isOpponentSide ? -1 : 1

        return ZStack(alignment: alignment) {
            ForEach(board.costDon.indices, id: \.self) { index in
                // 一番端（最初に出した）ドンに、コストエリアのドンの合計の枚数を表示する
                donCardView(
                    board.costDon[index],
                    countLabel: index == 0 ? "\(board.donCount)" : nil
                )
                .offset(x: direction * (sideMargin + step * CGFloat(index)))
            }
        }
        .frame(width: costAreaWidth, height: bottomRowHeight, alignment: alignment)
    }

    /// コストエリアのドン1枚。countLabel を渡すと、そのドンの上に枚数を表示する
    private func donCardView(_ don: DonCard, countLabel: String? = nil) -> some View {
        CardBackImage(imageName: "DonFront", cornerRadius: 3)
            .frame(width: bottomCardWidth)
            .rotationEffect(.degrees(don.isRested ? 90 : 0))
            .opacity(don.isRested ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.2), value: don.isRested)
            .onTapGesture { viewModel.toggleDon(owner: owner, id: don.id) }
            .draggable(SoloDragItem(owner: owner, content: .don(.cost(don.id)))) {
                CardBackImage(imageName: "DonFront", cornerRadius: 3).frame(width: bottomCardWidth)
            }
            // 枚数は、重なりで隠れにくい、ドンの並びの一番端の側に出す（相手側は点対称なので右）
            .overlay(alignment: isOpponentSide ? .topTrailing : .topLeading) {
                if let countLabel {
                    Text(countLabel)
                        .font(.system(size: max(w * 0.2, 8), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - 共通の部品

    /// カードが無いときの、点線の枠（大きさを指定しなければ、通常のカードの大きさ）
    private func placeholder(_ title: String, width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3]))
            .frame(width: width ?? w, height: height ?? h)
            .contentShape(Rectangle())
            .overlay {
                Text(title)
                    .font(.system(size: max(w * 0.2, 8)))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .padding(2)
            }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: max(w * 0.26, 10), weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.black.opacity(0.75), in: Capsule())
            .padding(2)
            .allowsHitTesting(false)
    }

    /// ドラッグ中に指についてくる見た目
    @ViewBuilder
    private func dragPreview(_ instance: CardInstance) -> some View {
        if instance.isFaceUp {
            CardThumbnailImage(card: instance.card, cornerRadius: 4).frame(width: w)
        } else {
            CardBackImage(cornerRadius: 4).frame(width: w)
        }
    }

    /// ドロップの処理と、成功/拒否の触覚フィードバック
    private func drop(_ items: [SoloDragItem], _ target: SoloDropTarget) -> Bool {
        let accepted = viewModel.performDrop(items, owner: owner, target: target)
        if accepted {
            SoloHaptics.dropped()
        } else {
            SoloHaptics.rejected()
        }
        return accepted
    }
}
