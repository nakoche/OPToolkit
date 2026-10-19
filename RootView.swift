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

    // bodyが再評価されるたびに作り直されないよう、各画面のViewModelはここで1回だけ保持する
    @State private var cardListViewModel: CardListViewModel
    @State private var deckListViewModel: DeckListViewModel
    @State private var soloPlayViewModel: SoloPlayViewModel
    @State private var settingsViewModel = SettingsViewModel()

    init() {
        // お気に入り（♡）の保存先（FavoritesStore）も、アプリで1つだけ作って渡す。
        // 今はカード画面だけが使うが、他の画面でも使うときに同じものを渡せるよう、ここで作っておく。
        let favoritesStore = FavoritesStore()
        _cardListViewModel = State(initialValue: CardListViewModel(favoritesStore: favoritesStore))

        // 対戦履歴の保存先（BattleHistoryStore）も、アプリで1つだけ作って渡す。
        // デッキ画面（履歴画面への遷移・デッキ削除時の履歴削除）が使う。
        let battleHistoryStore = BattleHistoryStore()

        // デッキ画面と一人回しが同じ保存先（DeckStore）を見るよう、1つだけ作って渡す。
        // 別々に作ると、デッキ画面で編集した内容が一人回しに反映されなくなる。
        let deckListViewModel = DeckListViewModel(battleHistoryStore: battleHistoryStore)
        _deckListViewModel = State(initialValue: deckListViewModel)
        _soloPlayViewModel = State(initialValue: SoloPlayViewModel(deckStore: deckListViewModel.store))
    }

    private var preferredColorScheme: ColorScheme? {
        (AppColorScheme(rawValue: colorSchemeRawValue) ?? .system).colorScheme
    }

    var body: some View {
        TabView {
            CardListView(viewModel: cardListViewModel)
                .tabItem { Label("カード", systemImage: "rectangle.stack") }

            DeckListView(viewModel: deckListViewModel)
                .tabItem { Label("デッキ", systemImage: "square.stack.3d.up") }

            SoloPlayView(viewModel: soloPlayViewModel)
                .tabItem { Label("一人回し", systemImage: "gamecontroller") }

            SettingsView(viewModel: settingsViewModel)
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    RootView()
}
