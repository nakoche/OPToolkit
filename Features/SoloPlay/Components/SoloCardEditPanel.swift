//
//  SoloCardEditPanel.swift
//  OPToolkit
//
//  カードの詳細画面（CardDetailModal）の、カード画像の下に出す、パワー・コストの変更パネル。
//  - 場のリーダー・キャラ: パワーを ±1000 / ±5000 で増減
//  - 場のキャラ: コストを ±1 で増減
//  それ以外のカード（手札・トラッシュ・ステージなど）には、何も出さない（詳細画面は、拡大表示だけ）。
//  増減は、そのカードが場を離れるとリセットされる（ターン終了ではリセットしない）。
//  操作は Undo / Redo の対象。パネルの文字は、増減しているときに色を変えて分かるようにする。
//  パワーは0を下回ってマイナスになってもよい（コストは0まで）。
//

import SwiftUI

struct SoloCardEditPanel: View {
    let viewModel: SoloPlayViewModel
    let target: SoloDetailTarget

    private var board: PlayerBoard { viewModel.current[target.owner] }
    private var instance: CardInstance? { board.instance(target.instanceID) }
    private var zone: BoardZone? { board.locate(target.instanceID)?.zone }

    private var canEditPower: Bool { zone == .leader || zone == .characters }
    private var canEditCost: Bool { zone == .characters }

    var body: some View {
        if let instance, canEditPower || canEditCost {
            VStack(spacing: 10) {
                if canEditPower {
                    powerRow(instance)
                }
                if canEditCost {
                    costRow(instance)
                }

                HStack {
                    Text("場を離れるとリセットされます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if instance.hasModifiers {
                        Button("元に戻す") {
                            viewModel.resetModifiers(target.instanceID, owner: target.owner)
                        }
                        .font(.caption.bold())
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - パワー

    private func powerRow(_ instance: CardInstance) -> some View {
        HStack(spacing: 6) {
            Text("パワー")
                .font(.subheadline.bold())
                .frame(width: 52, alignment: .leading)

            stepButton("−5000") { adjustPower(-5000) }
            stepButton("−1000") { adjustPower(-1000) }

            Spacer(minLength: 4)

            // 基本のパワーに増減を加えた数値（ドン付与分は含めない）。増減しているときは色を変える
            Text(String(instance.effectivePower))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(valueColor(for: instance.powerModifier))
                .frame(minWidth: 64)

            Spacer(minLength: 4)

            stepButton("+1000") { adjustPower(1000) }
            stepButton("+5000") { adjustPower(5000) }
        }
    }

    // MARK: - コスト

    private func costRow(_ instance: CardInstance) -> some View {
        HStack(spacing: 6) {
            Text("コスト")
                .font(.subheadline.bold())
                .frame(width: 52, alignment: .leading)

            stepButton("−1") { adjustCost(-1) }

            Spacer(minLength: 4)

            Text(String(instance.effectiveCost))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(valueColor(for: instance.costModifier))
                .frame(minWidth: 64)

            Spacer(minLength: 4)

            stepButton("+1") { adjustCost(1) }
        }
    }

    // MARK: - 部品

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .frame(minWidth: 40)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func valueColor(for modifier: Int) -> Color {
        if modifier > 0 { return .red }
        if modifier < 0 { return .blue }
        return .primary
    }

    private func adjustPower(_ delta: Int) {
        viewModel.adjustPower(target.instanceID, owner: target.owner, by: delta)
    }

    private func adjustCost(_ delta: Int) {
        viewModel.adjustCost(target.instanceID, owner: target.owner, by: delta)
    }
}
