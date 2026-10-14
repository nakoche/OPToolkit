//
//  SoloDeckSelectionView.swift
//  OPToolkit
//
//  一人回しの開始画面。左に先攻、右に後攻それぞれの「デッキを選択」ボタンを置く。
//  デッキを選ぶと、そのデッキのリーダーが表示される（未選択のときはカードの裏面）。
//  両方選ぶと、画面下部中央の「バトル開始」が押せるようになり、押すとマリガン選択へ進む。
//  選べるのは、リーダー設定済みで50枚のデッキだけ。
//  2人分の枠は画面の縦中央に置き、「バトル開始」は、画面の一番下と「デッキを選択」ボタンの中間あたりに置く。
//  iPhone・iPadどちらでも、左右2列のまま幅に合わせて広がる（リーダー画像は最大幅を制限）。
//

import SwiftUI

struct SoloDeckSelectionView: View {
    @Bindable var viewModel: SoloPlayViewModel

    /// 選択シートを開く対象（nilなら閉じている）
    @State private var pickerTarget: Perspective?
    /// 2人分の枠の高さ。「バトル開始」の位置を決めるために測る
    @State private var slotsHeight: CGFloat = 0

    var body: some View {
        // ScrollViewの中身に「画面と同じ高さ以上」の最小高さを与え、その中で中央に置く。
        // こうすると、普段は縦中央に並び、画面が小さくて収まらないときだけスクロールできる。
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        slot(for: .playerOne)
                        slot(for: .playerTwo)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .background(slotsHeightReader)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)

                startButton
                    .position(
                        x: geometry.size.width / 2,
                        y: startButtonCenterY(areaHeight: geometry.size.height)
                    )
            }
        }
        .sheet(item: $pickerTarget) { target in
            SoloDeckPickerSheet(
                title: target == .playerOne ? "先攻のデッキを選択" : "後攻のデッキを選択",
                decks: viewModel.availableDecks,
                selectedDeckID: viewModel.selectedDeck(for: target)?.id,
                onSelect: { deck in
                    viewModel.selectDeck(deck, for: target)
                    pickerTarget = nil
                },
                onCancel: {
                    pickerTarget = nil
                }
            )
        }
        .alert(
            "バトルを開始できません",
            isPresented: Binding(
                get: { viewModel.startErrorMessage != nil },
                set: { if !$0 { viewModel.startErrorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(viewModel.startErrorMessage ?? "")
        }
    }

    // MARK: - 1人分の枠

    private func slot(for player: Perspective) -> some View {
        let deck = viewModel.selectedDeck(for: player)

        return VStack(spacing: 12) {
            Text(player == .playerOne ? "先攻" : "後攻")
                .font(.headline)

            // デッキ未選択のときは、カードの裏面を出す
            Group {
                if let leader = deck?.leaderCard {
                    CardThumbnailImage(card: leader, cornerRadius: 10)
                } else {
                    CardBackImage(cornerRadius: 10)
                }
            }
            .frame(maxWidth: 200)

            Text(deck?.name ?? "未選択")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(deck == nil ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // リーダーのライフ値（この枚数のライフで始まる）
            if let leader = deck?.leaderCard {
                Text(leader.soloPlayStartingLifeText)
                    .font(.caption)
                    .foregroundStyle(leader.life == nil ? Color.orange : Color.secondary)
            }

            Button("デッキを選択") {
                // 開くたびに最新の一覧にする（デッキ画面で編集した内容を反映するため）
                viewModel.refreshDecks()
                pickerTarget = player
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - バトル開始ボタン

    private var startButton: some View {
        Button {
            viewModel.startBattleWithSelectedDecks()
        } label: {
            Text("バトル開始")
                .font(.headline)
                .frame(width: 280)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canStartBattle)
    }

    /// 2人分の枠の高さを測って slotsHeight に入れる（レイアウトには影響しない）
    private var slotsHeightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { slotsHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, newHeight in
                    slotsHeight = newHeight
                }
        }
    }

    /// 「バトル開始」の縦位置。以前の位置（画面の一番下）と、「デッキを選択」ボタンの中間にする。
    /// 枠は縦中央に置かれているので、枠の下端 = 画面の中央 + 枠の高さの半分。
    private func startButtonCenterY(areaHeight: CGFloat) -> CGFloat {
        let slotsBottom = areaHeight / 2 + slotsHeight / 2
        let deckButtonY = slotsBottom - 24 - 16           // 枠の下の余白 + ボタンの高さの半分
        let formerButtonY = areaHeight - 33               // 以前、画面の一番下に置いていたときの中心
        let middle = (deckButtonY + formerButtonY) / 2
        // 枠に重ならず、画面からもはみ出さない範囲に収める
        return min(max(middle, slotsBottom + 32), areaHeight - 36)
    }
}
