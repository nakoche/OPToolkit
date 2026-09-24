//
//  DeckCreationView.swift
//  OPToolkit
//

import SwiftUI

struct DeckCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deckName = ""

    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("デッキ名") {
                    TextField("例: 赤ルフィ", text: $deckName)
                }
                // TODO: リーダー選択・カード選択UIを追加
                // （CardListViewを再利用してカードをタップで追加、などが自然）
            }
            .navigationTitle("デッキ作成")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        onCreate(deckName)
                        dismiss()
                    }
                }
            }
        }
    }
}
