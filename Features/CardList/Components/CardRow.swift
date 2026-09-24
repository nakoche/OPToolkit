//
//  CardRow.swift
//  OPToolkit
//

import SwiftUI

struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.2))
                .frame(width: 44, height: 60)
                .overlay {
                    // TODO: 実画像に差し替え (card.imageName)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                Text("\(card.cardNumber) ・ \(card.color.rawValue) ・ \(card.type.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("コスト \(card.cost)")
                    .font(.caption)
                if let power = card.power {
                    Text("\(power)")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CardRow(card: .sampleLuffy)
}
