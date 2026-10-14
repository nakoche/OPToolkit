//
//  SoloDeckPickerSheet.swift
//  OPToolkit
//
//  一人回しの開始画面で、デッキ一覧から1つ選ぶシート。
//  リーダー未設定のデッキと、50枚でないデッキは選べない（灰色表示で理由を出す）。
//

import SwiftUI

struct SoloDeckPickerSheet: View {
    let title: String
    let decks: [Deck]
    let selectedDeckID: UUID?
    let onSelect: (Deck) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    ContentUnavailableView(
                        "デッキがありません",
                        systemImage: "square.stack.3d.up",
                        description: Text("先にデッキ画面でデッキを作成してください")
                    )
                } else {
                    List(decks) { deck in
                        Button {
                            onSelect(deck)
                        } label: {
                            row(for: deck)
                        }
                        .buttonStyle(.plain)
                        .disabled(!deck.isReadyForBattle)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
            }
        }
    }

    private func row(for deck: Deck) -> some View {
        HStack(spacing: 12) {
            CardThumbnailImage(card: deck.leaderCard, cornerRadius: 4)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                status(for: deck)
            }

            Spacer()

            if deck.id == selectedDeckID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .opacity(deck.isReadyForBattle ? 1 : 0.5)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func status(for deck: Deck) -> some View {
        if deck.leaderCard == nil {
            Text("リーダー未設定")
                .font(.caption)
                .foregroundStyle(.red)
        } else if deck.totalCardCount != Deck.soloPlayRequiredSize {
            Text("カード枚数 \(deck.totalCardCount)/\(Deck.soloPlayRequiredSize)（50枚のデッキのみ選べます）")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Text("\(deck.leaderCard?.name ?? "") ／ \(Deck.soloPlayRequiredSize)枚")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SoloDeckPickerSheet(
        title: "先攻のデッキを選択",
        decks: [.sample, Deck(name: "リーダー未設定"), Deck(name: "未完成", leaderCard: .sampleLuffy)],
        selectedDeckID: Deck.sample.id,
        onSelect: { _ in },
        onCancel: {}
    )
}
