//
//  AppSettings.swift
//  OPToolkit
//

import SwiftUI

/// 画面モード設定
enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "システムに合わせる"
    case light = "ライト"
    case dark = "ダーク"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// カードリストの並び替えキー（Settings・CardListの両方から参照するのでここに置く）
enum CardSortKey: String, CaseIterable, Identifiable {
    case name = "名前"
    case cost = "コスト"
    case power = "パワー"

    var id: String { rawValue }
}

enum SortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    var systemImage: String {
        self == .ascending ? "arrow.up" : "arrow.down"
    }
}
