//
//  FeatureCountList.swift
//  OPToolkit
//
//  特徴（"麦わらの一味"など）ごとの合計枚数を表示する。0枚の特徴は表示しない
//  （Deck.featureCountsが既に0件を除外して返す）。
//

import SwiftUI

struct FeatureCountList: View {
    let counts: [(feature: String, count: Int)]

    var body: some View {
        if counts.isEmpty {
            Text("特徴を持つカードがありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(counts.enumerated()), id: \.element.feature) { index, entry in
                    if index > 0 {
                        Divider()
                    }
                    HStack {
                        Text(entry.feature)
                            .font(.subheadline)
                        Spacer()
                        Text("\(entry.count)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

#Preview {
    FeatureCountList(counts: [(feature: "麦わらの一味", count: 20), (feature: "剣士", count: 4)])
        .padding()
}
