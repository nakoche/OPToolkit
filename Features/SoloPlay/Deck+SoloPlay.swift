//
//  Deck+SoloPlay.swift
//  OPToolkit
//
//  一人回しで使えるデッキかどうかの判定。
//

import Foundation

extension Card {
    /// 一人回しの開始画面・マリガン画面で見せる、スタート時のライフの枚数。
    /// ライフはリーダーのライフ値の枚数で始まる。cards.jsonにライフ値が無い（古い）ときだけ、5枚で始める。
    var soloPlayStartingLifeText: String {
        if let life {
            return "ライフ \(life)"
        }
        return "ライフ不明（\(PlayerBoard.defaultLife)枚で開始）"
    }
}

extension Deck {
    /// 一人回しで使うデッキ本体の枚数（リーダーを除く）
    static let soloPlayRequiredSize = 50

    /// 一人回しで使えるデッキか（リーダーが設定済みで、デッキ本体がちょうど50枚）
    var isReadyForBattle: Bool {
        leaderCard != nil && totalCardCount == Deck.soloPlayRequiredSize
    }
}
