//
//  BattleHistoryView.swift
//  OPToolkit
//
//  対戦履歴画面（デッキごと）。
//  - 右下の「＋」（デッキ一覧の「＋」と同じ位置・同じ見た目）で、大会名を決めて大会を作る。
//  - 大会ごとにセクションで表示する（新しい大会が上）。セクションの中は「1回戦、2回戦…」の順に並び、
//    いちばん下の「○回戦の対戦を記録」で、その大会に次の回戦を追加する（回戦は自動で入る）。
//  - 行のタップで編集、左スワイプで削除。大会名の右の「…」から、大会名の変更・大会の削除ができる。
//  - 先頭に、このデッキの通算成績を出す。
//
//  bodyにmodifierをつなげすぎるとコンパイルが終わらなくなるため（DeckListViewで経験済み）、
//  アラートはViewModifierに、編集画面の出し分けは別の関数に切り出している。
//

import SwiftUI

struct BattleHistoryView: View {
    @State var viewModel: BattleHistoryViewModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
            addTournamentButton
        }
        .navigationTitle("対戦履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadLeaders()
        }
        // 大会の作成・対戦記録の編集画面（リーダー選択などと同じく.fullScreenCoverで出す）
        .fullScreenCover(item: $viewModel.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .modifier(BattleHistoryAlerts(viewModel: viewModel))
    }

    // MARK: - 本体

    @ViewBuilder
    private var content: some View {
        let sections = viewModel.sections
        if sections.isEmpty {
            ContentUnavailableView(
                "対戦履歴",
                systemImage: "clock.arrow.circlepath",
                description: Text("「\(viewModel.deck.name)」の対戦履歴はまだありません。右下の「＋」から大会を作って、対戦を記録できます")
            )
        } else {
            tournamentList(sections)
        }
    }

    private func tournamentList(_ sections: [BattleTournamentSection]) -> some View {
        List {
            Section {
                summaryRow
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.records) { record in
                        recordRow(record, in: section.tournament)
                    }
                    addRecordButton(for: section)
                } header: {
                    tournamentHeader(for: section)
                }
            }
        }
        // 右下の「＋」ボタンに、いちばん下の行が隠れないようにする
        .contentMargins(.bottom, 90, for: .scrollContent)
    }

    // MARK: - 通算成績

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

    // MARK: - 大会のセクション

    private func tournamentHeader(for section: BattleTournamentSection) -> some View {
        HStack(spacing: 8) {
            Text(section.tournament.name)
            Spacer()
            Text(section.summary.text)
            Menu {
                Button {
                    viewModel.beginRenameTournament(section.tournament)
                } label: {
                    Label("大会名を変更", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    viewModel.requestDeleteTournament(section.tournament)
                } label: {
                    Label("大会を削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("大会の操作")
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
    }

    private func recordRow(_ record: BattleRecord, in tournament: BattleTournament) -> some View {
        Button {
            viewModel.beginEditRecord(record, in: tournament)
        } label: {
            BattleRecordRow(record: record, leader: viewModel.leader(for: record))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.requestDeleteRecord(record)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func addRecordButton(for section: BattleTournamentSection) -> some View {
        Button {
            viewModel.beginAddRecord(to: section.tournament)
        } label: {
            Label("\(section.nextRound)回戦の対戦を記録", systemImage: "plus.circle")
        }
    }

    // MARK: - 右下の「＋」ボタン（デッキ一覧の「＋」と同じ位置・同じ見た目）

    private var addTournamentButton: some View {
        Button {
            viewModel.beginAddTournament()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.indigo, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .accessibilityLabel("大会を作成")
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - 編集画面

    @ViewBuilder
    private func sheetContent(for sheet: BattleHistorySheet) -> some View {
        switch sheet {
        case .tournament(let tournament, let isNew):
            BattleTournamentEditView(
                tournament: tournament,
                isNew: isNew,
                pastNames: viewModel.tournamentNames,
                onSave: { viewModel.saveTournament($0, isNew: isNew) },
                onCancel: { viewModel.cancelEditing() }
            )
        case .record(let record, let isNew, let tournamentName):
            BattleRecordEditView(
                record: record,
                isNew: isNew,
                tournamentName: tournamentName,
                opponentLeader: viewModel.leader(for: record),
                onSave: { viewModel.saveRecord($0, isNew: isNew) },
                onCancel: { viewModel.cancelEditing() }
            )
        }
    }
}

// MARK: - アラート（削除確認・保存エラー）

private struct BattleHistoryAlerts: ViewModifier {
    let viewModel: BattleHistoryViewModel

    func body(content: Content) -> some View {
        content
            // 削除確認（デッキの削除と同じく.alert）
            .alert(
                viewModel.deletionTitle,
                isPresented: deletionBinding
            ) {
                Button("キャンセル", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("削除する", role: .destructive) {
                    viewModel.confirmDelete()
                }
            } message: {
                Text(viewModel.deletionMessage)
            }
            // 保存失敗の通知
            .alert(
                "保存できません",
                isPresented: errorBinding
            ) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeletion != nil },
            set: { if !$0 { viewModel.cancelDelete() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - プレビュー

#Preview {
    // 一時ファイルを指すストアに、サンプルの大会と記録を入れて表示する
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

/// プレビュー専用のサンプル投入（#Preview内では文を書きにくいので別に切り出している）
private enum BattleHistoryPreviewSupport {
    static func fill(_ store: BattleHistoryStore, deckID: UUID) {
        guard store.tournaments(for: deckID).isEmpty else { return }
        let leader = Card.sampleLuffy.cardNumber
        let now = Date()

        let shop = BattleTournament(deckID: deckID, name: "店舗大会 10月", createdAt: now.addingTimeInterval(-1_000))
        let free = BattleTournament(deckID: deckID, name: "フリー対戦", createdAt: now.addingTimeInterval(-100_000))
        try? store.addTournament(shop)
        try? store.addTournament(free)

        let records = [
            BattleRecord(deckID: deckID, tournamentID: shop.id, round: 1, opponentLeaderNumber: leader,
                         janken: .win, turnOrder: .first, result: .win, memo: "後半のカウンターが効いた",
                         createdAt: now.addingTimeInterval(-900)),
            BattleRecord(deckID: deckID, tournamentID: shop.id, round: 2, opponentLeaderNumber: leader,
                         janken: .lose, turnOrder: .second, result: .lose,
                         createdAt: now.addingTimeInterval(-600)),
            BattleRecord(deckID: deckID, tournamentID: free.id, round: 1,
                         result: .doubleLoss, memo: "じゃんけん・先後は記録なし",
                         createdAt: now.addingTimeInterval(-99_000)),
        ]
        for record in records {
            try? store.addRecord(record)
        }
    }
}
