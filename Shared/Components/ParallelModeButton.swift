//
//  ParallelModeButton.swift
//  OPToolkit
//
//  パラレル表示の切り替えボタン（星アイコン）。
//  タップするたびに ノーマルのみ → 混在 → パラレルのみ と循環する。
//  リーダー選択画面とカードリスト画面で、同じ見た目・動作にするために共通化している。
//

import SwiftUI

struct ParallelModeButton: View {
    @Binding var mode: ParallelDisplayMode
    /// ボタンの直径。アイコンの大きさもこれに比例させる
    var size: CGFloat = 36
    
    var body: some View {
        Button {
            mode.advance()
        } label: {
            Image(systemName: mode.symbolName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(.yellow)
                .frame(width: size, height: size)
                .background(Color(uiColor: .systemGray5), in: Circle())
        }
        .accessibilityLabel("パラレル表示切替")
    }
}

#Preview {
    @Previewable @State var mode = ParallelDisplayMode.mixed
    ParallelModeButton(mode: $mode)
}
