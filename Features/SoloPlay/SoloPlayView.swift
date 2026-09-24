//
//  SoloPlayView.swift
//  OPToolkit
//
//  ③一人回し画面。ロジックは全てSoloPlayViewModelに委譲する。
//

import SwiftUI

struct SoloPlayView: View {
    @State var viewModel: SoloPlayViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Divider()

                BoardArea(board: viewModel.visibleBoard, perspective: viewModel.perspective)
                    .frame(maxHeight: .infinity)

                Divider()

                controlBar
            }
            .navigationTitle("一人回し")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("その他の操作", isPresented: $viewModel.isMenuPresented) {
                Button("盤面をリセット", role: .destructive) {
                    viewModel.resetGame()
                }
                Button("マリガン（手札引き直し）") {
                    // TODO: マリガン処理を実装
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        HStack {
            Text("ターン \(viewModel.current.turnNumber)")
                .font(.headline)
            Spacer()
            Text(viewModel.current.activePlayer == .playerOne ? "先手番" : "後手番")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var controlBar: some View {
        HStack(spacing: 0) {
            controlButton("arrow.uturn.backward", label: "戻る", enabled: viewModel.canUndo) {
                viewModel.undo()
            }
            controlButton("arrow.uturn.forward", label: "進む", enabled: viewModel.canRedo) {
                viewModel.redo()
            }
            controlButton("rectangle.stack.badge.plus", label: "ドロー") {
                viewModel.draw()
            }
            controlButton("arrow.triangle.2.circlepath", label: "視点切替") {
                viewModel.togglePerspective()
            }
            controlButton("flag.checkered", label: "ターン終了") {
                viewModel.endTurn()
            }
            controlButton("ellipsis.circle", label: "その他") {
                viewModel.isMenuPresented = true
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func controlButton(
        _ systemImage: String,
        label: String,
        enabled: Bool = true,
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
        }
        .disabled(!enabled)
    }
}

#Preview {
    SoloPlayView(viewModel: SoloPlayViewModel())
}
