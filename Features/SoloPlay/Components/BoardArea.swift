//
//  BoardArea.swift
//  OPToolkit
//
//  対戦中の盤面全体。上から、相手の手札（裏向き）、相手の盤面、自分（視点側）の盤面、自分の手札を並べる。
//  画面の上半分（相手側）と下半分（自分側）で、背景色を分ける: 手番のプレイヤーの側は、先攻ならオレンジ、
//  後攻なら青、手番でない側はグレー。
//  「視点切替」を押すと（ターン終了でも自動で切り替わる）、上下の役割と、手札を見せる側が入れ替わる。
//  そのとき、盤面全体が回るアニメーションで入れ替える（前半: 90°まで回って薄くなる → 見えない間に
//  視点を入れ替える → 後半: -90°から0°まで回って現れる）。入れ替え後の盤面は、入れ替え前を180°回した
//  配置（点対称）なので、回転が途切れずにつながって見える。
//  回る向きは、先攻側 → 後攻側への切り替えが右回り（時計回り）、後攻側 → 先攻側が左回り。
//
//  カードの大きさは、画面の幅（7列が収まる）と高さ（上下2人分の3段の盤面と手札が収まる）の
//  小さいほうに合わせて決める。iPhoneでもiPadでも同じ配置のまま大きさだけ変わる。
//  盤面が3段になった分は、3段目（ドン・トラッシュ）の高さを約7割にし、自分の手札のカードを
//  盤面と同じ大きさにし、対戦中は「一人回し」のタイトルバーを隠して、高さを確保している
//  （カードの大きさが、幅で決まる今までの大きさのままになるように）。
//
//  山札・ライフにドロップしたカードは、ここで「上に置く／下に置く」を選んでもらう。
//

import SwiftUI

struct BoardArea: View {
    let viewModel: SoloPlayViewModel

    /// 画面に表示している視点。視点が切り替わったとき、回転アニメーションの途中で入れ替える
    @State private var displayedPerspective: Perspective
    @State private var spinAngle: Double = 0
    @State private var spinScale: Double = 1
    @State private var spinOpacity: Double = 1
    /// 回転アニメーション中か（中は、盤面を触れないようにする）
    @State private var isSpinning = false

    init(viewModel: SoloPlayViewModel) {
        self.viewModel = viewModel
        _displayedPerspective = State(initialValue: viewModel.perspective)
    }

    private let spacing: CGFloat = 4
    /// 上半分・下半分の中で、並べるもの（手札と盤面）の間のすき間
    private let stackSpacing: CGFloat = 4
    /// 上半分・下半分の、上下の余白
    private let halfPadding: CGFloat = 4
    private let horizontalPadding: CGFloat = 16
    /// 手札のカードは、盤面のカードより少し大きくする
    private let handScale: CGFloat = 1.0
    /// 相手の手札（裏向き）は、場所をとらないよう盤面のカードより少し小さくする
    private let opponentHandScale: CGFloat = 0.8

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = fittingCardWidth(for: geometry.size)

            // 画面の上半分（相手の手札と盤面）と下半分（自分の盤面と手札）を、別々の背景色にする。
            // 回転アニメーションでは、背景も一緒に回る。
            VStack(spacing: 0) {
                VStack(spacing: stackSpacing) {
                    SoloHandView(
                        viewModel: viewModel,
                        hand: viewModel.current[displayedPerspective.opponent].hand,
                        owner: displayedPerspective.opponent,
                        cardWidth: cardWidth * opponentHandScale,
                        isHidden: true
                    )
                    .frame(maxWidth: cardWidth * 7 + spacing * 6)

                    PlayerBoardView(
                        viewModel: viewModel,
                        board: viewModel.current[displayedPerspective.opponent],
                        owner: displayedPerspective.opponent,
                        isOpponentSide: true,
                        isActive: viewModel.current.activePlayer == displayedPerspective.opponent,
                        cardWidth: cardWidth
                    )
                }
                .padding(.vertical, halfPadding)
                // 余った高さは、2つの半分で分け合う。中身は、真ん中の境目に寄せて置く
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background { halfBackground(for: displayedPerspective.opponent) }

                VStack(spacing: stackSpacing) {
                    PlayerBoardView(
                        viewModel: viewModel,
                        board: viewModel.current[displayedPerspective],
                        owner: displayedPerspective,
                        isOpponentSide: false,
                        isActive: viewModel.current.activePlayer == displayedPerspective,
                        cardWidth: cardWidth
                    )

                    SoloHandView(
                        viewModel: viewModel,
                        hand: viewModel.current[displayedPerspective].hand,
                        owner: displayedPerspective,
                        cardWidth: cardWidth * handScale
                    )
                    .frame(maxWidth: cardWidth * 7 + spacing * 6)
                }
                .padding(.vertical, halfPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background { halfBackground(for: displayedPerspective) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotationEffect(.degrees(spinAngle))
            .scaleEffect(spinScale)
            .opacity(spinOpacity)
            .allowsHitTesting(!isSpinning)
        }
        // 回っている間に盤面が、上下のヘッダーや操作バーにはみ出して見えないようにする
        .clipped()
        .onChange(of: viewModel.perspective) { _, _ in
            spinIfNeeded()
        }
        .overlay { panelLayer }
        .confirmationDialog(
            "どこに置きますか？",
            isPresented: Binding(
                get: { viewModel.pendingPlacement != nil },
                set: { if !$0 { viewModel.pendingPlacement = nil } }
            ),
            titleVisibility: .visible,
            presenting: viewModel.pendingPlacement
        ) { placement in
            // ボタンの処理は、ダイアログを開いた時点の placement を使う
            // （閉じる処理で pendingPlacement が先に消えても、置く操作が失われないように）
            Button("上に置く") {
                viewModel.moveCard(placement.cardID, owner: placement.owner, to: placement.zone, position: .top)
            }
            Button("下に置く") {
                viewModel.moveCard(placement.cardID, owner: placement.owner, to: placement.zone, position: .bottom)
            }
            Button("キャンセル", role: .cancel) {}
        } message: { placement in
            Text(placement.zone == .deck ? "デッキ" : "ライフ")
        }
    }

    /// 盤面の背景。手番のプレイヤーの側だけ、先攻ならオレンジ、後攻なら青に染め、そうでない側はグレーのままにする
    private func halfBackground(for player: Perspective) -> some View {
        let isTurnPlayer = viewModel.current.activePlayer == player

        return ZStack {
            Color(uiColor: .systemGray5)

            (player == .playerOne ? Color.orange : Color.blue)
                .opacity(isTurnPlayer ? 0.3 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: isTurnPlayer)
    }

    /// 視点が切り替わったら、盤面全体が回るアニメーションで、上下を入れ替える
    private func spinIfNeeded() {
        guard !isSpinning, displayedPerspective != viewModel.perspective else { return }
        isSpinning = true

        // 切り替え先が後攻側なら右回り（+）、先攻側なら左回り（-）
        let direction: Double = viewModel.perspective == .playerTwo ? 1 : -1

        // 前半: 90°まで回りながら、少し縮んで薄くなる
        withAnimation(.easeIn(duration: 0.25)) {
            spinAngle = 90 * direction
            spinScale = 0.85
            spinOpacity = 0
        } completion: {
            // 見えなくなったところで、表示する視点を入れ替える（アニメーションなし）。
            // 入れ替え後の盤面は、入れ替え前を180°回した配置なので、-90°から回り始めると、
            // 回転がつながって見える。
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedPerspective = viewModel.perspective
                spinAngle = -90 * direction
            }

            // 後半: -90°から0°まで回りながら、元の大きさに戻って現れる
            withAnimation(.easeOut(duration: 0.25)) {
                spinAngle = 0
                spinScale = 1
                spinOpacity = 1
            } completion: {
                isSpinning = false
                // 回っている間にさらに視点が変わっていたら、もう一度回す
                spinIfNeeded()
            }
        }
    }

    /// デッキ・トラッシュの確認パネル。盤面の上に重ねるだけで、下の操作バーは隠さない
    /// （パネルを開いたまま、戻る/進む/拡大ボタンも使える）。
    @ViewBuilder
    private var panelLayer: some View {
        if let panel = viewModel.activePanel {
            ZStack {
                // 後ろの盤面を暗くして、触れないようにする。この背景をタップするとパネルを閉じる
                // （パネルの上のドラッグ操作は、タップではないので影響しない）
                Color.black.opacity(0.45)
                    .onTapGesture {
                        viewModel.activePanel = nil
                    }

                switch panel {
                case .deck(let owner):
                    SoloDeckPanel(viewModel: viewModel, owner: owner)
                case .trash(let owner):
                    SoloTrashPanel(viewModel: viewModel, owner: owner)
                }
            }
            .transition(.opacity)
        }
    }

    /// カード1枚の幅。幅いっぱい（7列）と、高さいっぱい（上下2人分＋手札）の小さいほうに合わせる
    private func fittingCardWidth(for size: CGSize) -> CGFloat {
        let widthBased = (size.width - horizontalPadding - spacing * 6) / 7

        // 縦の合計 = カード幅 × 係数 + 固定の余白
        //   係数: 1人分の盤面は、カードの高さ(1.4)×（1段目・2段目の2段 + 3段目の縮小分）。
        //         これが2人分。手札は、自分が handScale、相手が opponentHandScale。
        //   固定分: 1人分の「段のすき間2つ」×2、手札の上下の余白(12)×2、
        //           半分の中の、並べるものの間のすき間(2つ)、半分の上下の余白(2つの半分 × 上下)
        let boardFactor = 1.4 * (2 + PlayerBoardView.bottomRowScale)
        let factor = 2 * boardFactor + 1.4 * (handScale + opponentHandScale)
        let perBoardFixed = spacing * 2
        let fixed = 2 * perBoardFixed + 12 * 2 + stackSpacing * 2 + halfPadding * 4
        let heightBased = (size.height - fixed) / factor

        return max(min(widthBased, heightBased), 20)
    }
}
