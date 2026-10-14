//
//  SoloPlayView.swift
//  OPToolkit
//
//  ③一人回し画面。ロジックは全てSoloPlayViewModelに委譲する。
//  進行段階（viewModel.phase）に応じて、次の3つの画面を切り替える。
//   - デッキ選択（開始画面）: SoloDeckSelectionView
//   - マリガン選択:           SoloMulliganView
//   - 対戦中:                 盤面（BoardArea）+ 下部の操作バー
//  カードの詳細表示（拡大・パワー/コストの変更）は、ヘッダーや操作バーも含めた画面全体に重ねて出す。
//

import SwiftUI

struct SoloPlayView: View {
    @State var viewModel: SoloPlayViewModel

    var body: some View {
        ZStack {
            navigation

            // カード詳細: システムのシートは使わず、その場にフェード＋拡大で出す（カードリストと同じ）。
            // 場のキャラ・リーダーのときは、カードの下にパワー・コストを変更するパネルも出る。
            if let target = viewModel.detailTarget {
                CardDetailModal(
                    card: target.card,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.detailTarget = nil
                        }
                    },
                    accessory: {
                        SoloCardEditPanel(viewModel: viewModel, target: target)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(1)
            }
        }
    }

    private var navigation: some View {
        NavigationStack {
            content
                .navigationTitle("一人回し")
                .navigationBarTitleDisplayMode(.inline)
                // 対戦中は「一人回し」のタイトルバーを隠して、盤面に高さを回す
                // （マリガンの「中止」ボタンは、対戦前のバーに出るので影響しない）
                .toolbar(viewModel.phase == .playing ? Visibility.hidden : Visibility.automatic, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        // マリガン中は操作バーが無いので、ここから中断できるようにする
                        if isMulligan {
                            Button("中止") {
                                viewModel.endBattle()
                            }
                        }
                    }
                }
                .confirmationDialog("その他の操作", isPresented: $viewModel.isMenuPresented) {
                    Button("バトルをやり直す", role: .destructive) {
                        viewModel.restartBattle()
                    }
                    Button("バトル終了", role: .destructive) {
                        viewModel.endBattle()
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .task {
                    // 表示するたびにデッキ一覧を最新にする（デッキ画面での編集を反映するため）
                    await viewModel.loadDecks()
                }
        }
    }

    private var isMulligan: Bool {
        if case .mulligan = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .deckSelection:
            SoloDeckSelectionView(viewModel: viewModel)
        case .mulligan:
            SoloMulliganView(viewModel: viewModel)
        case .playing:
            playingContent
        }
    }

    // MARK: - 対戦中

    private var playingContent: some View {
        VStack(spacing: 0) {
            header

            Divider()

            BoardArea(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            Divider()

            controlBar
        }
        // ヘッダーなどの背景はグレー。手番を示す色付きの背景は、盤面の上下で分けて BoardArea が付ける
        .background { Color(uiColor: .systemGray5).ignoresSafeArea() }
    }

    private var header: some View {
        HStack {
            // 手番のプレイヤーごとに数える（先攻1ターン目、後攻1ターン目、先攻2ターン目…）
            Text("\(viewModel.current.activePlayer == .playerOne ? "先攻" : "後攻") \(viewModel.current.activePlayerTurnCount)ターン目")
                .font(.headline)
            Spacer()
            if viewModel.isDetailMode {
                Text("詳細を見るカードをタップ")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var controlBar: some View {
        HStack(spacing: 0) {
            controlButton("ellipsis.circle", label: "その他") {
                viewModel.isMenuPresented = true
            }
            controlButton("arrow.uturn.backward", label: "戻る", enabled: viewModel.canUndo) {
                viewModel.undo()
            }
            controlButton("arrow.uturn.forward", label: "進む", enabled: viewModel.canRedo) {
                viewModel.redo()
            }
            controlButton("rectangle.stack.badge.plus", label: "ドロー") {
                viewModel.draw()
            }
            controlButton("info.circle", label: "詳細", isHighlighted: viewModel.isDetailMode) {
                viewModel.toggleDetailMode()
            }
            controlButton("flag.checkered", label: "ターン終了") {
                viewModel.endTurn()
            }
            controlButton("arrow.triangle.2.circlepath", label: "視点切替") {
                viewModel.togglePerspective()
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// isHighlighted が true のとき（詳細モード中など）は、ボタンの背景を色付きにして、押されていることを示す
    private func controlButton(
        _ systemImage: String,
        label: String,
        enabled: Bool = true,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                isHighlighted ? Color.accentColor.opacity(0.2) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .disabled(!enabled)
    }
}

#Preview {
    SoloPlayView(
        viewModel: SoloPlayViewModel(
            deckStore: DeckStore(
                cardRepository: MockCardRepository(),
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-decks.json")
            )
        )
    )
}
