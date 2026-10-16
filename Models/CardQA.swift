//
//  CardQA.swift
//  OPToolkit
//
//  カード1枚に対する公式Q&Aの1件。qa.jsonの1項目に対応する。
//  Cardには持たせず、カード番号をキーにした別ファイル（qa.json）から引く
//  （Cardに項目を足すと、Codable・fetch_cards.py・cards.jsonの再生成が連動してしまうため）。
//

import Foundation

/// Task.detached内（MainActorの外）でデコードするので、型ごとnonisolatedにする
nonisolated struct CardQA: Identifiable, Codable, Hashable, Sendable {
    /// 公式のQ番号（例: "Q1417"）。1枚のカードの中では重複しない
    let id: String
    /// 更新日（例: "2026-08-21"）。公式のHTMLに無ければnil
    let date: String?
    let question: String
    let answer: String

    /// 画面に出す更新日（"2026-08-21" → "2026.08.21"）。公式サイトの表記に合わせている
    var displayDate: String? {
        date?.replacingOccurrences(of: "-", with: ".")
    }
}

// MARK: - サンプルデータ（プレビュー用）

extension CardQA {
    static let samples: [CardQA] = [
        CardQA(
            id: "Q0001",
            date: "2026-08-21",
            question: "自分の手札が0枚のとき、この【相手のアタック時】効果で自分のリーダーかキャラ1枚までを、このバトル中パワー+4000することはできますか？",
            answer: "いいえ、できません。"
        ),
        CardQA(
            id: "Q0002",
            date: "2026-08-21",
            question: "この【登場時】効果で、【トリガー】効果は持たず、効果内に「【トリガー】を持つカード1枚を～」などと記載されている相手のキャラ1枚を、手札に戻すことはできますか？",
            answer: "いいえ、できません。\nこの効果は、カードの効果欄の下に「【トリガー】」から始まる【トリガー】効果そのものを持つキャラを手札に戻す効果です。"
        ),
        CardQA(
            id: "Q0003",
            date: nil,
            question: "更新日が無いQ&Aの表示確認用です。",
            answer: "更新日の行は出ません。"
        )
    ]
}
