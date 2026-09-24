//
//  RootView.swift
//  OPToolkit
//
//  4画面をTabViewでまとめるルート。
//  設定画面で選んだ画面モード（ライト/ダーク/システム）をアプリ全体に反映する。
//

import SwiftUI

struct RootView: View {
    @AppStorage(SettingsStore.Key.colorScheme) private var colorSchemeRawValue: String = AppColorScheme.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        (AppColorScheme(rawValue: colorSchemeRawValue) ?? .system).colorScheme
    }

    var body: some View {
        TabView {
            CardListView(viewModel: CardListViewModel())
                .tabItem { Label("カード", systemImage: "rectangle.stack") }

            DeckListView(viewModel: DeckListViewModel())
                .tabItem { Label("デッキ", systemImage: "square.stack.3d.up") }

            SoloPlayView(viewModel: SoloPlayViewModel())
                .tabItem { Label("一人回し", systemImage: "gamecontroller") }

            SettingsView(viewModel: SettingsViewModel())
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    RootView()
}
