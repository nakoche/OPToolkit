//
//  BattleRecordRow.swift
//  OPToolkit
//
//  対戦履歴の1行。左に相手リーダーの画像、中央に名前・じゃんけん・先後・メモ、右に勝敗。
//  勝敗は色だけに頼らず、「勝／負／分」の文字も出す。
//

import SwiftUI

struct BattleRecordRow: View {
    let record: BattleRecord
    /// 相手のリーダー。カードDBの読み込み前、またはカード番号が未設定のときはnil
    let leader: Card?

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnailImage(card: leader)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(leaderTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    tag("じゃんけん\(record.janken.shortLabel)")
                    tag(record.turnOrder.label)
                }

                if !record.memo.isEmpty {
                    Text(record.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(record.result.shortLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(resultColor, in: Circle())
        }
        // 行のどこをタップしても反応するようにする（Button + .plain だと文字の上だけになりやすい）
        .contentShape(Rectangle())
    }

    /// カードDBに無い番号のときは、番号をそのまま出す
    private var leaderTitle: String {
        if let leader { return leader.name }
        return record.opponentLeaderNumber ?? "リーダー未設定"
    }

    private var resultColor: Color {
        switch record.result {
        case .win: return .blue
        case .lose: return .red
        case .draw: return .gray
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(uiColor: .systemGray5), in: Capsule())
    }
}

#Preview {
    List {
        BattleRecordRow(
            record: BattleRecord(
                deckID: UUID(),
                opponentLeaderNumber: Card.sampleLuffy.cardNumber,
                janken: .win,
                turnOrder: .first,
                result: .win,
                memo: "後半のカウンターが効いた"
            ),
            leader: .sampleLuffy
        )
        BattleRecordRow(
            record: BattleRecord(deckID: UUID(), janken: .lose, turnOrder: .second, result: .lose),
            leader: nil
        )
    }
}
