//
//  SoloDragItem.swift
//  OPToolkit
//
//  一人回しのドラッグ&ドロップで使う型をまとめたファイル。
//  - SoloDragItem  : ドラッグで運ぶ中身（誰の・どのカード/ドンか）
//  - SoloDropTarget: ドロップ先の種類
//  - SoloPendingPlacement: 山札・ライフへのドロップ後の「上/下」選択待ち
//  - SoloHaptics   : ドロップ成功/拒否の触覚フィードバック
//
//  ドラッグの中身は、アプリ内のドラッグ&ドロップ用にJSONで運ぶ。
//  MainActor外でも使われる型（Transferable）なので、nonisolated にしている。
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// ドラッグしているもの
nonisolated enum SoloDragContent: Codable, Hashable {
    /// 盤面のカード1枚（CardInstanceのid）
    case card(UUID)
    /// ドン（どこから取るか）
    case don(DonSource)
}

/// ドラッグで運ぶ中身。owner は持ち主（自分のものは自分の盤面にしか置けないようにするため）
nonisolated struct SoloDragItem: Codable, Transferable {
    let owner: Perspective
    let content: SoloDragContent

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// ドロップ先の種類
enum SoloDropTarget {
    /// カードを置くゾーン
    case zone(BoardZone)
    /// カードを置くゾーンと、その中の位置（山札の上/下、ライフの上など）を指定する
    case zoneAt(BoardZone, ZonePosition)
    /// 場に出す（キャラならキャラエリア、ステージならステージへ。それ以外は受け付けない）
    case field
    /// キャラエリアの空きスロット（カードのみ。ドンは受け付けない）
    case characterSlot(Int)
    /// キャラエリアの埋まっているスロット。ドンなら付与、カードならそのスロットへ（入れ替え）
    case characterCard(id: UUID, slot: Int)
    /// ドンデッキ
    case donDeck
    /// コストエリア
    case costArea
    /// 盤面のカード1枚の上。ドンなら付与、カードなら fallbackZone へ置く（nilなら受け付けない）
    case cardTarget(id: UUID, fallbackZone: BoardZone?)
}

/// 山札・ライフにカードをドロップしたあと、「上/下」の選択待ちになっているもの
struct SoloPendingPlacement: Equatable {
    let owner: Perspective
    let cardID: UUID
    let zone: BoardZone
}

enum SoloHaptics {
    static func dropped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func rejected() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
