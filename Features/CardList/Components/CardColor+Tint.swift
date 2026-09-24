//
//  CardColor+Tint.swift
//  OPToolkit
//
//  CardColor(データ)をFilterChipで使うColor(表示)に変換する。
//  Modelsはプレゼンテーション非依存にしたいので、あえてFeatures側に置いている。
//

import SwiftUI

extension CardColor {
    var tint: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .black: return .black
        case .yellow: return Color(red: 0.75, green: 0.6, blue: 0.0)   // 白文字でも視認できるよう少し濃いめの黄
        }
    }
}
