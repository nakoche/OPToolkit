//
//  DeckStatsGrid.swift
//  OPToolkit
//
//  デッキ内訳の各種数値をまとめて表示する。
//  指定の並び順（一部は2列、トータルカウンターだけ1行フル幅）で固定表示する。
//

import SwiftUI

struct DeckStatsGrid: View {
    let deck: Deck

    var body: some View {
        VStack(spacing: 0) {
            pairRow(("キャラクター", deck.characterCount), ("イベント", deck.eventCount))
            Divider()
            pairRow(("カウンター1000", deck.counter1000Count), ("ステージ", deck.stageCount))
            Divider()
            pairRow(("カウンター2000", deck.counter2000Count), ("カウンターレス", deck.counterlessCount))
            Divider()
            singleRow(("トータルカウンター", deck.totalCounterValue))
            Divider()
            pairRow(("ブロッカー", deck.blockerCount), ("トリガー", deck.triggerCount))
        }
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func pairRow(_ left: (title: String, value: Int), _ right: (title: String, value: Int)) -> some View {
        HStack(spacing: 16) {
            statCell(left)
            statCell(right)
        }
        .padding(.vertical, 8)
    }

    private func singleRow(_ item: (title: String, value: Int)) -> some View {
        statCell(item)
            .padding(.vertical, 8)
    }

    private func statCell(_ item: (title: String, value: Int)) -> some View {
        HStack {
            Text(item.title)
                .font(.subheadline)
            Spacer()
            Text("\(item.value)")
                .font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DeckStatsGrid(deck: .sample)
        .padding()
}
