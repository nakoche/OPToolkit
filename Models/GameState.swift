//
//  GameState.swift
//  OPToolkit
//
//  対戦全体の状態。Undo/Redoでは、この値を丸ごと保存して戻す。
//  （以前 SoloPlayViewModel.swift にあった Perspective / GameState をここへ移した）
//

import Foundation

/// プレイヤーの識別と、画面の視点の両方に使う（先攻 = playerOne、後攻 = playerTwo）
/// nonisolated にしているのは、エラーメッセージ（LocalizedError）など、MainActor外の文脈でも
/// == で比較できるようにするため。（プロジェクトの既定がMainActor隔離のため、明示しないと
/// Equatableの適合までMainActor隔離になり、Swift 6モードでエラーになる）
nonisolated enum Perspective: Identifiable, Codable {
    case playerOne
    case playerTwo

    /// .sheet(item:) などで使うための識別子
    var id: Perspective { self }

    mutating func toggle() {
        self = self == .playerOne ? .playerTwo : .playerOne
    }

    var opponent: Perspective {
        self == .playerOne ? .playerTwo : .playerOne
    }
}

struct GameState: Equatable {
    /// 全体のターン数（先攻1ターン目 = 1、後攻1ターン目 = 2、…）
    var turnNumber: Int = 1
    var activePlayer: Perspective = .playerOne
    var playerOne = PlayerBoard()
    var playerTwo = PlayerBoard()

    /// 今の手番のプレイヤーにとって、何ターン目か（先攻1・後攻1・先攻2・後攻2…の順に数える）
    var activePlayerTurnCount: Int {
        (turnNumber + 1) / 2
    }

    subscript(player: Perspective) -> PlayerBoard {
        get { player == .playerOne ? playerOne : playerTwo }
        set {
            if player == .playerOne {
                playerOne = newValue
            } else {
                playerTwo = newValue
            }
        }
    }
}
