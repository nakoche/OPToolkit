//
//  SoloDropZone.swift
//  OPToolkit
//
//  ドロップ先に共通の部品。ドラッグ中に指が上に来ると、枠を光らせる。
//  isInvalid が true のときは赤く光らせる（キャラエリアが満杯など、今は置けない場所を伝えるため）。
//  実際に置けるかどうかは onDrop の戻り値（false なら拒否）で決まる。
//  contentShape を付けているのは、点線の枠だけの空きスロットやカード同士のすき間のような
//  「何も描かれていない部分」でも、ゾーンの全体をドロップ先として受け付けるため。
//  （付けないと、描かれている線の上にしかドロップできず、判定が極端に狭くなる）
//

import SwiftUI

struct SoloDropZone<Content: View>: View {
    let isInvalid: Bool
    let onDrop: ([SoloDragItem]) -> Bool
    let content: Content

    @State private var isTargeted = false

    init(
        isInvalid: Bool = false,
        onDrop: @escaping ([SoloDragItem]) -> Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.isInvalid = isInvalid
        self.onDrop = onDrop
        self.content = content()
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isInvalid ? Color.red : Color.accentColor, lineWidth: 3)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: SoloDragItem.self) { items, _ in
                onDrop(items)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}
