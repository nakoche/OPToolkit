//
//  DeckStatsGrid.swift
//  OPToolkit
//
//  デッキ内訳の各種数値をまとめて表示する。
//  指定の並び順（一部は2列、トータルカウンターだけ1行フル幅）で固定表示し、
//  各項目は独立した背景ボックスとして表示する（1つの箱にまとめない）。
//  各ボックス内は「項目名が左・数字が右」のレイアウト。
//

import SwiftUI

struct DeckStatsGrid: View {
    let deck: Deck

    var body: some View {
        VStack(spacing: 8) {
            pairRow(("キャラクター", deck.characterCount), ("イベント", deck.eventCount))
            pairRow(("カウンター1000", deck.counter1000Count), ("ステージ", deck.stageCount))
            pairRow(("カウンター2000", deck.counter2000Count), ("カウンターレス", deck.counterlessCount))
            singleRow(("トータルカウンター", deck.totalCounterValue))
            pairRow(("ブロッカー", deck.blockerCount), ("トリガー", deck.triggerCount))
        }
    }

    private func pairRow(_ left: (title: String, value: Int), _ right: (title: String, value: Int)) -> some View {
        HStack(spacing: 8) {
            statBox(left)
            statBox(right)
        }
    }

    private func singleRow(_ item: (title: String, value: Int)) -> some View {
        statBox(item)
    }

    private func statBox(_ item: (title: String, value: Int)) -> some View {
        HStack {
            Text(item.title)
                .font(.subheadline)
            Spacer()
            Text("\(item.value)")
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    DeckStatsGrid(deck: .sample)
        .padding()
}
