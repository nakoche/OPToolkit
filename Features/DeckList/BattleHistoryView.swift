//
//  BattleHistoryView.swift
//  OPToolkit
//
//  対戦履歴画面（デッキごと）。
//  - 記録は大会名ごとにまとめて表示（グループは新しい大会が上、グループ内も新しい順）。
//    大会名が空の記録は「大会名なし」にまとまる。
//  - 右上の「＋」で記録を追加、行のタップで編集、左スワイプで削除（確認アラートあり）。
//  - 先頭に、このデッキの通算成績を出す。
//

import SwiftUI

struct BattleHistoryView: View {
    @State var viewModel: BattleHistoryViewModel

    var body: some View {
        Group {
            if viewModel.records.isEmpty {
                ContentUnavailableView(
                    "対戦履歴",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("「\(viewModel.deck.name)」の対戦履歴はまだありません。右上の「＋」から記録できます")
                )
            } else {
                recordList
            }
        }
        .navigationTitle("対戦履歴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.beginAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("対戦を記録")
            }
        }
        .task {
            await viewModel.loadLeaders()
        }
        // 追加・編集画面（リーダー選択などと同じく.fullScreenCoverで出す）
        .fullScreenCover(item: $viewModel.editorTarget) { target in
            BattleRecordEditView(
                record: target.record,
                isNew: target.isNew,
                opponentLeader: viewModel.leader(for: target.record),
                tournamentNames: viewModel.tournamentNames,
                onSave: { viewModel.save($0, isNew: target.isNew) },
                onCancel: { viewModel.cancelEditing() }
            )
        }
        // 削除確認（デッキの削除と同じく.alert）
        .alert(
            "この対戦記録を削除しますか？",
            isPresented: Binding(
                get: { viewModel.pendingDelete != nil },
                set: { if !$0 { viewModel.cancelDelete() } }
            )
        ) {
            Button("キャンセル", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("削除する", role: .destructive) {
                viewModel.confirmDelete()
            }
        } message: {
            Text("この操作は取り消せません")
        }
        // 保存失敗の通知
        .alert(
            "保存できません",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var recordList: some View {
        List {
            Section {
                summaryRow
            }

            ForEach(viewModel.groups) { group in
                Section {
                    ForEach(group.records) { record in
                        Button {
                            viewModel.beginEdit(record)
                        } label: {
                            BattleRecordRow(record: record, leader: viewModel.leader(for: record))
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.requestDelete(record)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.title)
                        Spacer()
                        Text(group.summary.text)
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
    }

    private var summaryRow: some View {
        let summary = viewModel.summary
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("「\(viewModel.deck.name)」の通算成績")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.text)
                    .font(.title3.weight(.bold))
            }
            Spacer()
            if let winRateText = summary.winRateText {
                Text(winRateText)
                    .font(.headline)
            }
        }
    }
}

#Preview {
    // 一時ファイルを指すストアに、サンプルの記録を入れて表示する
    let store = BattleHistoryStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-battle-history.json")
    )
    let deck = Deck.sample
    BattleHistoryPreviewSupport.fill(store, deckID: deck.id)

    return NavigationStack {
        BattleHistoryView(
            viewModel: BattleHistoryViewModel(
                deck: deck,
                store: store,
                cardRepository: MockCardRepository()
            )
        )
    }
}

/// プレビュー専用のサンプル記録の投入（#Preview内では文を書きにくいので別に切り出している）
private enum BattleHistoryPreviewSupport {
    static func fill(_ store: BattleHistoryStore, deckID: UUID) {
        guard store.records(for: deckID).isEmpty else { return }
        let leader = Card.sampleLuffy.cardNumber
        let now = Date()
        let samples = [
            BattleRecord(deckID: deckID, tournamentName: "店舗大会 10月", opponentLeaderNumber: leader,
                         janken: .win, turnOrder: .first, result: .win, memo: "後半のカウンターが効いた",
                         createdAt: now.addingTimeInterval(-300)),
            BattleRecord(deckID: deckID, tournamentName: "店舗大会 10月", opponentLeaderNumber: leader,
                         janken: .lose, turnOrder: .second, result: .lose,
                         createdAt: now.addingTimeInterval(-200)),
            BattleRecord(deckID: deckID, opponentLeaderNumber: nil,
                         janken: .win, turnOrder: .first, result: .draw, memo: "フリー対戦",
                         createdAt: now.addingTimeInterval(-100_000)),
        ]
        for record in samples {
            try? store.add(record)
        }
    }
}
