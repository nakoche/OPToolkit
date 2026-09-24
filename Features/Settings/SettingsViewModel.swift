//
//  SettingsViewModel.swift
//  OPToolkit
//
//  設定値そのものは@AppStorageで永続化するため、ViewModelは
//  「どのキーを、どのenumとして扱うか」の変換ロジックだけを持つ薄い層。
//

import Foundation

@Observable
final class SettingsViewModel {
    // View側の@AppStorageバインディングをenumとして扱うためのヘルパー
    func colorScheme(from rawValue: String) -> AppColorScheme {
        AppColorScheme(rawValue: rawValue) ?? .system
    }

    func sortKey(from rawValue: String) -> CardSortKey {
        CardSortKey(rawValue: rawValue) ?? .name
    }

    // TODO: バージョン番号などBundleから取得する値もここに集約できる
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
