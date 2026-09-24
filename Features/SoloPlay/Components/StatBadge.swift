//
//  StatBadge.swift
//  OPToolkit
//

import SwiftUI

struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatBadge(title: "デッキ", value: "50")
}
