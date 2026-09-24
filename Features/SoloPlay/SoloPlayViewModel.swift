//
//  SoloPlayViewModel.swift
//  OPToolkit
//
//  盤面状態とその履歴（Undo/Redo）を管理する。カード効果は反映しない。
//

import Foundation

enum Perspective {
    case playerOne
    case playerTwo

    mutating func toggle() {
        self = self == .playerOne ? .playerTwo : .playerOne
    }
}

/// 1人分の盤面（デッキ・手札・場・ライフ等）
/// TODO: ワンピースカードの実際の盤面要素（ドン、キャラエリア、ライフ等）に合わせて拡張
struct PlayerBoard: Equatable {
    var deckCount: Int = 50
    var hand: [Card] = []
    var field: [Card] = []
    var lifeCount: Int = 5
    var donCount: Int = 10
}

struct GameState: Equatable {
    var turnNumber: Int = 1
    var activePlayer: Perspective = .playerOne
    var playerOne = PlayerBoard()
    var playerTwo = PlayerBoard()
}

@Observable
final class SoloPlayViewModel {
    private(set) var current = GameState()
    private var undoStack: [GameState] = []
    private var redoStack: [GameState] = []

    var perspective: Perspective = .playerOne
    var isMenuPresented = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var visibleBoard: PlayerBoard {
        perspective == .playerOne ? current.playerOne : current.playerTwo
    }

    private func apply(_ mutate: (inout GameState) -> Void) {
        undoStack.append(current)
        redoStack.removeAll()
        var next = current
        mutate(&next)
        current = next
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(current)
        current = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(current)
        current = next
    }

    func draw() {
        apply { [perspective] state in
            switch perspective {
            case .playerOne where state.playerOne.deckCount > 0:
                state.playerOne.deckCount -= 1
                // TODO: 実カードを手札に追加する場合はここで hand.append(...)
            case .playerTwo where state.playerTwo.deckCount > 0:
                state.playerTwo.deckCount -= 1
            default:
                break
            }
        }
    }

    func endTurn() {
        apply { state in
            state.turnNumber += 1
            state.activePlayer.toggle()
        }
    }

    func togglePerspective() {
        perspective.toggle()
    }

    func resetGame() {
        apply { state in
            state = GameState()
        }
    }
}
