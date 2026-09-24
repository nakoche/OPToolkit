//
//  String+Search.swift
//  OPToolkit
//
//  検索時にひらがな/カタカナを区別しないための正規化。
//  カタカナをひらがなに寄せてから比較することで、
//  「ぞろ」で検索しても「ゾロ」がヒットするようにする。
//

import Foundation

extension String {
    /// カタカナをひらがなに変換した正規化済み文字列（検索比較専用）
    private var hiraganaNormalized: String {
        applyingTransform(.hiraganaToKatakana, reverse: true) ?? self
    }

    /// selfがqueryを含むかどうかを、ひらがな/カタカナを区別せず、大文字小文字も無視して判定する
    func matchesSearch(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return hiraganaNormalized.localizedCaseInsensitiveContains(query.hiraganaNormalized)
    }
}
