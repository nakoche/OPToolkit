//
//  CostBarChart.swift
//  OPToolkit
//
//  コスト0〜10それぞれの枚数を「水が溜まっていく」ような棒グラフで表示する。
//  枠は固定サイズで、中の水位（塗りつぶし高さ）だけが枚数に応じて変わる。
//  10枚でMAX（それ以上は10として扱う）。
//

import SwiftUI

struct CostBarChart: View {
    /// コスト(0...10) -> 枚数
    let histogram: [Int: Int]

    private let costRange = 0...10
    private let maxValue = 10
    private let barHeight: CGFloat = 120
    private let barWidth: CGFloat = 22

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(costRange), id: \.self) { cost in
                bar(cost: cost, count: histogram[cost] ?? 0)
            }
        }
    }

    private func bar(cost: Int, count: Int) -> some View {
        let ratio = min(CGFloat(count), CGFloat(maxValue)) / CGFloat(maxValue)

        return VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                // 枠（固定サイズの「水槽」）
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(uiColor: .systemGray6))
                    .frame(width: barWidth, height: barHeight)

                // 水位
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: barWidth, height: barHeight * ratio)
            }
            .frame(height: barHeight)

            Text("\(cost)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CostBarChart(histogram: [0: 1, 1: 4, 2: 8, 3: 12, 4: 6, 5: 2, 6: 0, 7: 1, 8: 0, 9: 0, 10: 0])
        .padding()
}
