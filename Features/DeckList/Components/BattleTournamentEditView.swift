//
//  BattleTournamentEditView.swift
//  OPToolkit
//
//  大会の作成・名前変更画面（BattleHistoryViewから.fullScreenCoverで開く）。
//  - 大会名を入力する。空欄（空白だけ）のままでは保存できない。
//  - 過去に作った大会名の一覧から、タップして選ぶこともできる（デッキをまたいで共通）。
//  - 大会を作ったあとは、履歴画面のその大会の中に、対戦を1回戦から順に追加していく。
//

import SwiftUI

struct BattleTournamentEditView: View {
    let isNew: Bool
    /// 過去に作った大会名（新しい順）
    let pastNames: [String]
    let onSave: (BattleTournament) -> Void
    let onCancel: () -> Void

    @State private var draft: BattleTournament
    @FocusState private var isNameFocused: Bool

    init(
        tournament: BattleTournament,
        isNew: Bool,
        pastNames: [String],
        onSave: @escaping (BattleTournament) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isNew = isNew
        self.pastNames = pastNames
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: tournament)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("大会名") {
                    TextField("例: 店舗大会 10月", text: $draft.name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                }

                if !pastNames.isEmpty {
                    pastNamesSection
                }
            }
            .navigationTitle(isNew ? "大会を作成" : "大会名を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isNew ? "作成" : "保存") { onSave(draft) }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                // 過去の大会名があるときは、先に一覧を見せたいので、キーボードは出さない
                if pastNames.isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    private var pastNamesSection: some View {
        Section {
            ForEach(pastNames, id: \.self) { name in
                Button {
                    draft.name = name
                } label: {
                    HStack {
                        Text(name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if draft.name == name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("過去の大会名から選ぶ")
        }
    }
}

#Preview {
    BattleTournamentEditView(
        tournament: BattleTournament(deckID: UUID(), name: ""),
        isNew: true,
        pastNames: ["店舗大会 10月", "フラッグシップ予選"],
        onSave: { _ in },
        onCancel: {}
    )
}
