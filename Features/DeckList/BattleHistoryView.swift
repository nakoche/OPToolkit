//
//  BattleHistoryView.swift
//  OPToolkit
//
//  対戦履歴画面。詳細仕様は未定なので、遷移先としてのプレースホルダーのみ用意する。
//  TODO: 対戦記録の保存方法（勝敗、使用デッキ、対戦相手のデッキ色など）が決まり次第実装する。
//

import SwiftUI

struct BattleHistoryView: View {
    /// 特定デッキの履歴だけを見たい場合に渡す（未指定なら全デッキの履歴を想定）
    var deck: Deck?

    var body: some View {
        ContentUnavailableView(
            "対戦履歴",
            systemImage: "clock.arrow.circlepath",
            description: Text(deck.map { "「\($0.name)」の対戦履歴はまだありません" } ?? "この画面は準備中です")
        )
        .navigationTitle("対戦履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BattleHistoryView()
    }
}
