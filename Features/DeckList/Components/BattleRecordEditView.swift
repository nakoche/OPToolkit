//
//  BattleRecordEditView.swift
//  OPToolkit
//
//  対戦記録の追加・編集画面（BattleHistoryViewから.fullScreenCoverで開く）。
//  - 大会: 追加先の大会名を表示する（変更はできない）。回戦は自動で入る。ずれたときだけステッパーで直す。
//  - 相手のリーダー: 大きな画像をタップするとLeaderSelectViewを開いて選ぶ（選び直しはできるが、外すことはできない）。
//  - 勝敗・先攻後攻・じゃんけん: 連動したボタンで選ぶ（勝敗は丸、先攻後攻とじゃんけんは横長の角丸）。
//    最初は何も選ばれておらず、押したボタンだけが選ばれる。
//    選んでいるボタンをもう一度押すと、未選択（記録しない）に戻せる。
//  - メモ: 複数行。
//  - 保存ボタンは、DeckDetailViewと同じく、下の中央に浮かせる（メモの入力中は、入力欄に重ならないよう隠す）。
//  どの項目も必須にしていない（対戦中に素早く残せるように）。
//

import SwiftUI

struct BattleRecordEditView: View {
    let isNew: Bool
    /// 追加先（所属）の大会名。表示のみ
    let tournamentName: String
    let onSave: (BattleRecord) -> Void
    let onCancel: () -> Void

    @State private var draft: BattleRecord
    @State private var opponentLeader: Card?
    @State private var isSelectingLeader = false
    @FocusState private var isMemoFocused: Bool

    /// 相手リーダーの画像の幅（DeckDetailViewの自分のリーダー（90）より大きくしている）
    private let leaderImageWidth: CGFloat = 160

    init(
        record: BattleRecord,
        isNew: Bool,
        tournamentName: String,
        opponentLeader: Card?,
        onSave: @escaping (BattleRecord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isNew = isNew
        self.tournamentName = tournamentName
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: record)
        _opponentLeader = State(initialValue: opponentLeader)
    }

    var body: some View {
        NavigationStack {
            form
                .scrollDismissesKeyboard(.interactively)
                // 下に浮かせた保存ボタンがメモに重なって見えなくならないよう、スクロール末尾に余白を足す
                .contentMargins(.bottom, 88, for: .scrollContent)
                .overlay(alignment: .bottom) {
                    saveButton
                }
                .navigationTitle(isNew ? "対戦を記録" : "対戦を編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル", action: onCancel)
                    }
                    // メモは改行できるので、キーボードを閉じる手段を用意する
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") { isMemoFocused = false }
                    }
                }
                // 相手リーダーの選択（既存のリーダー選択画面をそのまま使う）
                .fullScreenCover(isPresented: $isSelectingLeader) {
                    LeaderSelectView(
                        viewModel: LeaderSelectViewModel(),
                        onSelect: { card in
                            opponentLeader = card
                            draft.opponentLeaderNumber = card.cardNumber
                            isSelectingLeader = false
                        },
                        onCancel: { isSelectingLeader = false }
                    )
                }
        }
    }

    // MARK: - フォーム

    private var form: some View {
        Form {
            roundSection
            leaderSection

            Section("勝敗") {
                OptionButtonGroup(
                    options: MatchResult.allCases,
                    selection: $draft.result,
                    label: { $0.label },
                    tint: { result in
                        switch result {
                        case .win: return OptionButtonColor.win
                        case .lose: return OptionButtonColor.lose
                        case .doubleLoss: return OptionButtonColor.doubleLoss
                        }
                    },
                    shape: .circle
                )
            }

            Section("先攻・後攻") {
                OptionButtonGroup(
                    options: TurnOrder.allCases,
                    selection: $draft.turnOrder,
                    label: { $0.label },
                    tint: { turnOrder in
                        switch turnOrder {
                        case .first: return OptionButtonColor.first
                        case .second: return OptionButtonColor.second
                        }
                    }
                )
            }

            Section("じゃんけん") {
                OptionButtonGroup(
                    options: JankenResult.allCases,
                    selection: $draft.janken,
                    label: { $0.label },
                    tint: { janken in
                        switch janken {
                        case .win: return OptionButtonColor.win
                        case .lose: return OptionButtonColor.lose
                        }
                    }
                )
            }

            Section("メモ") {
                TextField("対戦の振り返りなど", text: $draft.memo, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($isMemoFocused)
            }
        }
    }

    // MARK: - 保存ボタン（下の中央に浮かせる）

    /// DeckDetailViewの保存ボタンと同じ見た目・位置。メモの入力中は、入力欄に重ならないよう隠す。
    @ViewBuilder
    private var saveButton: some View {
        if !isMemoFocused {
            Button {
                onSave(draft)
            } label: {
                Text("保存")
                    .font(.headline)
                    .frame(width: 160)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .shadow(radius: 4, y: 2)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 大会・回戦

    private var roundSection: some View {
        Section {
            LabeledContent("大会", value: tournamentName)
            Stepper("\(draft.round)回戦", value: $draft.round, in: 1...99)
        } header: {
            Text("大会・回戦")
        }
    }

    // MARK: - 相手のリーダー

    private var leaderSection: some View {
        Section("対戦相手のリーダー") {
            Button {
                isSelectingLeader = true
            } label: {
                VStack(spacing: 10) {
                    CardThumbnailImage(card: opponentLeader, cornerRadius: 8)
                        .frame(width: leaderImageWidth)

                    Text(leaderTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(opponentLeader == nil && draft.opponentLeaderNumber == nil ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// カードDBに無い番号が保存されているときは、番号をそのまま出す
    private var leaderTitle: String {
        if let opponentLeader { return opponentLeader.name }
        return draft.opponentLeaderNumber ?? "リーダーを選択"
    }
}

// MARK: - 連動ボタン（勝敗・先攻後攻・じゃんけん用）

/// 連動ボタンの形
private enum OptionButtonShape {
    /// 横いっぱいに広がる角丸の四角（先攻・後攻、じゃんけん）
    case roundedRectangle
    /// 丸（勝敗）
    case circle
}

/// 連動ボタンの選択中の色。選択中は白い文字を載せるので、白でも読める濃さにしている。
private enum OptionButtonColor {
    // 勝ち・負け: 勝敗とじゃんけんで共通（勝ち＝青、負け＝赤。履歴の行の勝敗の丸の色とも合わせている）
    static let win = Color.blue
    static let lose = Color.red
    /// 両負け: 勝ちでも負けでもない結果なので、グレー
    static let doubleLoss = Color.gray

    // 先攻・後攻: 勝ち負けの青・赤と取り違えない色で、2つの間は暖色と寒色で見分けやすくしている
    /// 先攻: オレンジ（先に攻める、暖かい色）
    static let first = Color(red: 0.80, green: 0.42, blue: 0.0)
    /// 後攻: ティール（青緑。後から受ける、落ち着いた色）
    static let second = Color(red: 0.0, green: 0.55, blue: 0.55)
}

/// 横に並べたボタンのうち、押したものだけが選ばれる（ラジオボタンのような動き）。
/// - 最初（selectionがnil）は、どれも選ばれていない。
/// - 選ばれているボタンをもう一度押すと、未選択（nil）に戻る。
/// - 選ばれたボタンは、色だけでなく塗りつぶしと白い文字で区別する（VoiceOverにも「選択中」と伝える）。
private struct OptionButtonGroup<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String
    let tint: (Option) -> Color
    var shape: OptionButtonShape = .roundedRectangle

    /// 丸ボタンの直径の上限。iPadなどの広い画面で、丸が大きくなりすぎないようにする
    private let maxCircleDiameter: CGFloat = 140

    /// 丸ボタンの間隔。左右の端の余白（セクションの端から丸まで）も、同じ値にそろえる
    private let circleSpacing: CGFloat = 20

    var body: some View {
        // 丸のときは、「丸と丸の間隔」と「セクションの端から丸までの余白」を同じ値（circleSpacing）にそろえる。
        // Formの行には標準の左右余白があるので、丸のときだけそれをなくして、同じ値の余白を自前で付ける。
        HStack(spacing: shape == .circle ? circleSpacing : 8) {
            ForEach(options, id: \.self) { option in
                optionButton(option)
            }
        }
        .padding(.horizontal, shape == .circle ? circleSpacing : 0)
        .padding(.vertical, 2)
        .listRowInsets(shape == .circle ? EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0) : nil)
    }

    private func optionButton(_ option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            selection = isSelected ? nil : option
        } label: {
            buttonLabel(option, isSelected: isSelected)
        }
        // Formの行の中で複数のボタンを並べるときは、.plainにしないと、行全体が1つのボタンとして反応してしまう
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func buttonLabel(_ option: Option, isSelected: Bool) -> some View {
        let foreground = isSelected ? Color.white : Color.primary
        let fill = isSelected ? tint(option) : Color(uiColor: .systemGray5)

        switch shape {
        case .roundedRectangle:
            Text(label(option))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(foreground)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))

        case .circle:
            // 塗りつぶした円を土台にして、その上に文字を重ねる。
            // 円は渡された横幅いっぱいに広がるので、高さを幅と同じにすれば、ボタンの数で横幅を等分した大きさの正円になる。
            // （文字にaspectRatioを付けると、文字の大きさに引きずられて円が小さくなり、「…」と省略されてしまう）
            Circle()
                .fill(fill)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text(label(option))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                }
                // タップできる範囲を丸の中だけにする
                .contentShape(Circle())
                // 広い画面で大きくなりすぎないよう上限を付け、残りは左右の余白にする
                .frame(maxWidth: maxCircleDiameter)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    BattleRecordEditView(
        record: BattleRecord(deckID: UUID(), tournamentID: UUID(), round: 3),
        isNew: true,
        tournamentName: "店舗大会 10月",
        opponentLeader: .sampleLuffy,
        onSave: { _ in },
        onCancel: {}
    )
}
