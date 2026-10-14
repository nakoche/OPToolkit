//
//  SoloPlayViewModel.swift
//  OPToolkit
//
//  一人回し（デジタルテーブルトップ）の状態と操作を管理する。
//  カード効果は反映せず、カードを自由に動かせることを目的にしている。
//  盤面を変える操作はすべて apply 経由にして、Undo/Redo の対象にする。
//
//  進行: デッキ選択 → マリガン（先攻→後攻）→ 対戦中
//  マリガンまでの準備は Undo の対象外（対戦中になった時点で履歴は空）。
//
//  デッキ一覧はデッキ画面と同じ DeckStore から読む（RootView で同じインスタンスを渡す）。
//

import Foundation

/// 一人回しの進行段階
enum SoloPlayPhase: Equatable {
    /// デッキ選択画面（対戦前）
    case deckSelection
    /// 指定プレイヤーが、手札を引き直すか選んでいる
    case mulligan(Perspective)
    /// 対戦中
    case playing
}

/// 詳細表示しているカード。増減などの操作に使うため、持ち主と盤面上のidも持つ
struct SoloDetailTarget: Equatable {
    let owner: Perspective
    let instanceID: UUID
    let card: Card
}

/// 盤面の上に開く確認パネル（どちらも、対象のプレイヤーを持つ）
enum SoloPanel: Equatable {
    /// 山札を上から見る（サーチ）
    case deck(Perspective)
    /// トラッシュの一覧
    case trash(Perspective)
}

nonisolated enum SoloPlayError: LocalizedError {
    case leaderNotSet(Perspective)

    var errorDescription: String? {
        switch self {
        case .leaderNotSet(let player):
            let name = player == .playerOne ? "先攻" : "後攻"
            return "\(name)のデッキにリーダーが設定されていません。"
        }
    }
}

@Observable
final class SoloPlayViewModel {
    private(set) var current = GameState()
    private(set) var phase: SoloPlayPhase = .deckSelection

    // MARK: デッキ選択

    private let deckStore: DeckStoreProtocol
    /// 選べるデッキの一覧（デッキ画面に登録されているもの）
    private(set) var availableDecks: [Deck] = []
    private(set) var selectedDeckOne: Deck?
    private(set) var selectedDeckTwo: Deck?
    /// バトル開始に失敗したときのアラート表示用
    var startErrorMessage: String?

    init(deckStore: DeckStoreProtocol) {
        self.deckStore = deckStore
    }

    private var undoStack: [GameState] = []
    private var redoStack: [GameState] = []
    /// 履歴が増え続けてメモリを使いすぎないようにする上限
    private static let maxUndoCount = 300

    /// 「バトルをやり直す」用に、直近の対戦で使った2つのデッキを覚えておく
    private struct BattleDecks {
        let playerOne: Deck
        let playerTwo: Deck
    }
    private var lastDecks: BattleDecks?

    /// 画面で「手前（自分側）」として見ているプレイヤー
    var perspective: Perspective = .playerOne
    var isMenuPresented = false

    /// 詳細表示中のカード（nilなら出ていない）。画面全体に重ねて表示する
    var detailTarget: SoloDetailTarget?

    /// 詳細モード中か（操作バーの「詳細」ボタンを押したあと、カードをタップするまで true）
    var isDetailMode = false

    /// 山札・ライフにカードをドロップしたあと、「上に置く／下に置く」の選択待ちのもの
    var pendingPlacement: SoloPendingPlacement?

    /// 開いている確認パネル（山札・トラッシュ）。nilなら閉じている
    var activePanel: SoloPanel?

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var visibleBoard: PlayerBoard { current[perspective] }
    var opponentBoard: PlayerBoard { current[perspective.opponent] }

    // MARK: - デッキ選択

    /// 画面表示時に呼ぶ。保存済みデッキをカードDBと突き合わせて復元し、一覧を最新にする
    @MainActor
    func loadDecks() async {
        await deckStore.prepare()
        refreshDecks()
    }

    /// デッキ一覧を最新にする。選択済みのデッキも、編集・削除されていれば反映する
    func refreshDecks() {
        availableDecks = deckStore.fetchAll()
        selectedDeckOne = latest(of: selectedDeckOne)
        selectedDeckTwo = latest(of: selectedDeckTwo)
    }

    /// 選択済みのデッキを最新の内容にする。削除された、または編集で条件（リーダー設定済み・50枚）を
    /// 満たさなくなったデッキは、選択を外す。
    private func latest(of deck: Deck?) -> Deck? {
        guard let deck else { return nil }
        return availableDecks.first { $0.id == deck.id && $0.isReadyForBattle }
    }

    func selectedDeck(for player: Perspective) -> Deck? {
        player == .playerOne ? selectedDeckOne : selectedDeckTwo
    }

    func selectDeck(_ deck: Deck, for player: Perspective) {
        if player == .playerOne {
            selectedDeckOne = deck
        } else {
            selectedDeckTwo = deck
        }
    }

    /// 両方のデッキが選ばれていて、どちらも対戦に使える（リーダー設定済み・50枚）か
    var canStartBattle: Bool {
        (selectedDeckOne?.isReadyForBattle ?? false) && (selectedDeckTwo?.isReadyForBattle ?? false)
    }

    /// 選んだ2つのデッキでバトルを始める（マリガン選択へ進む）
    func startBattleWithSelectedDecks() {
        guard let one = selectedDeckOne, let two = selectedDeckTwo else { return }
        startErrorMessage = nil
        do {
            try startBattle(playerOneDeck: one, playerTwoDeck: two)
        } catch {
            startErrorMessage = error.localizedDescription
        }
    }

    // MARK: - 対戦の開始・終了

    /// 2つのデッキで対戦を始める。山札をシャッフルして5枚引き、先攻のマリガン選択へ進む。
    func startBattle(playerOneDeck: Deck, playerTwoDeck: Deck) throws {
        guard var one = PlayerBoard(from: playerOneDeck) else { throw SoloPlayError.leaderNotSet(.playerOne) }
        guard var two = PlayerBoard(from: playerTwoDeck) else { throw SoloPlayError.leaderNotSet(.playerTwo) }

        one.shuffleDeck()
        one.drawInitialHand()
        two.shuffleDeck()
        two.drawInitialHand()

        var state = GameState()
        state.playerOne = one
        state.playerTwo = two

        lastDecks = BattleDecks(playerOne: playerOneDeck, playerTwo: playerTwoDeck)
        detailTarget = nil
        isDetailMode = false
        pendingPlacement = nil
        activePanel = nil
        current = state
        undoStack.removeAll()
        redoStack.removeAll()
        perspective = .playerOne      // 先攻の手札を見せる
        phase = .mulligan(.playerOne)
    }

    /// 手札を山札に戻してシャッフルし、5枚引き直す。何回でも繰り返せる（次へ進まない）。
    func redrawMulliganHand() {
        guard case .mulligan(let player) = phase else { return }
        current[player].mulligan()
    }

    /// 今の手札で確定する。先攻 → 後攻の順に呼ばれ、後攻が確定すると対戦が始まる。
    func confirmMulligan() {
        guard case .mulligan(let player) = phase else { return }

        switch player {
        case .playerOne:
            phase = .mulligan(.playerTwo)
            perspective = .playerTwo  // 後攻の手札を見せる
        case .playerTwo:
            finishSetup()
        }
    }

    /// ライフを置き、先攻の1ターン目を始める（ドローなし、ドン!!は1枚）
    private func finishSetup() {
        current.playerOne.placeInitialLife()
        current.playerTwo.placeInitialLife()

        current.turnNumber = 1
        current.activePlayer = .playerOne
        current.playerOne.addDon(1)

        undoStack.removeAll()
        redoStack.removeAll()
        perspective = .playerOne
        phase = .playing
    }

    /// バトルを終了してデッキ選択に戻る（選んでいたデッキはそのまま残す）
    func endBattle() {
        current = GameState()
        undoStack.removeAll()
        redoStack.removeAll()
        lastDecks = nil
        perspective = .playerOne
        detailTarget = nil
        isDetailMode = false
        pendingPlacement = nil
        activePanel = nil
        phase = .deckSelection
    }

    /// 同じデッキでバトルをやり直す（シャッフルし直してマリガンから）
    func restartBattle() {
        guard let decks = lastDecks else {
            endBattle()
            return
        }
        do {
            try startBattle(playerOneDeck: decks.playerOne, playerTwoDeck: decks.playerTwo)
        } catch {
            endBattle()
        }
    }

    // MARK: - Undo / Redo

    /// 盤面を変える操作の共通入口。操作が成功して実際に盤面が変わったときだけ履歴に積む
    /// （置けない場所へのドロップなどが、Undo履歴に空の1手として残らないようにするため）。
    @discardableResult
    private func apply(_ mutate: (inout GameState) -> Bool) -> Bool {
        guard phase == .playing else { return false }

        var next = current
        guard mutate(&next), next != current else { return false }

        undoStack.append(current)
        if undoStack.count > Self.maxUndoCount {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        current = next
        return true
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(current)
        let activePlayerBefore = current.activePlayer
        current = previous
        // ターン終了を取り消したときは、視点も前の手番側に戻す
        if previous.activePlayer != activePlayerBefore {
            perspective = previous.activePlayer
        }
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(current)
        let activePlayerBefore = current.activePlayer
        current = next
        if next.activePlayer != activePlayerBefore {
            perspective = next.activePlayer
        }
    }

    // MARK: - 盤面の操作（戻り値は「実際に変わったか」。ドロップ拒否の触覚フィードバック等に使う）

    /// カードを動かす。owner は、そのカードの持ち主
    @discardableResult
    func moveCard(
        _ id: UUID,
        owner: Perspective,
        to zone: BoardZone,
        position: ZonePosition = .bottom
    ) -> Bool {
        apply { $0[owner].move(id, to: zone, position: position) }
    }

    /// 複数のカードを、同じゾーンへ順番どおりに動かす（Undoは1回分）。
    /// 山札の「残りをすべてデッキの下へ」のように、まとめて送るときに使う。
    @discardableResult
    func moveCards(
        _ ids: [UUID],
        owner: Perspective,
        to zone: BoardZone,
        position: ZonePosition = .bottom
    ) -> Bool {
        apply { state in
            var movedAny = false
            for id in ids {
                if state[owner].move(id, to: zone, position: position) {
                    movedAny = true
                }
            }
            return movedAny
        }
    }

    /// リーダー・キャラのパワーを増減する（詳細画面から）
    @discardableResult
    func adjustPower(_ id: UUID, owner: Perspective, by delta: Int) -> Bool {
        apply { $0[owner].adjustPower(id, by: delta) }
    }

    /// キャラのコストを増減する（詳細画面から）
    @discardableResult
    func adjustCost(_ id: UUID, owner: Perspective, by delta: Int) -> Bool {
        apply { $0[owner].adjustCost(id, by: delta) }
    }

    /// パワー・コストの増減を元に戻す（詳細画面から）
    @discardableResult
    func resetModifiers(_ id: UUID, owner: Perspective) -> Bool {
        apply { $0[owner].resetModifiers(id) }
    }

    /// リーダー・キャラ・ステージのレスト⇄アクティブ
    @discardableResult
    func toggleRest(_ id: UUID, owner: Perspective) -> Bool {
        apply { $0[owner].toggleRest(id) }
    }

    /// ライフのカードの表⇄裏
    @discardableResult
    func flipLifeCard(_ id: UUID, owner: Perspective) -> Bool {
        apply { $0[owner].flipLifeCard(id) }
    }

    /// ドンのドラッグ&ドロップ
    @discardableResult
    func moveDon(owner: Perspective, from source: DonSource, to destination: DonDestination) -> Bool {
        apply { $0[owner].moveDon(from: source, to: destination) }
    }

    /// コストエリアのドン1枚のレスト⇄アクティブ
    @discardableResult
    func toggleDon(owner: Perspective, id: UUID) -> Bool {
        apply { $0[owner].toggleDon(id) }
    }

    // MARK: - ドラッグ&ドロップ

    /// ドロップされたものを、ドロップ先に応じて処理する。受け付けたら true（拒否なら false）。
    /// 自分のカード・ドンは、自分の盤面のゾーンにしか置けない（相手の盤面へは動かせない）。
    @discardableResult
    func performDrop(_ items: [SoloDragItem], owner: Perspective, target: SoloDropTarget) -> Bool {
        guard phase == .playing, let item = items.first, item.owner == owner else { return false }

        switch (item.content, target) {
        case (.card(let id), .zone(let zone)):
            return placeCard(id, owner: owner, zone: zone)

        case (.card(let id), .cardTarget(_, let fallbackZone)):
            // カードの上に別のカードをドロップした場合は、そのカードのゾーン全体へ置く扱いにする
            guard let fallbackZone else { return false }
            return placeCard(id, owner: owner, zone: fallbackZone)

        case (.card(let id), .zoneAt(let zone, let position)):
            // 位置まで指定されているので、上/下の選択は聞かずにそのまま置く
            return moveCard(id, owner: owner, to: zone, position: position)

        case (.card(let id), .characterSlot(let slot)), (.card(let id), .characterCard(_, let slot)):
            // キャラエリアの指定スロットへ（空きなら移動、埋まっていれば入れ替え）
            return moveCard(id, owner: owner, to: .characters, position: .index(slot))

        case (.don(let source), .characterCard(let id, _)):
            return moveDon(owner: owner, from: source, to: .card(id))

        case (.card(let id), .field):
            guard let type = current[owner].instance(id)?.card.type else { return false }
            switch type {
            case .character: return moveCard(id, owner: owner, to: .characters)
            case .stage: return moveCard(id, owner: owner, to: .stage)
            default: return false
            }

        case (.don(let source), .donDeck):
            return moveDon(owner: owner, from: source, to: .donDeck)

        case (.don(let source), .costArea):
            return moveDon(owner: owner, from: source, to: .costArea)

        case (.don(let source), .cardTarget(let id, _)):
            return moveDon(owner: owner, from: source, to: .card(id))

        default:
            return false
        }
    }

    private func placeCard(_ id: UUID, owner: Perspective, zone: BoardZone) -> Bool {
        switch zone {
        case .deck, .life:
            // 上に置くか下に置くかは、ドロップのあとに選んでもらう。
            // ここでは、動かせるカード（リーダーでない）かだけ確認する。
            guard let location = current[owner].locate(id), location.zone != .leader else { return false }
            pendingPlacement = SoloPendingPlacement(owner: owner, cardID: id, zone: zone)
            return true
        default:
            return moveCard(id, owner: owner, to: zone)
        }
    }

    // MARK: - 操作バー

    /// 手前（視点側）のプレイヤーが1枚引く
    func draw() {
        let player = perspective
        apply { $0[player].draw() }
    }

    /// ターン終了。手番を交代し、次の手番側のリフレッシュ・ドロー・ドン!!2枚を自動で行い、
    /// 視点も次の手番側に切り替える。間違えたときは Undo で戻す（視点も戻る）。
    func endTurn() {
        let didEnd = apply { state in
            state.turnNumber += 1
            state.activePlayer.toggle()

            let player = state.activePlayer
            state[player].refresh()
            state[player].draw()
            state[player].addDon(2)
            return true
        }
        if didEnd {
            perspective = current.activePlayer
        }
    }

    func togglePerspective() {
        perspective.toggle()
    }
}
