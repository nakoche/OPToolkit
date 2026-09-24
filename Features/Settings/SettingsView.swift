//
//  SettingsView.swift
//  OPToolkit
//
//  ④設定画面。@AppStorageで即時反映・永続化し、
//  enum変換はSettingsViewModelに委譲する。
//

import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel

    @AppStorage(SettingsStore.Key.colorScheme) private var colorSchemeRawValue: String = AppColorScheme.system.rawValue
    @AppStorage(SettingsStore.Key.enableSoundEffects) private var enableSoundEffects: Bool = true
    @AppStorage(SettingsStore.Key.defaultSortKey) private var defaultSortKeyRawValue: String = CardSortKey.name.rawValue

    private var selectedColorScheme: Binding<AppColorScheme> {
        Binding(
            get: { viewModel.colorScheme(from: colorSchemeRawValue) },
            set: { colorSchemeRawValue = $0.rawValue }
        )
    }

    private var defaultSortKey: Binding<CardSortKey> {
        Binding(
            get: { viewModel.sortKey(from: defaultSortKeyRawValue) },
            set: { defaultSortKeyRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("表示") {
                    Picker("画面モード", selection: selectedColorScheme) {
                        ForEach(AppColorScheme.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("カードリスト") {
                    Picker("デフォルトの並び順", selection: defaultSortKey) {
                        ForEach(CardSortKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                }

                Section("一人回し") {
                    Toggle("効果音", isOn: $enableSoundEffects)
                }

                Section {
                    LabeledContent("バージョン", value: viewModel.appVersion)
                    Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
                    Link("利用規約", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
