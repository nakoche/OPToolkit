//
//  CardInstance.swift
//  OPToolkit
//
//  盤面上の「カード1枚」。
//  Cardはカード番号がそのままIDなので、同じカードを複数枚入れたデッキでは1枚ずつを区別できない
//  （ForEachでID重複になる）。そこで1枚ごとにUUIDを振り、
//  レスト・付与ドンの枚数・表裏・パワーとコストの増減もここで持つ。
//

import Foundation

struct CardInstance: Identifiable, Equatable, Hashable {
    let id: UUID
    let card: Card
    /// レスト状態（リーダー・キャラ・ステージで使う）
    var isRested: Bool
    /// 表向きか。山札とライフに置かれているときだけ裏向き（false）になる
    var isFaceUp: Bool
    /// このカードに付与されているドンの枚数（リーダー・キャラのみ）
    var attachedDon: Int
    /// 効果などによるパワーの増減（+1000、-2000など）。場を離れるとリセットされる。
    /// パワーは0を下回ってマイナスになってもよい。
    /// ドン付与による+1000は含めない（ドン付与分は、持ち主の手番中だけ表示側で加算する）
    var powerModifier: Int
    /// 効果などによるコストの増減。場を離れるとリセットされる
    var costModifier: Int

    init(
        card: Card,
        id: UUID = UUID(),
        isRested: Bool = false,
        isFaceUp: Bool = true,
        attachedDon: Int = 0,
        powerModifier: Int = 0,
        costModifier: Int = 0
    ) {
        self.id = id
        self.card = card
        self.isRested = isRested
        self.isFaceUp = isFaceUp
        self.attachedDon = attachedDon
        self.powerModifier = powerModifier
        self.costModifier = costModifier
    }

    /// 増減を加えたパワー（ドン付与分は含めない）。マイナスになることもある。
    /// パワーが取れていないカード（0のキャラなど）は0として扱う
    var effectivePower: Int {
        (card.power ?? 0) + powerModifier
    }

    /// 増減を加えたコスト
    var effectiveCost: Int {
        max(card.cost + costModifier, 0)
    }

    /// コストが0を下回らないよう、増減の値を補正する
    /// （0未満まで下げたあとに、戻すための操作が余分に必要にならないようにするため）。
    /// パワーはマイナスまで下げられるので、補正しない。
    mutating func clampModifiers() {
        costModifier = max(costModifier, -card.cost)
    }

    var hasModifiers: Bool {
        powerModifier != 0 || costModifier != 0
    }
}
