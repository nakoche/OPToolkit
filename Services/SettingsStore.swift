//
//  SettingsStore.swift
//  OPToolkit
//
//  @AppStorageのキーを一箇所に集約。View/ViewModel双方からのtypoを防ぐ。
//

import Foundation

enum SettingsStore {
    enum Key {
        static let colorScheme = "appColorScheme"
        static let enableSoundEffects = "enableSoundEffects"
        static let defaultSortKey = "defaultSortKey"
        /// 一人回しで、山札を上から見る枚数（3・4・5）。最後に選んだ枚数を覚えておく
        static let soloDeckLookCount = "soloDeckLookCount"
    }
}
