//
//  SoloPlayViewModel+Detail.swift
//  OPToolkit
//
//  カードの詳細表示（操作バーの「詳細」ボタン）まわり。
//  「詳細」ボタンを押すと詳細モードになり、次にタップしたカードの詳細を表示して、モードは自動で解除される。
//  詳細画面では、カードを大きく見られるほか、場のキャラ・リーダーはパワーやコストを増減できる。
//  ダブルタップなど、ふだんの操作（レストなど）と干渉しないようにするための仕組み。
//

import SwiftUI

extension SoloPlayViewModel {
    /// 詳細モード中なら、タップされたカードの詳細を表示して true を返す（モードはここで解除する）。
    /// 詳細モードでなければ false を返すので、呼び出し側は通常のタップ処理（レストなど）を行う。
    /// 裏向きのカードは中身を見せないため表示せず、詳細モードのまま触覚で知らせる（タップは消費する）。
    /// - owner: そのカードの持ち主（増減などの操作は、この人の盤面に対して行う）
    @discardableResult
    func showDetailIfNeeded(_ instance: CardInstance, owner: Perspective, isFaceUp: Bool = true) -> Bool {
        guard isDetailMode else { return false }

        guard isFaceUp else {
            SoloHaptics.rejected()
            return true
        }

        withAnimation(.easeOut(duration: 0.18)) {
            detailTarget = SoloDetailTarget(owner: owner, instanceID: instance.id, card: instance.card)
            isDetailMode = false
        }
        return true
    }

    /// 操作バーの「詳細」ボタン。もう一度押すと、詳細モードを取り消す
    func toggleDetailMode() {
        isDetailMode.toggle()
    }
}
