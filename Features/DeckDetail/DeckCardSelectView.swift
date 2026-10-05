//
//  DeckCardSelectView.swift
//  OPToolkit
//
//  「デッキカードを選択する」ボタンから開く画面。
//  カード一覧画面と同じグリッド表示。リーダーは除外して表示する。
//  色フィルタはリーダーの色で固定（フィルタシート内では変更不可）。
//  カードをタップすると枚数指定モーダルが出る。
//
//  以前は1枚確定するたびに画面が閉じてデッキ詳細に戻ってしまっていたが、
//  選んだ内容は即座にデッキへ反映されつつ、この画面は開いたままにして
//  続けて何枚でも選べるようにした。画面上部に現在の合計枚数を常に表示し、
//  終わったら「完了」で閉じる（添付の参考画像のように、デッキの状態を
//  見ながらカードリストから選び続けられる形に近づけている）。
//

import SwiftUI

struct DeckCardSelectView: View {
    @State var viewModel: DeckCardSelectViewModel
    let currentQuantity: (Card) -> Int
    /// 現在デッキに入っているカード（画面上部のプレビュー表示用）
    let deckEntries: () -> [DeckEntry]
    let onConfirm: (Card, Int) -> Void
    let onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    // 画面上部の「現在のデッキ」サムネイル
    private let thumbnailWidth: CGFloat = 44
    private let thumbnailSpacing: CGFloat = 6
    /// サムネイル領域の最大行数。これを超える枚数が選ばれたら、領域の中だけが縦にスクロールする
    /// （カード一覧が押し出されて見えなくなるのを防ぐための上限）
    private let maxPreviewRows = 3
    /// サムネイル領域の中身の高さ（枚数に合わせて高さを伸ばすために測定する）
    @State private var previewContentHeight: CGFloat = 0
    /// タップでカードを追加した回数。変化するたびに軽い振動で知らせる（追加できなかったときは変えない）
    @State private var addFeedbackCount = 0
    /// 上部のサムネイルをタップしてカードを減らした回数。変化するたびに、追加と同じ強さの振動で知らせる
    @State private var removeFeedbackCount = 0

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredCards) { card in
                            CardImageCell(card: card)
                                .overlay(alignment: .bottomTrailing) {
                                    let quantity = currentQuantity(card)
                                    if quantity > 0 {
                                        Text("×\(quantity)")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(4)
                                            .background(.blue, in: Capsule())
                                            .foregroundStyle(.white)
                                            .padding(3)
                                    }
                                }
                                // タップで1枚追加（上限4枚）
                                .onTapGesture {
                                    addOne(card)
                                }
                                // 長押しで、拡大表示＋枚数を直接指定するモーダルを開く
                                .onLongPressGesture(minimumDuration: 0.4) {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        viewModel.selectCard(card)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
                // 下に浮かせたボタンが、一番下の行のカードに重なって押せなくならないよう、スクロール末尾に余白を足す
                .contentMargins(.bottom, 88, for: .scrollContent)
                .safeAreaInset(edge: .top, spacing: 0) {
                    addedCardsPreview
                }
                .overlay(alignment: .bottom) {
                    // 枚数指定モーダルの表示中は隠す（モーダルのバツボタンと位置が重なって見づらくなるため）
                    if viewModel.selectedCard == nil {
                        floatingButtons
                            .transition(.opacity)
                    }
                }
                // ナビゲーションバーを隠して、サムネイル領域を画面の上端に寄せる
                .toolbar(.hidden, for: .navigationBar)
                // カードを追加できたときの、軽い振動
                .sensoryFeedback(.impact(weight: .light), trigger: addFeedbackCount)
                // カードを減らしたときの振動（追加と同じ強さ）
                .sensoryFeedback(.impact(weight: .light), trigger: removeFeedbackCount)
                // 長押しでモーダルが開いたときの振動（閉じるときは鳴らさない）
                .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.selectedCard) { _, newValue in
                    newValue != nil
                }
                .fullScreenCover(isPresented: $viewModel.isFilterSheetPresented) {
                    CardSearchSheet(
                        criteria: viewModel.criteria,
                        lockedColors: viewModel.lockedColors,
                        onSearch: { newCriteria in
                            viewModel.applySearch(newCriteria)
                            viewModel.isFilterSheetPresented = false
                        },
                        onCancel: {
                            viewModel.isFilterSheetPresented = false
                        }
                    )
                }
                .task {
                    await viewModel.loadCards()
                }
            }

            if let card = viewModel.selectedCard {
                CardQuantityModal(
                    card: card,
                    initialQuantity: currentQuantity(card),
                    onConfirm: { quantity in
                        onConfirm(card, quantity)
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.selectedCard = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.selectedCard = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(1)
            }
        }
    }

    /// 画面上部：現在デッキに入っているカードのサムネイルを、折り返して並べる。
    /// 選んだカードがその場で追加されていくのが見えるようにするための領域。
    /// 高さは枚数（行数）に合わせて伸び、maxPreviewRows行を超えたらその中だけスクロールする。
    private var addedCardsPreview: some View {
        let entries = deckEntries()
        let total = entries.reduce(0) { $0 + $1.quantity }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("現在のデッキ")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(total)/50")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(total == 50 ? .green : .primary)
            }
            .padding(.horizontal, 16)

            if entries.isEmpty {
                Text("カードをタップで追加／長押しで拡大・枚数指定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: thumbnailWidth, maximum: thumbnailWidth), spacing: thumbnailSpacing)],
                        alignment: .leading,
                        spacing: thumbnailSpacing
                    ) {
                        ForEach(entries) { entry in
                            addedCardThumbnail(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        previewContentHeight = newHeight
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(previewContentHeight, maxPreviewHeight))
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 4)
        .background(.ultraThinMaterial)
    }

    private var maxPreviewHeight: CGFloat {
        let thumbnailHeight = thumbnailWidth * 3.5 / 2.5
        let rows = CGFloat(maxPreviewRows)
        return thumbnailHeight * rows + thumbnailSpacing * (rows - 1)
    }

    private func addedCardThumbnail(_ entry: DeckEntry) -> some View {
        CardThumbnailImage(card: entry.card, cornerRadius: 5)
            .frame(width: thumbnailWidth)
            .overlay(alignment: .bottomTrailing) {
                Text("×\(entry.quantity)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(3)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(2)
            }
            // タップで1枚減らす（0枚になったらデッキから外れる）
            .onTapGesture {
                removeFeedbackCount += 1
                onConfirm(entry.card, entry.quantity - 1)
            }
    }

    /// カード一覧のタップ：1枚追加する。追加できたときだけ振動する。
    /// 上限（4枚）のときは何もしない（振動もしない。カードの「×4」の表示で上限だと分かる）。
    private func addOne(_ card: Card) {
        let current = currentQuantity(card)
        guard current < Deck.maxCopiesPerCard else { return }
        addFeedbackCount += 1
        onConfirm(card, current + 1)
    }

    /// カード一覧の上に浮かせて表示するボタン：「完了」を下の中央に、フィルタを右端に置く。
    /// 片手でも押しやすいよう、完了ボタンは下の中央にしている。
    private var floatingButtons: some View {
        ZStack {
            Button(action: onClose) {
                Text("完了")
                    .font(.headline)
                    .frame(width: 160)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .shadow(radius: 4, y: 2)

            HStack {
                Spacer()
                filterButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var filterButton: some View {
        Button {
            viewModel.isFilterSheetPresented = true
        } label: {
            Image(systemName: "camera.filters")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .accessibilityLabel("フィルタ・並び替え")
    }
}

#Preview {
    DeckCardSelectView(
        viewModel: DeckCardSelectViewModel(lockedColors: [.red], repository: MockCardRepository()),
        currentQuantity: { _ in 0 },
        deckEntries: { [DeckEntry(card: .sampleZoro, quantity: 3)] },
        onConfirm: { _, _ in },
        onClose: {}
    )
}
