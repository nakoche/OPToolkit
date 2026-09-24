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
    }
}
