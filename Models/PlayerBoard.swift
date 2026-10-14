//
//  PlayerBoard.swift
//  OPToolkit
//
//  1人分の盤面。デジタルテーブルトップとして「カードを自由に動かせる」ことが目的なので、
//  カード効果やターン進行のルールは持たない。守らせるのは次の2つだけ。
//   - キャラクターエリアは5体まで（5つのスロット。満杯なら置けない。先に1体をトラッシュ等へ移す）。
//     空いているスロットへ自由に動かせて、埋まっているスロットへ動かすと入れ替わる
//   - ステージは1枚まで（置き済みなら置けない）
//  ほかのゾーンは何でも置ける。
//
//  並びの向き:
//   - deck / life : 先頭(index 0)が「一番上」
//   - trash       : 先頭が「一番新しく落ちたカード」（落ちた順の降順）
//

import Foundation

// MARK: - ゾーン・位置

enum BoardZone: Hashable {
    case leader
    case characters
    case stage
    case hand
    case deck
    case life
    case trash
}

/// ゾーンの中のどこに入れるか
enum ZonePosition: Equatable {
    case top
    case bottom
    case index(Int)

    func resolvedIndex(count: Int) -> Int {
        switch self {
        case .top: return 0
        case .bottom: return count
        case .index(let value): return min(max(value, 0), count)
        }
    }
}

struct ZoneLocation: Equatable {
    let zone: BoardZone
    let index: Int
}

// MARK: - ドン

/// コストエリアにあるドン1枚。1枚ずつ独立して、レスト/アクティブを切り替えたり、ドラッグしたりできる
struct DonCard: Identifiable, Equatable, Hashable {
    let id: UUID
    var isRested: Bool

    init(id: UUID = UUID(), isRested: Bool = false) {
        self.id = id
        self.isRested = isRested
    }
}

/// ドラッグ元（ドラッグ&ドロップで運ぶため、Codable・nonisolated にしている）
nonisolated enum DonSource: Hashable, Codable {
    case donDeck
    /// コストエリアのドン1枚（DonCardのid）
    case cost(UUID)
    /// カードに付与されているドン（カードのid）
    case attached(UUID)
}

/// ドロップ先
enum DonDestination: Hashable {
    case donDeck
    case costArea
    /// 付与先のカード（リーダーまたはキャラのid）
    case card(UUID)
}

// MARK: - 盤面

struct PlayerBoard: Equatable {
    static let maxCharacters = 5
    static let initialHandCount = 5
    /// リーダーのライフ値が不明（cards.jsonが古い等）のときの枚数
    static let defaultLife = 5
    static let totalDon = 10

    var leader: CardInstance?
    /// キャラクターエリアの5つのスロット。nilは空き
    var characterSlots: [CardInstance?] = Array(repeating: nil, count: PlayerBoard.maxCharacters)
    var stage: CardInstance?
    var hand: [CardInstance] = []
    var deck: [CardInstance] = []
    var life: [CardInstance] = []
    var trash: [CardInstance] = []

    /// ドンデッキの残り枚数（山札と同じく、中身は区別しないので枚数だけ持つ）
    var donDeck: Int = PlayerBoard.totalDon
    /// コストエリアのドン（1枚ずつ。並びは、出した順）
    var costDon: [DonCard] = []

    var deckCount: Int { deck.count }
    var lifeCount: Int { life.count }
    /// コストエリアのドンの枚数（アクティブ + レスト）
    var donCount: Int { costDon.count }
    var donActive: Int { costDon.filter { !$0.isRested }.count }
    var donRested: Int { costDon.filter { $0.isRested }.count }

    /// 場にいるキャラ（空きスロットは除く）。枚数の確認や、読み取り用
    var characters: [CardInstance] { characterSlots.compactMap { $0 } }

    // MARK: 検索

    func locate(_ id: UUID) -> ZoneLocation? {
        if leader?.id == id { return ZoneLocation(zone: .leader, index: 0) }
        if let i = characterSlots.firstIndex(where: { $0?.id == id }) { return ZoneLocation(zone: .characters, index: i) }
        if stage?.id == id { return ZoneLocation(zone: .stage, index: 0) }
        if let i = hand.firstIndex(where: { $0.id == id }) { return ZoneLocation(zone: .hand, index: i) }
        if let i = deck.firstIndex(where: { $0.id == id }) { return ZoneLocation(zone: .deck, index: i) }
        if let i = life.firstIndex(where: { $0.id == id }) { return ZoneLocation(zone: .life, index: i) }
        if let i = trash.firstIndex(where: { $0.id == id }) { return ZoneLocation(zone: .trash, index: i) }
        return nil
    }

    func instance(at location: ZoneLocation) -> CardInstance? {
        switch location.zone {
        case .leader: return leader
        case .characters: return characterSlots[location.index]
        case .stage: return stage
        case .hand: return hand[location.index]
        case .deck: return deck[location.index]
        case .life: return life[location.index]
        case .trash: return trash[location.index]
        }
    }

    func instance(_ id: UUID) -> CardInstance? {
        guard let location = locate(id) else { return nil }
        return instance(at: location)
    }

    // MARK: カードの移動

    /// このゾーンにカードを置けるか。
    /// `source` は今いるゾーン。同じゾーン内での並べ替えなら上限チェックの対象外にする。
    func canPlace(_ card: Card, in zone: BoardZone, from source: BoardZone) -> Bool {
        let isSameZone = (source == zone)
        switch zone {
        case .leader:
            return false
        case .characters:
            return card.type == .character && (isSameZone || characters.count < PlayerBoard.maxCharacters)
        case .stage:
            return card.type == .stage && (isSameZone || stage == nil)
        case .hand, .deck, .life, .trash:
            return true
        }
    }

    /// カードを別のゾーン（または同じゾーン内の別の位置）へ動かす。置けないときは何も変えず false。
    /// - リーダーは動かせない。
    /// - トラッシュへは常に先頭（一番新しい位置）に入る（position は無視）。
    /// - ゾーンをまたぐとレスト・付与ドンはリセットされ、付与ドンはレストでコストエリアに戻る。
    @discardableResult
    mutating func move(_ id: UUID, to zone: BoardZone, position: ZonePosition = .bottom) -> Bool {
        // キャラエリアは5つのスロットで管理しているので、専用の処理にする
        // （position が .index(n) なら、n番のスロットを指定したことになる）
        if zone == .characters {
            var requestedSlot: Int?
            if case .index(let value) = position {
                requestedSlot = value
            }
            return moveCharacter(id, toSlot: requestedSlot)
        }

        guard let location = locate(id),
              location.zone != .leader,
              zone != .leader,
              let target = instance(at: location),
              canPlace(target.card, in: zone, from: location.zone),
              var moving = take(at: location)
        else { return false }

        if location.zone != zone {
            returnAttachedDon(count: moving.attachedDon)
            moving = normalized(moving, for: zone)
        }
        put(moving, into: zone, at: position)
        return true
    }

    /// キャラをキャラエリアのスロットへ動かす。
    /// - すでに場にいるキャラ: 指定スロットが空きならそこへ移動、埋まっていれば入れ替える。
    /// - ほかのゾーンから: 指定スロットが空きならそこへ。埋まっている・未指定なら、一番左の空きへ。
    /// - キャラ以外や、エリアが満杯のとき（場の中での入れ替えは除く）は置けない。
    @discardableResult
    mutating func moveCharacter(_ id: UUID, toSlot requestedSlot: Int?) -> Bool {
        guard let location = locate(id),
              location.zone != .leader,
              let target = instance(at: location),
              target.card.type == .character
        else { return false }

        if location.zone == .characters {
            guard let slot = requestedSlot, characterSlots.indices.contains(slot) else { return false }
            if slot == location.index { return true }   // 同じ場所へのドロップ。何も変えない
            characterSlots.swapAt(location.index, slot) // 空きなら移動、埋まっていれば入れ替え
            return true
        }

        let slot: Int
        if let requestedSlot,
           characterSlots.indices.contains(requestedSlot),
           characterSlots[requestedSlot] == nil {
            slot = requestedSlot
        } else if let firstEmpty = characterSlots.firstIndex(where: { $0 == nil }) {
            slot = firstEmpty
        } else {
            return false
        }

        guard var moving = take(at: location) else { return false }
        returnAttachedDon(count: moving.attachedDon)
        moving = normalized(moving, for: .characters)
        characterSlots[slot] = moving
        return true
    }

    private mutating func take(at location: ZoneLocation) -> CardInstance? {
        switch location.zone {
        case .leader:
            let value = leader
            leader = nil
            return value
        case .characters:
            let value = characterSlots[location.index]
            characterSlots[location.index] = nil
            return value
        case .stage:
            let value = stage
            stage = nil
            return value
        case .hand: return hand.remove(at: location.index)
        case .deck: return deck.remove(at: location.index)
        case .life: return life.remove(at: location.index)
        case .trash: return trash.remove(at: location.index)
        }
    }

    private mutating func put(_ instance: CardInstance, into zone: BoardZone, at position: ZonePosition) {
        switch zone {
        case .leader:
            leader = instance
        case .characters:
            // 通常は moveCharacter() を通る。念のため、一番左の空きスロットへ入れる
            if let slot = characterSlots.firstIndex(where: { $0 == nil }) {
                characterSlots[slot] = instance
            }
        case .stage:
            stage = instance
        case .hand:
            hand.insert(instance, at: position.resolvedIndex(count: hand.count))
        case .deck:
            deck.insert(instance, at: position.resolvedIndex(count: deck.count))
        case .life:
            life.insert(instance, at: position.resolvedIndex(count: life.count))
        case .trash:
            trash.insert(instance, at: 0)
        }
    }

    /// ゾーンをまたいだときの状態のリセット（付与ドンは呼び出し側で先に回収しておく）
    private func normalized(_ instance: CardInstance, for zone: BoardZone) -> CardInstance {
        var result = instance
        result.isRested = false
        result.attachedDon = 0
        result.powerModifier = 0   // 場を離れたら、パワー・コストの増減はリセットする
        result.costModifier = 0
        result.isFaceUp = (zone != .deck && zone != .life)
        return result
    }

    // MARK: パワー・コストの増減（詳細画面から）

    /// リーダー・キャラのパワーを増減する。場を離れるとリセットされる。
    @discardableResult
    mutating func adjustPower(_ id: UUID, by delta: Int) -> Bool {
        modifyFieldCard(id, allowedZones: [.leader, .characters]) { card in
            card.powerModifier += delta
            card.clampModifiers()
        }
    }

    /// キャラのコストを増減する。場を離れるとリセットされる。
    @discardableResult
    mutating func adjustCost(_ id: UUID, by delta: Int) -> Bool {
        modifyFieldCard(id, allowedZones: [.characters]) { card in
            card.costModifier += delta
            card.clampModifiers()
        }
    }

    /// パワー・コストの増減を、元に戻す
    @discardableResult
    mutating func resetModifiers(_ id: UUID) -> Bool {
        modifyFieldCard(id, allowedZones: [.leader, .characters]) { card in
            card.powerModifier = 0
            card.costModifier = 0
        }
    }

    /// リーダー・キャラの1枚を書き換える（指定したゾーンにいるときだけ）
    private mutating func modifyFieldCard(
        _ id: UUID,
        allowedZones: Set<BoardZone>,
        _ change: (inout CardInstance) -> Void
    ) -> Bool {
        guard let location = locate(id), allowedZones.contains(location.zone) else { return false }

        switch location.zone {
        case .leader:
            guard var card = leader else { return false }
            change(&card)
            leader = card
            return true
        case .characters:
            guard var card = characterSlots[location.index] else { return false }
            change(&card)
            characterSlots[location.index] = card
            return true
        default:
            return false
        }
    }

    // MARK: レスト・ライフの表裏

    /// リーダー・キャラ・ステージのレスト⇄アクティブを切り替える
    @discardableResult
    mutating func toggleRest(_ id: UUID) -> Bool {
        if leader?.id == id {
            leader?.isRested.toggle()
            return true
        }
        if let i = characterSlots.firstIndex(where: { $0?.id == id }) {
            characterSlots[i]?.isRested.toggle()
            return true
        }
        if stage?.id == id {
            stage?.isRested.toggle()
            return true
        }
        return false
    }

    /// ライフのカードの表⇄裏を切り替える
    @discardableResult
    mutating func flipLifeCard(_ id: UUID) -> Bool {
        guard let i = life.firstIndex(where: { $0.id == id }) else { return false }
        life[i].isFaceUp.toggle()
        return true
    }

    // MARK: ドン

    /// ドンを動かす。取り出せない・置けない組み合わせのときは何も変えず false。
    /// - ドンデッキから出たドンはアクティブでコストエリアに入る。
    /// - 付与から外れたドンは、レストでコストエリアに戻る。
    @discardableResult
    mutating func moveDon(from source: DonSource, to destination: DonDestination) -> Bool {
        // 取り出せるか
        switch source {
        case .donDeck:
            guard donDeck > 0 else { return false }
        case .cost(let id):
            guard costDon.contains(where: { $0.id == id }) else { return false }
        case .attached(let id):
            guard attachedDonCount(of: id) > 0 else { return false }
        }

        // 置けるか
        switch destination {
        case .donDeck:
            if source == .donDeck { return false }
        case .costArea:
            // コストエリアの中での移動は、並べ替えは行わないので受け付けない
            if case .cost = source { return false }
        case .card(let id):
            guard canAttachDon(to: id) else { return false }
            if source == .attached(id) { return false }
        }

        // 取り出す
        switch source {
        case .donDeck: donDeck -= 1
        case .cost(let id): costDon.removeAll { $0.id == id }
        case .attached(let id): addAttachedDon(-1, to: id)
        }

        // 置く
        switch destination {
        case .donDeck:
            donDeck += 1
        case .costArea:
            // ドンデッキから出たドンはアクティブ、付与から外れたドンはレストで入る
            costDon.append(DonCard(isRested: source != .donDeck))
        case .card(let id):
            addAttachedDon(1, to: id)
        }
        return true
    }

    /// コストエリアのドン1枚のレスト⇄アクティブを切り替える
    @discardableResult
    mutating func toggleDon(_ id: UUID) -> Bool {
        guard let index = costDon.firstIndex(where: { $0.id == id }) else { return false }
        costDon[index].isRested.toggle()
        return true
    }

    /// ドンデッキから最大 count 枚を、アクティブでコストエリアに出す
    mutating func addDon(_ count: Int) {
        let moved = min(max(count, 0), donDeck)
        donDeck -= moved
        for _ in 0..<moved {
            costDon.append(DonCard(isRested: false))
        }
    }

    /// 付与されていたドンを、レストでコストエリアに戻す（カードが場を離れたとき・リフレッシュで使う）
    private mutating func returnAttachedDon(count: Int) {
        for _ in 0..<max(count, 0) {
            costDon.append(DonCard(isRested: true))
        }
    }

    private func canAttachDon(to id: UUID) -> Bool {
        leader?.id == id || characters.contains(where: { $0.id == id })
    }

    private func attachedDonCount(of id: UUID) -> Int {
        if let leader, leader.id == id { return leader.attachedDon }
        return characters.first(where: { $0.id == id })?.attachedDon ?? 0
    }

    private mutating func addAttachedDon(_ delta: Int, to id: UUID) {
        if leader?.id == id {
            leader?.attachedDon += delta
            return
        }
        if let i = characterSlots.firstIndex(where: { $0?.id == id }) {
            characterSlots[i]?.attachedDon += delta
        }
    }

    // MARK: ドロー・リフレッシュ

    /// 山札の一番上を手札に加える。山札が空なら何もせず false。
    @discardableResult
    mutating func draw() -> Bool {
        guard !deck.isEmpty else { return false }
        var card = deck.removeFirst()
        card.isFaceUp = true
        hand.append(card)
        return true
    }

    /// リフレッシュ: 付与ドンをレストでコストエリアに戻し、レストのカード・ドンをすべてアクティブにする
    mutating func refresh() {
        if var current = leader {
            returnAttachedDon(count: current.attachedDon)
            current.attachedDon = 0
            current.isRested = false
            leader = current
        }
        for i in characterSlots.indices {
            if var character = characterSlots[i] {
                returnAttachedDon(count: character.attachedDon)
                character.attachedDon = 0
                character.isRested = false
                characterSlots[i] = character
            }
        }
        stage?.isRested = false

        // コストエリアのドンは、すべてアクティブにする
        for index in costDon.indices {
            costDon[index].isRested = false
        }
    }

    // MARK: ゲーム準備

    mutating func shuffleDeck() {
        deck.shuffle()
    }

    mutating func drawInitialHand() {
        for _ in 0..<PlayerBoard.initialHandCount {
            draw()
        }
    }

    /// マリガン: 手札をすべて山札に戻してシャッフルし、5枚引き直す
    mutating func mulligan() {
        let returned = hand.map { (instance: CardInstance) -> CardInstance in
            var card = instance
            card.isFaceUp = false
            return card
        }
        hand.removeAll()
        deck.insert(contentsOf: returned, at: 0)   // 直後にシャッフルするので位置は問わない
        deck.shuffle()
        drawInitialHand()
    }

    /// ライフの配置。山札の上から、リーダーのライフ値の枚数を取り出す。
    /// 1枚目をライフの一番下に置き、2枚目をその上に重ねていく。
    /// つまり山札の上からN枚目が、ライフの一番上になる。
    mutating func placeInitialLife() {
        let count = min(leader?.card.life ?? PlayerBoard.defaultLife, deck.count)
        guard count > 0 else { return }

        let taken = Array(deck.prefix(count))
        deck.removeFirst(count)
        // lifeは先頭が一番上。taken[0]が一番下になるよう逆順にする
        life = taken.reversed().map { (instance: CardInstance) -> CardInstance in
            var card = instance
            card.isFaceUp = false
            return card
        }
    }
}

// MARK: - デッキから盤面を作る

extension PlayerBoard {
    /// デッキから盤面を作る（山札は未シャッフル・全カード裏向き）。リーダー未設定なら nil。
    init?(from source: Deck) {
        guard let leaderCard = source.leaderCard else { return nil }
        self.init()
        leader = CardInstance(card: leaderCard)
        deck = source.cardEntries.flatMap { (entry: DeckEntry) -> [CardInstance] in
            (0..<max(entry.quantity, 0)).map { _ in
                CardInstance(card: entry.card, isFaceUp: false)
            }
        }
    }
}
