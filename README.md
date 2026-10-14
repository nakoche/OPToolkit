# OPToolkit

ワンピースカードゲーム（OPTCG）向けのマルチツールアプリ。SwiftUI + MVVM。**個人利用のみで、公開しない**前提で作っている。

このドキュメントは、別のセッション（別のClaude、別の開発者）が開発を引き継げることを目的に、確認できた事実だけを書いている。確認できていないことは、「要確認」と明記するか、10章にまとめた。

> **確認状況の凡例**
> - 見出しに**（継承）**とある節は、前回までのREADMEの記述を整理して引き継いだもので、今回の見直しではソースコードを再確認していない。
> - それ以外の節（一人回し、`Card`／`DeckStore`まわり、`cards.json`の生成など）は、今回までに共有・作成したコードで確認している。
> - Xcodeでのビルドと動作確認は、ユーザーが行っている（Claudeはビルドできない）。

---

## 1. 概要と機能

| 画面 | 内容 | 状態 |
|---|---|---|
| ① カードリスト | 検索・絞り込み・並び替え・カード詳細表示 | 実装済み |
| ② デッキ | 一覧、作成/編集、永続化、QR共有、画像書き出し | 実装済み。対戦履歴画面のみプレースホルダー |
| ③ 一人回し | カードを自由に動かせるデジタルテーブルトップ（カード効果は反映しない） | 実装済み。BGM・効果音・詳細設定は未実装 |
| ④ 設定 | 画面モード、デフォルト並び順、効果音トグルなど | 一部のみ反映（7章参照） |

---

## 2. 技術・開発環境

| 技術 | 用途 |
|---|---|
| SwiftUI + `@Observable`（Observation） | 全画面・全ViewModel。`ObservableObject`は使わない |
| `Kingfisher`（SPM。唯一の外部パッケージ） | カード画像の非同期取得とキャッシュ（2000枚以上あるため） |
| `Transferable` / `.draggable` / `.dropDestination` | 一人回しのドラッグ&ドロップ |
| `Vision`・`CoreImage`・`AVFoundation`・`Photos`・`PhotosUI` | QRの生成・読み取り、デッキ画像の保存 |
| `ImageRenderer` | デッキ画像の書き出し |

- **最低OS**: `@Observable`、`ContentUnavailableView`、`withAnimation(_:completionCriteria:_:completion:)`、`.onChange(of:)`の2引数形式などを使っているので、**iOS 17以降が必要**。Deployment Targetの設定値そのものは未確認。
- **並行処理の設定**: ビルド警告（`Main actor-isolated conformance ... cannot be used in nonisolated context`）から、Default Actor Isolationは**MainActor**、Swiftの言語モードは**5**と推測している（ビルド設定は未確認）。そのため、MainActor外で使う型には`nonisolated`が必要（9章）。

---

## 3. セットアップ・ビルド

### 3.1 必要なもの

1. **Kingfisher**: Swift Package Managerで追加済みであること。
2. **`cards.json`**: アプリのBundleに含める（下記3.2で生成）。**古いと一人回しのライフ数が合わない**（`life`が無いと、全リーダーが5枚で始まる）ので、`Card`に項目を足したときや公式サイトが更新されたときは、再生成して差し替える。
3. **Info.plist**（追加済み。コードでは自動化できない）: `NSCameraUsageDescription`（QRカメラ読み取り）、`NSPhotoLibraryAddUsageDescription`（デッキ画像の保存）。値が空だと警告が出るので、空でない文言を入れる。
4. **画像アセット**（`Assets.xcassets`のImage Set）: `CardBack`（カード裏面）、`DonFront`（ドン!!カード表面）、`DonBack`（ドン!!カード裏面）。一人回しで使う。`cards.json`の画像のようにネットから取得せず、アプリに同梱している。

### 3.2 `cards.json`の生成（`Tools/fetch_cards.py`）

公式カードリスト（`https://www.onepiece-cardgame.com/cardlist/`）をスクレイピングして生成する。初回のみ`pip3 install requests beautifulsoup4`が必要。

```
cd Tools
python3 fetch_cards.py                   # 全弾を取得（取得済みHTMLは raw_html/ にキャッシュ。リクエスト間隔は既定1.5秒）
python3 fetch_cards.py --offline         # キャッシュ済みHTMLだけで、通信せずに作り直す
python3 fetch_cards.py --refresh         # キャッシュを無視して再取得
python3 fetch_cards.py --series 550101   # 特定の弾だけ取得（動作確認用）
```

- 出力は`cards.json`（`--out`で変更可）。生成後、Bundleの`cards.json`と差し替える。
- 実行後のログで、取得枚数、複数色・複数属性の枚数、特徴の分割結果、検出したパック、**リーダーのライフ値の内訳**（「取得できず」が出ていないこと）、スキップ枚数を確認する。
- 公式サイトのHTML構造が変わった場合は、`parse_cards`と`pack_code_from_label`の修正が必要。
- **このスクリプトはXcodeのターゲットに追加しない**。アプリに入れるのは`cards.json`だけ。

### 3.3 ビルド・実行

Xcodeでビルド・実行する。コマンドラインでのビルド手順は、確認していない。自動テストは、現状ない。

---

## 4. アーキテクチャ

### 4.1 MVVM

- 各画面は`View`と`ViewModel`（`@Observable`クラス）の組。`View`は`@State var viewModel: XxxViewModel`で保持する（`@StateObject`ではない）。
- データ取得・永続化は`Services/`層。ViewModelは具体的な実装ではなくプロトコル（`CardRepositoryProtocol`、`DeckStoreProtocol`）に依存する。プレビュー用に`MockCardRepository`がある。
- `RootView`は、`TabView`で4画面をまとめ、**ViewModelを`@State`で1回だけ保持する**（`body`が再評価されるたびに作り直されないように）。`init`で`DeckListViewModel`を作り、その`store`を`SoloPlayViewModel`に渡して、**デッキ画面と一人回しが同じ`DeckStore`を使う**。
- `Models/`は、データ構造と、その値だけで決まる計算を置く。画面やI/Oには依存させない。

### 4.2 ディレクトリ構成

フォルダ配置は、前回までのREADMEと、会話内で案内した配置先に基づく。実際のXcodeのグループは未確認（`BoardArea.swift`が`Features/SoloPlay/Components/`にあることだけ、ユーザーが確認済み）。

```
OPToolkit/
├── OPToolkitApp.swift            // @main
├── RootView.swift                // 4画面のTabView。DeckStoreを共有して各ViewModelを保持
│
├── Models/
│   ├── Card.swift                // Card と列挙型（色・種類・属性・レアリティ・ブロックアイコン）
│   ├── Card+ReleaseSort.swift    // カードリストの発売順の比較（CardReleaseOrder）
│   ├── Deck.swift                // Deck, DeckEntry, デッキ集計
│   ├── AppSettings.swift         // AppColorScheme, CardSortKey, SortDirection
│   ├── CardInstance.swift        // 【一人回し】盤面上のカード1枚（UUID・レスト・付与ドン・パワー/コストの増減）
│   ├── PlayerBoard.swift         // 【一人回し】1人分の盤面。ゾーン・ドン・移動ルール
│   └── GameState.swift           // 【一人回し】Perspective, GameState（Undoの単位）
│
├── Services/
│   ├── CardRepository.swift      // cards.jsonの読み込み
│   ├── ImageHost.swift           // カード画像URLの組み立て（公式サイトを直接参照）
│   ├── ImageCacheConfig.swift    // Kingfisherのキャッシュ設定
│   ├── DeckStore.swift           // デッキの永続化（JSON）
│   ├── StoredDeck.swift          // デッキの保存形式（カード番号＋枚数）
│   ├── SettingsStore.swift       // @AppStorageのキーを集約
│   ├── QRCodeService.swift       // QR画像の生成
│   ├── DeckQRPayload.swift       // デッキ⇄QR文字列
│   └── QRImageDecoder.swift      // 写真に写ったQRの読み取り
│
├── Features/
│   ├── CardList/                 // ① CardListView/ViewModel, CardSearchSheet, CardSearchCriteria, CardDetailModal
│   ├── DeckList/                 // ② DeckListView/ViewModel, 画像書き出し, QRScannerView, BattleHistoryView(空)
│   ├── DeckDetail/               // ② デッキ詳細・リーダー選択・デッキカード選択・枚数モーダル
│   ├── SoloPlay/                 // ③ 一人回し（5.4参照）
│   │   ├── SoloPlayView.swift
│   │   ├── SoloPlayViewModel.swift
│   │   ├── SoloPlayViewModel+Detail.swift
│   │   ├── SoloDragItem.swift
│   │   ├── Deck+SoloPlay.swift
│   │   └── Components/
│   └── Settings/                 // ④ SettingsView/ViewModel
│
└── Shared/
    ├── Components/               // CardThumbnailImage, CardBackImage, FilterChip, ShareSheet, BackSwipeInterceptor
    └── Extensions/               // String+Search（ひらがな/カタカナを区別しない検索）

Tools/                            // Xcodeターゲットに含めない
└── fetch_cards.py
```

規則: 各`Features/<画面名>/`の直下に`<画面名>View.swift`と`<画面名>ViewModel.swift`、その画面専用の小さなViewは`Components/`に置く。

### 4.3 並行処理（アクター隔離）

Default Actor IsolationがMainActorだと、型や`static`メンバーが暗黙にMainActorになる。次のような型には、明示的に`nonisolated`を付けている。

- バックグラウンドで使う処理（`QRImageDecoder`の各メソッド、`Card`の`init(from:)`/`encode(to:)`）
- MainActor外の文脈で`==`や`Codable`が必要な型（`Perspective`、`SoloPlayError`、ドラッグの中身の`DonSource`・`SoloDragContent`・`SoloDragItem`）

---

## 5. 画面と機能

### 5.1 画面遷移（継承）

```
RootView (TabView)
├─ CardListView … CardDetailModal（オーバーレイ） / CardSearchSheet（fullScreenCover）
├─ DeckListView
│   ├─ DeckDetailView（push。タブバー非表示、標準の戻るボタンは非表示）
│   │   ├─ LeaderSelectView（fullScreenCover。新規作成時のみ）
│   │   └─ DeckCardSelectView（fullScreenCover）… CardQuantityModal / CardSearchSheet（色固定）
│   ├─ BattleHistoryView（push。プレースホルダー）
│   ├─ QRScannerView（fullScreenCover。「画像から」/「カメラ」）
│   └─ DeckImagePreviewModal（オーバーレイ）
├─ SoloPlayView … デッキ選択 → マリガン → 対戦中（5.4）
└─ SettingsView
```

### 5.2 ① カードリスト（`Features/CardList/`）

- 1行5枚の`LazyVGrid`。下部の固定フッターに、カード名・番号の検索欄とフィルタボタン。
- 検索条件は`CardSearchCriteria`（色・種類・特徴・コスト・パワー・属性・カウンター・レアリティ・ブロックアイコン・並び替え）に集約。`CardSearchSheet`（`fullScreenCover`）で編集する。色・属性の複数選択は**OR**（どれか1つ持っていればよい）。`lockedColors`を渡すと、色フィルタを固定できる（デッキカード選択で使用）。
- **デフォルトの表示順は「発売順」**（`CardSortKey.releaseOrder`）。優先順位は、①弾の種類（`OP`→`EB`→`PRB`→`ST`→その他）、②同じ種類の中では番号が新しい弾が先、③同じ弾の中ではオリジナルが先で再録は末尾、④番号順、⑤ノーマルが先でパラレルが後、⑥パラレル同士はレアリティが低い方が先。単純な1キー比較にできないため、`CardReleaseOrder`の専用比較で行う。
- カードをタップすると、`CardDetailModal`（画像だけを大きく見せるライトボックス）を出す。**背景のタップ**か、**上下左右へのドラッグ**（一定距離を超える）で閉じる。×ボタンは無い。呼び出し側が`accessory`を渡すと、画像の下に部品を並べられる（一人回しで使う）。

### 5.3 ② デッキ（継承。`DeckStore`・`StoredDeck`は確認済み）

#### 一覧（`DeckListView`）
- 各行: リーダー画像、デッキ名、「対戦履歴」「画像作成」「コピー」。右端の「＝」ハンドルのドラッグで並び替え、左スワイプで削除（`.alert`で確認）。
- 右下に「＋」（デッキ作成）と「QRから作成」。表示のたびに`await viewModel.load()`で保存済みデッキを復元する。保存失敗は「保存できません」のアラートで通知する。
- 画像作成: `DeckImageExporter`が、QR付きの1枚画像（幅400pt、`ImageRenderer.scale = 3`）を作る。カード画像は、事前に`KingfisherManager`で取得してから描画する。保存はPNGで`PHAssetCreationRequest`（`.addOnly`権限）。
- QR読み込み: 「画像から」（既定。`PhotosPicker`＋`QRImageDecoder`）と「カメラ」（切り替えたときだけ起動。読み取りは画面中央の枠の中だけ）。既存のデッキと同名なら「〇〇コピー1」のように番号を付ける。
- QRの中身は、短い独自形式`OPTK1`（デッキ名・リーダーのカード番号・「カード番号:枚数」の並び）。旧JSON形式も読める。

#### 詳細・カード選択（`Features/DeckDetail/`）
- `DeckDetailView`: デッキ名、リーダー、デッキカード、デッキ情報、コスト別の棒グラフ、特徴別の枚数、メモ。保存ボタンは下に浮かせる。デッキ名・リーダー・カード・メモのいずれかが保存時点から変わっているときは、戻る操作（自前の戻るボタンと、左端スワイプの`BackSwipeInterceptor`）で確認を出す。
- `LeaderSelectView`: リーダーだけのグリッド。タップで即選択。パラレル表示は3状態（ノーマルのみ／混在／パラレルのみ）。
- `DeckCardSelectView`: **タップで+1、長押し（0.4秒）で`CardQuantityModal`（枚数指定）、画面上部の追加済みサムネイルのタップで-1**。同じカード番号は`Deck.maxCopiesPerCard`（4）まで。色フィルタはリーダーの色に固定（2色リーダーなら、どちらかの色を持つカード）。「完了」ボタンとフィルタボタンは、カード一覧の上に浮かせる。

#### 永続化（`DeckStore`）
- 保存先は`Application Support/OPToolkit/decks.json`。形式は`{ "version": 1, "decks": [...] }`で、**`Card`の実体は保存せず、カード番号＋枚数（`StoredDeck`）だけ**を保存する。`Card`にフィールドを足しても、保存済みデッキが読めなくなったり、`cards.json`の更新が反映されなくなったりしないため。
- ファイルは`init`で同期的に読む。`Card`への復元はカードDB（非同期）が必要なので、画面表示時に`await prepare()`を1回呼ぶ。`prepare()`前の`fetchAll()`は空を返す。
- **永続化の正は`stored`（カード番号＋枚数）で、復元済みの`decks`はその写し**。`prepare()`前に`save`等が呼ばれても、保存済みデータを壊さない。`cards.json`を読めなかったときは復元しない。`decks.json`が壊れていたときは`decks.corrupt.json`に退避してから空で始める。`cards.json`から消えたカード番号は、表示から外れるが保存ファイルには残る。
- `save`/`update`/`delete`/`reorder`は`throws`（失敗は`DeckStoreError.writeFailed`）。

### 5.4 ③ 一人回し（`Features/SoloPlay/`）

**概要**: 1人で両側を操作する対戦練習用の**デジタルテーブルトップ**。カード効果は反映せず、カードを自由に動かせることを目的にしている。ルールとして強制するのは、キャラエリア5枠・ステージ1枚・リーダーは動かせない、の3つだけ。

#### 流れ
1. **デッキ選択**（`SoloDeckSelectionView`）: 左が先攻、右が後攻。それぞれ`DeckStore`のデッキから選ぶ。選べるのは**リーダー設定済みで50枚のデッキだけ**（`Deck.isReadyForBattle`）。未選択の枠は`CardBack`、選択後はリーダーと「ライフ n」を表示する（`cards.json`に`life`が無いときは、オレンジの「ライフ不明（5枚で開始）」）。両方選ぶと「バトル開始」が押せる。
2. **マリガン**（`SoloMulliganView`）: 先攻、後攻の順に、5枚の手札を見て、「引き直す」（何回でも）か「このまま」を選ぶ。左上の「中止」でデッキ選択に戻る。後攻が「このまま」を押すと、ライフが置かれて対戦が始まる。
3. **対戦中**（`BoardArea`＋操作バー）。ライフは、山札の上から**リーダーのライフ値（`Card.life`。無ければ5）の枚数**を取り、1枚目をライフの一番下に置いて重ねる（山札の上からN枚目がライフの一番上。すべて裏向き）。先攻はドン!!1枚、ドローなしで始まる。

#### 盤面（`PlayerBoardView`）
公式プレイマットの配置に合わせた3段・7列のグリッド（カード幅を1列とする）。

| 段 | 自分側 |
|---|---|
| 1段目 | 左にライフ（1・2段目にまたがる縦長）。右の6列に、キャラ5スロットを均等に配置 |
| 2段目 | リーダーは盤面の横幅のど真ん中。ステージは右から2番目のキャラの真下、デッキは右端のキャラの真下。リーダーの左に「先攻」「後攻」の文字 |
| 3段目 | 左にドンデッキ、中央にコストエリア（ドンを1枚ずつ重ねて並べる）、右にトラッシュ。高さはカードの約7割（`bottomRowScale`） |

- **相手側は、自分側を180°回した点対称**の配置（ライフが右、デッキが左、スロットとドンの並びも逆順）。カードそのものは回転させない。
- 上に相手の手札（裏向き。重ねて並べ、枚数を右端に重ねて表示）、下に自分の手札（表向き。横スクロール。枚数を左下に重ねて表示）。
- 画面の**上半分と下半分で背景色を分ける**。手番のプレイヤーの側は、先攻ならオレンジ、後攻なら青。手番でない側はグレー。
- カード1枚の幅は、画面の幅（7列）と高さ（3段×2人分と手札）の小さいほうに合わせて決める（`BoardArea.fittingCardWidth`）。対戦中は「一人回し」のナビゲーションバーを隠して、高さを確保している。iPhone・iPadとも、同じ配置で大きさだけが変わる。
- ドンの合計枚数は、コストエリアの一番端（最初に出した）ドンの上に表示する。

#### 操作

| 対象 | 操作 | 動作 |
|---|---|---|
| リーダー・キャラ・ステージ | タップ | レスト⇄アクティブ（レストは横向き） |
| ライフ | タップ | 表⇄裏 |
| コストエリアのドン | タップ | 1枚ずつレスト⇄アクティブ |
| ドンデッキ | タップ | アクティブなドンを1枚、コストエリアへ |
| 山札 / トラッシュ | タップ | 確認パネルを開く（下記） |
| カード・ドン | ドラッグ&ドロップ | ゾーン間の移動（下記） |
| 操作バーの「詳細」 | 押してから、カードをタップ | カードの詳細を表示（下記） |

- **ドラッグ&ドロップ**: iOS標準の仕組み（長押しして持ち上げる）。カードとドンは、**持ち主の盤面のゾーンにしか動かせない**（`SoloDragItem.owner`）。
  - キャラは、空きスロットへドロップで移動、埋まっているスロットへドロップで入れ替え。手札などから出すときは、ドロップしたスロット（埋まっていれば、一番左の空き）に置く。5体満杯・ステージ置き済みのエリアに、新しいカードは置けない（赤く光り、触覚で知らせる）。
  - ドンは、ドンデッキ・コストエリア・カードの間で動かせる。キャラ・リーダーへドロップすると付与され（カードの下に、右下へずらして重なる）、付与ドンの枚数バッジをドラッグすると外せる。
  - 山札・ライフへのドロップは、あとで「上に置く／下に置く」を選ぶ。
  - ゾーンをまたぐと、レスト・付与ドン・パワーとコストの増減はリセットされる。付与ドンは、レストでコストエリアに戻る。
- **ドロップの判定範囲**: 何も描かれていない部分（点線の空きスロットなど）でも受け付けるよう、`SoloDropZone`が`contentShape`を付けている。

#### ターン進行・視点
- **ターン終了**で、手番を交代し、次の手番側のリフレッシュ（付与ドンを戻し、レストのカードとドンをすべてアクティブに）、ドロー1枚、ドン!!2枚（ドンデッキに残りがあるだけ）を自動で行う。間違えたときは「戻る」で取り消す。ヘッダーは「先攻 nターン目」の形（手番のプレイヤーごとに数える。`GameState.activePlayerTurnCount`）。
- **視点**（`perspective`）は、画面の下にいるプレイヤー。「視点切替」と「ターン終了」（と、それを取り消す「戻る」「進む」）で切り替わる。切り替えのときは、盤面全体が回るアニメーション（先攻側→後攻側が右回り、後攻側→先攻側が左回り。前半で90°回って薄くなり、見えない間に入れ替え、後半で戻る）。入れ替え後の盤面は、入れ替え前を180°回した配置なので、回転がつながって見える（`BoardArea.spinIfNeeded`）。

#### 詳細表示とパワー・コストの変更
- 「詳細」ボタンは、**1回限りのモード**。押してから、カードをタップすると詳細（`CardDetailModal`）を開き、モードは解除される。裏向きのカード（ライフ、山札パネル内など）は表示せず、モードのまま触覚で知らせる。
- 場のリーダー・キャラを開くと、カード画像の下に変更パネル（`SoloCardEditPanel`）が出る。パワーは±1000/±5000（**マイナスまで下げられる**）、コストは±1（0まで。キャラのみ）。「元に戻す」で戻る。
- 増減は、**場を離れると自動でリセットされ、ターン終了ではリセットされない**。Undo/Redoの対象。
- 盤面のカードには、右上にパワー（リーダー・キャラ）、左上にコスト（キャラ）を表示する。パワーは「基本のパワー＋増減」に、**持ち主の手番中だけ、付与ドン1枚につき+1000**を加える（基本より増えれば赤、減れば青）。パワーが取れていないカード（0のキャラなど）は0として扱う。

#### 確認パネル（盤面の上に重ねる。背景のタップか×で閉じる）
- **山札パネル**（`SoloDeckPanel`）: 山札の上から3/4/5枚（最後に選んだ枚数を`SettingsStore.Key.soloDeckLookCount`で記憶）を裏向きで並べる。カードのタップで表裏を切り替える。「1枚追加」「全部めくる」。カードを下のタイル（手札／場に出す／デッキの上／デッキの下／ライフの上／トラッシュ）へドラッグして送る。「残りをすべてデッキの下へ」は、見ているカードを並びのまま送って、パネルを閉じる（Undoは1回分）。見ているカードは、**開いた時点の上からN枚で固定**し、取り出しても次のカードが繰り上がらない。表にした状態は、パネルの中だけで、Undoの対象外。
- **トラッシュパネル**（`SoloTrashPanel`）: 並び順を「落ちた順」（既定。新しいカードが先頭）と「同名まとめ・一覧順」（同名を揃え、カード一覧と同じ発売順。`CardReleaseOrder`）で切り替える。タイル（トラッシュを除く5つ）と「閉じる」タイルがある。

#### Undo / Redo
盤面全体（`GameState`）のスナップショットを積む方式（個々の操作を逆再生する方式ではない）。操作が成功して**実際に盤面が変わったときだけ**積む（置けない場所へのドロップなどは履歴に残らない）。上限は300。マリガンまでの準備、パネル内の表裏、詳細モードは対象外。

#### データモデル
- `PlayerBoard`: `leader`、`characterSlots`（5スロット、空きは`nil`）、`stage`、`hand`、`deck`、`life`、`trash`、`donDeck`（枚数）、`costDon`（`DonCard`の配列。1枚ずつ`id`とレスト状態を持つ）。`deck`と`life`は先頭が一番上、`trash`は先頭が一番新しい。付与ドンは、`CardInstance.attachedDon`の枚数で持つ（付与中のドンは、個別のレスト状態を持たない）。
- `CardInstance`: `Card`はカード番号がIDなので、同じカードを複数枚持つデッキでは区別できない。そこで、1枚ごとに`UUID`を振り、レスト・表裏・付与ドン・パワー/コストの増減を持たせた。
- 盤面を変える操作は、`SoloPlayViewModel`の`apply`を通す（Undo履歴の管理と、変化の判定をここで行う）。ドロップの振り分けは`SoloPlayViewModel.performDrop`。
- `SoloPlayViewModel`の`init`は、`DeckStore`を**必須引数**で受け取る（デフォルト引数で新しい`DeckStore`を作らない）。

#### ファイル

| ファイル | 役割 |
|---|---|
| `SoloPlayView` / `SoloPlayViewModel` / `SoloPlayViewModel+Detail` | 画面の切り替え・操作バー、状態と操作、詳細モード |
| `SoloDragItem` | ドラッグの中身（`SoloDragItem`）、ドロップ先（`SoloDropTarget`）、触覚（`SoloHaptics`） |
| `Deck+SoloPlay` | 一人回しで使えるデッキの判定、ライフ値の表示文字列 |
| `Components/BoardArea` | 盤面全体、背景色、回転アニメーション、カード幅の計算、山札・ライフの上/下の確認 |
| `Components/PlayerBoardView` / `BoardCardView` | 1人分の盤面、盤面上のカード1枚の見た目（レスト・付与ドン・パワー・コスト） |
| `Components/SoloHandView` / `SoloDropZone` | 手札、ドロップ先の共通部品 |
| `Components/SoloDeckPanel` / `SoloTrashPanel` / `SoloPanelDropTiles` | 山札パネル、トラッシュパネル、パネル下のドロップ先タイル |
| `Components/SoloCardEditPanel` | パワー・コストの変更パネル |
| `Components/SoloDeckSelectionView` / `SoloDeckPickerSheet` / `SoloMulliganView` | デッキ選択、デッキの選択シート、マリガン |
| `Shared/Components/CardBackImage` | 同梱画像（`CardBack`/`DonFront`/`DonBack`）を、カードと同じ枠で表示 |

#### 設計判断
- **「拡大」ではなく「詳細」ボタンにした**。長押しはドラッグの持ち上げと、ダブルタップはレストのタップと競合し、意図せず開いてしまったため。操作バーを増やさず、変更パネルも同じ画面に載せた。
- **ドラッグ&ドロップは、独自の`DragGesture`ではなくiOS標準を使う**。横スクロールの手札や、他の操作との両立を優先した。ドロップ可否は置いた瞬間に判定する。
- **盤面の配置は、画面の幅と高さに収めるため、3段目を縮めている**。縮める量は`PlayerBoardView.bottomRowScale`で一元管理している。
- 山札のシャッフル、手札の並び替え、勝敗の判定は、必要ないという判断で作っていない。

### 5.5 ④ 設定（継承）

画面モード（ライト/ダーク/システム）、カードリストのデフォルト並び順、一人回しの効果音トグル、バージョン表示、プライバシーポリシー/利用規約リンク（ダミーURL）。画面モードは`RootView`が`.preferredColorScheme`で全体に反映する。**並び順の設定と効果音の設定は、まだ使われていない**（7章）。

---

## 6. 設計判断（継承 + 確認済み）

- **モーダルは、`.sheet`ではなく、手動の`ZStack`オーバーレイ＋`.transition`**（`CardDetailModal`、`CardQuantityModal`、一人回しのパネル）。「下から出る」ではなく「その場に浮かび上がる」見た目にするため。
- **フィルタ・カード選択は、`.sheet`ではなく`.fullScreenCover`**。ただし、これは「`.sheet`のスワイプ判定のラグ」を避ける意図だった。後の調査で、体感ラグの主因はSimulatorの描画負荷だったと分かっている。`Form`を使わず`ScrollView`で組んでいる`CardSearchSheet`も同じ経緯（構成は変えていない）。
- **削除確認は`.alert`**（`.confirmationDialog`は、環境によって行の近くに出て押しにくかった）。
- **`Card.id`は、カード番号（`cardNumber`）**。パラレル版は`OP01-001_p1`のように別番号になるので、一意性は保てる。
- **`Card`は、`colors`/`attributes`（配列）が正**。`color`/`attribute`は先頭の値を返す互換用。`Card`は独自の`Codable`実装で、旧形式（`color`/`attribute`だけ）の`cards.json`も読める。`life`（リーダーのライフ値）は`cards.json`に無くても`nil`として読める。
- **カード画像は「外部取得＋キャッシュ」**。Bundle同梱だとアプリが数百MBになるため。個人利用が前提なので、**公式サイトの画像URLを直接参照**している（`ImageHost.baseURL`で一元管理）。公開する場合は、自前ホスティングを再検討する。ドン!!・カード裏面は、枚数が少ないので同梱している。
- **カードDBは、公式サイトのスクレイピングで作る**（外部APIが無いため）。`Card.packCode`は、再録カードを判定するための、カードが今収録されている弾。`CardRarity`には、`SP`・`TR`を追加している。
- **デッキ一覧の並び替えは、独自の`DragGesture`による隣接入れ替え**。「＝」ハンドルだけを起点にしたいという要件のため。
- **デッキカード選択は、タップで+1、長押しでモーダル、上部サムネイルのタップで-1**。「タップするたびに循環する」方式は、4枚の次のタップでカードが消える事故が起きやすいので採らなかった。追加できたときだけ軽く振動する（できないときは何もしない）。
- **同じカードの上限は`Deck.maxCopiesPerCard`（4）**。50枚の上限は、デッキの保存では検証していない（表示のみ）。一人回しでは、50枚のデッキだけ選べる。

---

## 7. 現在の制約・既知の課題

### 一人回し（確認済み）
- **未実装**: BGM・効果音（設定キー`enableSoundEffects`があるだけ）、詳細設定（設定タブの機能として、今後実装）。
- **意図して作っていない**: カード効果の反映、山札のシャッフル、手札の並び替え、途中保存、勝敗の判定や目印。
- **未対応**: 横向き、アクセシビリティ（VoiceOver・大きな文字サイズ）。
- ドンの総数は10枚固定（`PlayerBoard.totalDon`）。付与できるのはアクティブなドンだけ、といったルールは強制しない。
- 視点切替の回転は、「ターン終了」「戻る」「進む」でも起きる。
- 一人回しのロジック（`PlayerBoard`の移動ルール、ライフ配置など）の自動テストは、ない。

### 設定画面
- **`CardListViewModel`は`CardSearchCriteria()`をそのまま使い、`SettingsStore.Key.defaultSortKey`を読んでいない**（確認済み）。設定の「デフォルトの並び順」は、カードリストに反映されない。
- 継承: `SettingsView`の`@AppStorage`の初期値と`SettingsViewModel.sortKey(from:)`のフォールバックが`.name`で、実際のデフォルト（`.releaseOrder`）と食い違っている。今回は未確認。

### デッキ・カード（継承。今回は未再確認）
- リーダーを変更しても、追加済みの別色のカードが残る（`DeckDetailViewModel.setLeader`が整理しない）。
- ノーマルとパラレルは別カード番号なので、別カードとして数えられる（同名が、ノーマル4枚＋パラレル4枚で入る）。
- 種類の多いデッキのQRが、画像や写真から読み取れる大きさかは未検証。
- 画像の書き出しが失敗しても、画面上は何も起きない。画像プレビューは、`shareImage`への代入に`withAnimation`が無く、`.transition(.opacity)`が効かない。画像書き出し時のカード画像の取得は直列。
- `BattleHistoryView`はプレースホルダー（記録する内容が未決定）。
- Simulatorではカメラが使えず、エラー表示も未実装。
- `cards.json`から消えたカード番号は、画面に出ず、デッキからも消せない（保存ファイルには残る）。
- `BackSwipeInterceptor`は、UIKitの内部挙動（ジェスチャーのdelegate、iOS 26のKVC）に依存しており、OSの更新で変わる可能性がある。

### データ・外部依存
- **カード画像とカードデータは、公式サイトのHTML構造・画像URLに依存している**。変更されると、画像が一斉に表示されなくなったり、`fetch_cards.py`が失敗したりする（`ImageHost.baseURL`と`parse_cards`を修正）。
- `fetch_cards.py`の`packCode`は、絞り込みの表示名が`【XX-NN】`形式であることに依存する。この形式がないページ（ファミリーデッキセット・プロモーション・限定商品）は`packCode`が`nil`になり、再録とは扱われない。
- 公式のQ&A情報、効果テキストは、`cards.json`に保存していない（効果テキストは、ブロッカー/トリガーの判定にだけ使用）。
- `CardListViewModel`の読み込みエラーは、`print`のみでViewに伝わらない（TODOコメントあり）。

---

## 8. 今後の実装予定

- **一人回しのBGM・効果音**: 動作の実装が完了したあとに検討する（音源は未用意）。
- **一人回しの詳細設定**: 設定タブ内の機能として実装する予定（項目は未定）。
- **設定画面の対応**: デッキ・一人回しの実装後に行うとしていた作業で、未着手（7章の並び順の反映を含む）。
- **対戦履歴**: 記録する内容が未決定。

---

## 9. 開発時の注意点

1. **`DeckStore`と`CardRepository`は、1つのインスタンスを共有する**。画面ごとにデフォルト引数（`= DeckStore()`）で作らない（過去に、デッキ詳細で保存した内容が一覧に反映されない不具合が起きた）。`DeckListViewModel.store`を、`DeckDetailViewModel`と`SoloPlayViewModel`に渡す。`DeckDetailViewModel`と`SoloPlayViewModel`の`deckStore`引数は、デフォルトを持たない。プレビューでは、一時ファイルを指す`DeckStore`を渡す。
2. **デッキを読むときは、`await deckStore.prepare()`の後に`fetchAll()`を呼ぶ**（`prepare()`前は空）。
3. **`Card`にフィールドを足すときは、`init(from:)`/`encode(to:)`/`CodingKeys`、`fetch_cards.py`の出力、`cards.json`の再生成をセットで行う**（Swift側だけ足しても、JSONに無ければ`nil`になるだけで気づきにくい。`life`が実例）。
4. **MainActor外で使う型には`nonisolated`を付ける**（4.3）。ドラッグ&ドロップの中身（`Transferable`）の型も同様。
5. **一人回しの盤面操作は、`apply`を通す**。通さないとUndoの対象にならない。ドラッグ&ドロップの新しい受け先を足すときは、`SoloDropTarget`と`SoloPlayViewModel.performDrop`に追加する。
6. **キャラのスロットは、`characterSlots`（5つの`CardInstance?`）が正**。`characters`は、空きを除いた読み取り用の計算プロパティ。
7. **`KFImage`には`.resizable()`を付ける**（共通部品`CardThumbnailImage`を使うと漏れない）。`ImageRenderer`で描画するViewには、非同期ロードを使わず、取得済みの`UIImage`を渡す。`LazyVGrid`の中で`ForEach(... id: \.self)`をネストしない（IDが重複して描画されない要素が出る）。
8. **写真への保存は、PNGデータを`PHAssetCreationRequest.addResource`で行う**（`UIImage`渡しは、JPEG圧縮で失敗した）。
9. **色・属性は、`colors`/`attributes`（配列）で判定する**。
10. **SF Symbol名は、Xcodeの補完で実在を確認してから使う**（過去に、存在しない名前でビルドエラーが出た）。
11. **新規ファイルを追加するときは、Target Membershipを確認し、配置するフォルダを案内する**。「Cannot find 'X' in scope」の原因は、ターゲットに含まれていないことが多い。
12. **新しいOSで非推奨になったAPIを使わない**（例: `UIScreen.main`）。
13. **Simulatorで「スクロールが一瞬止まる」のは、実装のバグではなく、Simulatorの描画負荷だったことがある**。まず、実機・Releaseビルドで確認する。
14. **`Tools/fetch_cards.py`は、Xcodeのターゲットに追加しない**。
15. コード内のコメントは日本語で、「なぜその実装にしたか」を書く。View/ViewModelは`<画面名>View.swift`/`<画面名>ViewModel.swift`、プロトコルは`〜Protocol`、モック実装は`Mock〜`と名付ける。
16. **Claude向け**: Claudeはビルドできない。コンパイルエラーや警告は、ユーザーがXcodeで確認して報告する。

---

## 10. 確認できていない事項

- **今回の見直しで、ソースを直接確認していないファイル**: `OPToolkitApp.swift`、`ImageHost.swift`、`ImageCacheConfig.swift`（`configure()`が起動時に呼ばれているか）、`Card+ReleaseSort.swift`（一人回しのトラッシュパネルは、`CardReleaseOrder.sorted(_:direction:)`の呼び出し形を、`CardSearchCriteria`の使い方から推測して使っている）、`CardRepository.swift`、`SettingsView`/`SettingsViewModel`、`DeckDetail`・`DeckList`配下のほとんど、`String+Search.swift`、`CardRow.swift`。
- **Xcodeのビルド設定**: Deployment Target、Swiftの言語モード、Default Actor Isolation。
- **未使用の可能性があるもの**: `DeckCreationView`、`ShareSheet`、`DeckListViewModel.move(fromOffsets:)`、`CardRow.swift`。
- **動作確認の範囲**: 一人回しの各機能は、ユーザーがXcodeで確認済み。使用した機種やシミュレーター、iPadでの確認の有無は不明。
- **`cards.json`の最新の枚数・スキップ枚数**（リーダーのライフ値は、2〜6の範囲で取得できたとの報告のみ）。
- 対象ユーザーの要件（OPTCGのプレイヤーを想定しているが、明文化された要件は無い）。
