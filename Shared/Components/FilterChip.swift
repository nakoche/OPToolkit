//
//  FilterChip.swift
//  OPToolkit
//
//  検索シート内の各種フィルタで使う、押すとON/OFFが切り替わるボタン。
//
//  未選択時: 薄いグレー背景 + tint色の文字
//  選択時  : tint色の背景 + 白文字
//  （色別フィルタのように項目ごとに違うtintを渡せば多色に、
//    それ以外は共通の1色を渡せば「押したことがわかる」だけのシンプルな見た目になる）
//

import SwiftUI

struct FilterChip: View {
    let label: String
    var tint: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? tint : Color(uiColor: .systemGray5),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(isSelected ? .white : tint)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack {
            FilterChip(label: "赤", tint: .red, isSelected: true) {}
            FilterChip(label: "緑", tint: .green, isSelected: false) {}
        }
        HStack {
            FilterChip(label: "3", isSelected: true) {}
            FilterChip(label: "4", isSelected: false) {}
        }
    }
    .padding()
}
