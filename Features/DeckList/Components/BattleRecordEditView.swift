//
//  BattleRecordEditView.swift
//  OPToolkit
//
//  対戦記録の追加・編集画面（BattleHistoryViewから.fullScreenCoverで開く）。
//  - 大会名: 自由入力。入力欄の右のメニューから、過去に使った大会名を選べる。
//  - 相手のリーダー: タップするとLeaderSelectViewを開いて選ぶ（選択を外すこともできる）。
//  - じゃんけん・先後・勝敗: セグメントで選ぶ。
//  - メモ: 複数行。
//  どの項目も必須にしていない（対戦中に素早く残せるように）。
//

import SwiftUI

struct BattleRecordEditView: View {
    let isNew: Bool
    /// 大会名の選択肢（過去に使った大会名）
    let tournamentNames: [String]
    let onSave: (BattleRecord) -> Void
    let onCancel: () -> Void

    @State private var draft: BattleRecord
    @State private var opponentLeader: Card?
    @State private var isSelectingLeader = false

    init(
        record: BattleRecord,
        isNew: Bool,
        opponentLeader: Card?,
        tournamentNames: [String],
        onSave: @escaping (BattleRecord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isNew = isNew
        self.tournamentNames = tournamentNames
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: record)
        _opponentLeader = State(initialValue: opponentLeader)
    }

    var body: some View {
        NavigationStack {
            Form {
                tournamentSection
                leaderSection

                Section("じゃんけん") {
                    Picker("じゃんけん", selection: $draft.janken) {
                        ForEach(JankenResult.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("先攻・後攻") {
                    Picker("先攻・後攻", selection: $draft.turnOrder) {
                        ForEach(TurnOrder.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("勝敗") {
                    Picker("勝敗", selection: $draft.result) {
                        ForEach(MatchResult.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("メモ") {
                    TextField("対戦の振り返りなど", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(isNew ? "対戦を記録" : "対戦を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { onSave(draft) }
                        .fontWeight(.semibold)
                }
            }
            // 相手リーダーの選択（既存のリーダー選択画面をそのまま使う）
            .fullScreenCover(isPresented: $isSelectingLeader) {
                LeaderSelectView(
                    viewModel: LeaderSelectViewModel(),
                    onSelect: { card in
                        opponentLeader = card
                        draft.opponentLeaderNumber = card.cardNumber
                        isSelectingLeader = false
                    },
                    onCancel: { isSelectingLeader = false }
                )
            }
        }
    }

    // MARK: - 大会名

    private var tournamentSection: some View {
        Section {
            HStack {
                TextField("大会名（空欄なら「大会名なし」）", text: $draft.tournamentName)

                if !tournamentNames.isEmpty {
                    Menu {
                        ForEach(tournamentNames, id: \.self) { name in
                            Button(name) { draft.tournamentName = name }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("過去の大会名から選ぶ")
                }
            }
        } header: {
            Text("大会名")
        } footer: {
            if !tournamentNames.isEmpty {
                Text("右のボタンから、過去に使った大会名を選べます")
            }
        }
    }

    // MARK: - 相手のリーダー

    private var leaderSection: some View {
        Section("対戦相手のリーダー") {
            Button {
                isSelectingLeader = true
            } label: {
                HStack(spacing: 12) {
                    CardThumbnailImage(card: opponentLeader)
                        .frame(width: 44)

                    Text(leaderTitle)
                        .foregroundStyle(opponentLeader == nil && draft.opponentLeaderNumber == nil ? .secondary : .primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if draft.opponentLeaderNumber != nil {
                Button("リーダーの選択を外す", role: .destructive) {
                    opponentLeader = nil
                    draft.opponentLeaderNumber = nil
                }
            }
        }
    }

    /// カードDBに無い番号が保存されているときは、番号をそのまま出す
    private var leaderTitle: String {
        if let opponentLeader { return opponentLeader.name }
        return draft.opponentLeaderNumber ?? "リーダーを選択"
    }
}

#Preview {
    BattleRecordEditView(
        record: BattleRecord(deckID: UUID(), tournamentName: "店舗大会 10月"),
        isNew: true,
        opponentLeader: nil,
        tournamentNames: ["店舗大会 10月", "フラッグシップ予選"],
        onSave: { _ in },
        onCancel: {}
    )
}
