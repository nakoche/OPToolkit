# OPToolkit

ワンピースカードゲーム（OPTCG）向けのマルチツールアプリ。SwiftUI + MVVMで実装している。

このドキュメントは、このコードベースだけを見て別のセッション（別のClaude、あるいは別の開発者）が開発を引き継げることを目的に、実際のコードから読み取れる内容だけを記載している。憶測が入っている箇所は明示的に「要確認」と記載した。

> **追記範囲について**: 本READMEは複数のセッションにまたがって更新されている。直近のセッションでは、カード画像の取得方式（外部取得＋Kingfisherキャッシュ）、カードデータの取得方式（`Tools/fetch_cards.py`によるスクレイピング）、カードリストのデフォルト表示順（発売順）の3点を実装し、それに関する記述を追記した。このセッションでは`CardList`関連のファイルと`README.md`のみを見ており、`DeckList`/`DeckDetail`/`SoloPlay`/`Settings`関連の記述（既存のもの）は直接確認できていない点に注意。

> **最新の状態について**: その後のセッションで、デッキ機能（一覧・作成/編集・永続化・QR共有・画像書き出し）と、カードの複数色/複数属性対応を実装した。**1〜6章の記述と食い違う場合は、末尾の「7. 追記」を優先すること**（古くなった記述は7.7に一覧にしてある）。

---

## 1. プロジェクト概要

### アプリの目的・コンセプト
ワンピースカードゲームのプレイヤー向けに、以下4つの機能をまとめた「マルチツール」アプリ。

- カードリスト閲覧（検索・詳細な絞り込み）
- デッキ構築・管理（QRコードでの共有含む）
- 一人回し（対戦相手なしでの盤面シミュレーター。カード効果は反映しない）
- 各種設定

### 対象ユーザー
- OPTCGのプレイヤー（想定。要確認: 具体的なターゲット層についての明文化された要件はコード上には無い）

---

## 2. アーキテクチャ

### 設計パターン: MVVM

- 各画面は `View`（SwiftUIの`View`構造体）と `ViewModel`（`@Observable`クラス）のペアで構成される。
- `ViewModel`は`@Observable`マクロを使っている（`ObservableObject`/`@Published`は使っていない）。iOS 17以降のObservationフレームワーク前提。
- `View`側は`@State var viewModel: XxxViewModel`という形で保持する（`@StateObject`ではない）。
- データ取得・永続化は`Services/`層のプロトコル経由で行い、`ViewModel`は具体的な実装（`CardRepository`や`DeckStore`）ではなくプロトコル（`CardRepositoryProtocol`, `DeckStoreProtocol`）に依存する。テスト・プレビュー用に`MockCardRepository`が用意されている。

### フォルダ構成

```
OPToolkit/
├── OPToolkitApp.swift          // @main エントリーポイント
├── RootView.swift              // TabViewで4画面をまとめるルート
│
├── Models/                     // 純粋なデータ構造のみ。ロジックを持たない
│   ├── Card.swift               // Card, CardColor, CardType, CardAttribute, CardRarity, CardBlockIcon
│   ├── Card+ReleaseSort.swift    // カードリストのデフォルト表示順（発売順）の比較ロジック（要確認: 実際の配置フォルダ）
│   ├── Deck.swift                // Deck, DeckEntry + デッキ集計用の計算プロパティ（characterCount等）
│   └── AppSettings.swift          // AppColorScheme, CardSortKey, SortDirection（CardSortKeyへの`.releaseOrder`追加が別途必要。5章参照）
│
├── Services/                    // データ取得・永続化層（ViewModelから呼ばれる）
│   ├── CardRepository.swift        // カードDB取得。Bundle同梱のcards.jsonを読み込む（Tools/fetch_cards.pyで生成）
│   ├── ImageHost.swift              // カード画像URLの組み立て（公式サイトのURLを直接参照。要確認: 実際の配置フォルダ）
│   ├── ImageCacheConfig.swift        // Kingfisherのキャッシュ上限・有効期限設定（要確認: 実際の配置フォルダ、App起動時に呼び出し済みか）
│   ├── DeckStore.swift              // デッキの保存/読込/更新/削除/並び替え（現状は全てメモリ上のみ）
│   ├── SettingsStore.swift           // @AppStorageのキーを集約
│   ├── QRCodeService.swift            // 文字列→QRコード画像生成（CoreImage）
│   └── DeckQRPayload.swift             // デッキ⇄QR文字列（JSON）の変換
│
├── Features/                    // 画面ごとにView・ViewModel・専用コンポーネントをまとめる
│   ├── CardList/                 // ①カードリスト画面
│   ├── DeckList/                  // ②デッキ一覧画面
│   ├── DeckDetail/                 // デッキ詳細・リーダー選択・デッキカード選択画面
│   ├── SoloPlay/                    // ③一人回し画面
│   └── Settings/                     // ④設定画面
│
└── Shared/                      // 複数画面で使い回すView・拡張
    ├── Components/                // FilterChip, ShareSheet
    └── Extensions/                  // String+Search（ひらがな/カタカナを区別しない検索）

Tools/                            // Xcodeターゲットには含めない補助スクリプト
└── fetch_cards.py                  // 公式カードリストからcards.jsonを生成するスクレイパー（6章参照）
```

各`Features/<画面名>/`直下に`<画面名>View.swift`と`<画面名>ViewModel.swift`を置き、その画面専用の小さなサブViewは`Components/`サブフォルダに入れる、という規則で統一している。

### 主要な技術選定

| 技術 | 用途 | 選定理由（コード上のコメントから） |
|---|---|---|
| `@Observable`マクロ | 全ViewModel | iOS 17+のObservationフレームワークを使う前提。`ObservableObject`は使っていない |
| `ImageRenderer` | デッキ画像書き出し（`DeckImageExportView.swift`） | 外部ライブラリ無しでSwiftUI Viewをそのまま画像化するため |
| `CoreImage.CIFilterBuiltins`（`CIFilter.qrCodeGenerator`） | QRコード生成（`QRCodeService.swift`） | 外部ライブラリ不要でiOS標準機能のみで完結するため |
| `AVFoundation`（`AVCaptureSession`等） | QRコード読み取り（`QRScannerView.swift`） | 同上、外部ライブラリ不要 |
| `Photos`（`PHPhotoLibrary`） | デッキ画像の写真ライブラリ保存（`DeckImagePreviewModal.swift`） | 旧`UIImageWriteToSavedPhotosAlbum`は成否を確実に取得できなかったため、成功/失敗をハンドラで判定できる`PHPhotoLibrary`に切り替えた経緯がある（3参照） |
| `Kingfisher`（SPM） | カード画像の非同期取得・メモリ/ディスクキャッシュ（`CardImageCell.swift`） | カード画像が2000枚以上あり、標準の`AsyncImage`にはディスクキャッシュが無いため大量スクロール時に再ダウンロードが発生する。ディスクキャッシュ・ダウンサンプリング・プリフェッチが標準搭載されているKingfisherを採用した |
| 外部パッケージ | Kingfisherのみ | 上記以外はSwiftUI/UIKit/AVFoundation/Photos/CoreImageなど標準フレームワークのみで構成されている |

---

## 3. 画面・機能構成

### RootView（`RootView.swift`）
`TabView`で以下4画面をまとめる。設定で選んだ表示モード（ライト/ダーク/システム）を`.preferredColorScheme`でアプリ全体に反映する。

### ① カードリスト画面（`Features/CardList/`）
- `CardListView`: 1行5枚のグリッド表示（`LazyVGrid`）。画面下部固定フッターに「カード名・番号」検索欄と、フィルタボタン（`camera.filters`アイコン）を配置。
- タップしたカードは`CardDetailModal`で全画面オーバーレイ表示（`.sheet`ではなく手動のZStackオーバーレイ＋フェード/スケールのtransition。背景タップ・下部中央のバツボタン・上下左右のドラッグで閉じられる）。
- フィルタ・並び替えは`CardSearchSheet`（`.fullScreenCover`で表示）にまとめてあり、検索条件は`CardSearchCriteria`という1つの構造体で保持する。色・種別・特徴・コスト・パワー・属性・カウンター・レアリティ・ブロックアイコン・並び替えの全項目をここで持つ。
- `CardSearchSheet`は`Form`を使わず`ScrollView`+自前レイアウトで組んである（後述の設計判断を参照）。
- `lockedColors`パラメータを持ち、非nilの場合は色フィルタを固定して変更不可にできる（デッキカード選択画面から利用）。

### ② デッキ一覧画面（`Features/DeckList/`）
- `DeckListView`: 各デッキを1行表示。左にリーダー画像、右上にデッキ名、右下に「対戦履歴」「画像作成」「コピー」の3アイコン。行右端に並び替え用ハンドル（`equal`アイコン、ドラッグで隣接入れ替え）。
- 左スワイプで削除（`.alert`による確認。キャンセルが左・削除が右に並ぶよう`.cancel`/`.destructive`roleを利用）。
- 右下に「デッキ作成」（＋）と、その上に「QRから作成」の2つのフローティングボタン。
- 画像作成: `DeckImageExportView`＋`DeckImageExporter.makeImage(for:)`でQR付きの1枚画像を生成し、`DeckImagePreviewModal`で表示・保存できる。
- QR読み込み: `QRScannerView`（AVFoundationのカメラスキャナー）で読み取った文字列を`DeckQRPayload.decode`→`resolve(using:)`でデッキに復元し保存する。
- `BattleHistoryView`: 対戦履歴画面。**現状はプレースホルダーのみ**（後述）。

### デッキ詳細・関連画面（`Features/DeckDetail/`）
- `DeckDetailView`: リーダー表示、デッキカード表示（サムネイル＋枚数）、デッキ名編集、保存ボタン、デッキ情報（項目ごとに独立したボックス表示）、コスト別棒グラフ（0〜10、水位表現、10枚でMAX）、特徴別枚数リスト、メモ欄。
  - `.toolbar(.hidden, for: .tabBar)`でこの画面以降タブバーを隠す。
  - 新規作成時（`isNew == true`）のみリーダー選択ボタンが表示される。
- `LeaderSelectView`: リーダーカードのみのグリッド。フィルタボタンなし。検索欄＋色フィルタ＋パラレル表示切替（星アイコン、3状態: ノーマルのみ/混在/パラレルのみ、初期は混在）を画面下部に配置。カードタップで即座にリーダーとして選択される。
- `DeckCardSelectView`: リーダー以外のカードのグリッド。色フィルタはリーダーの色に固定（`CardSearchSheet`の`lockedColors`機能を利用）。カードタップで`CardQuantityModal`（-/数字(最大4)/+/デッキに追加）を表示。**1枚選ぶたびに画面を閉じずに開いたままにしてあり**、画面上部に現在デッキに入っているカードのサムネイルをプレビュー表示する（詳細は決定事項の章を参照）。

### ③ 一人回し画面（`Features/SoloPlay/`）
- `SoloPlayView`/`SoloPlayViewModel`。カード効果は反映しない前提の盤面シミュレーター。
- 盤面全体を`GameState`としてスナップショットし、操作のたびに`undoStack`/`redoStack`に積む方式でUndo/Redoを実現（個々の操作を逆再生する方式ではない）。
- 実装済み操作: 1つ戻る/進む、ドロー、ターン終了、視点切替、その他メニュー（盤面リセット、マリガンは未実装）。
- 盤面表示（`BoardArea`）は統計バッジ（デッキ枚数・ライフ・ドン・手札）のみで、場のカード表示は未実装のプレースホルダー。

### ④ 設定画面（`Features/Settings/`）
- 画面モード（ライト/ダーク/システム）、カードリストのデフォルト並び順、一人回しの効果音トグル、バージョン表示、プライバシーポリシー/利用規約リンク（ダミーURL）。

### 画面遷移関係
```
RootView (TabView)
├─ CardListView
│   └─ CardDetailModal（オーバーレイ）/ CardSearchSheet（fullScreenCover）
├─ DeckListView
│   ├─ DeckDetailView（NavigationStack push, タブバー非表示）
│   │   ├─ LeaderSelectView（fullScreenCover, 新規作成時のみ）
│   │   └─ DeckCardSelectView（fullScreenCover）
│   │       └─ CardSearchSheet（fullScreenCover, 色固定）
│   ├─ BattleHistoryView（NavigationStack push）
│   └─ QRScannerView（fullScreenCover）
├─ SoloPlayView
└─ SettingsView
```

---

## 4. これまでの決定事項・設計判断

コード中のコメントや、実装の変遷から読み取れる主な判断。

- **`Form`を使わずカスタム`ScrollView`でフィルタシートを組んでいる**（`CardSearchSheet.swift`）。当初は「`Form`＝`UITableView`のタップ/スクロール判定待ちが原因」と推測してこの構成にしたが、後の調査でこれはSimulatorの描画負荷が主因だったことが判明している（実機では問題なかった）。**構成自体は変更していない**が、これが唯一の理由ではない点は把握しておくこと。
- **`.sheet`ではなく`.fullScreenCover`を多用している**（`CardSearchSheet`, `LeaderSelectView`, `DeckCardSelectView`, `QRScannerView`など）。理由は「`.sheet`は下スワイプで閉じるジェスチャー認識器が常駐しており、`.interactiveDismissDisabled(true)`にしても判定処理自体は残ってしまう」ため。ただしこれも上記と同様、実際の体感ラグの主因はSimulatorの負荷だった可能性がある。
- **カード詳細・カード枚数モーダルは`.sheet`/`.fullScreenCover`を使わず、手動のZStackオーバーレイ＋`.transition`で実装**（`CardDetailModal`, `CardQuantityModal`）。「下から出るモーダル」ではなく「その場にふっと浮かび上がる」見た目にするため。閉じ方は背景タップ／下部中央のバツボタン／全方向ドラッグ（一定距離を超えると閉じる）の3通り。
- **デッキ一覧の削除確認は`.confirmationDialog`から`.alert`に変更した**。`.confirmationDialog`は環境によって行の近く（画面上部寄り）に表示されて押しにくいことがあったため。`.alert`は画面中央付近に出て、`.cancel`ロールのボタンが自動的に左、`.destructive`が右に並ぶ。
- **`DeckListViewModel`と`DeckDetailViewModel`は同じ`DeckStore`インスタンスを共有する必要がある**（`DeckListViewModel.store`を通じて明示的に渡している）。過去に別々の`DeckStore()`をデフォルト引数で生成してしまい、「デッキ詳細で保存したのに一覧に反映されない」という不具合が実際に発生した。**新しい画面を追加する際、`DeckStore`や`CardRepository`をデフォルト引数`= DeckStore()`のまま使うと同様の事故が起きるので注意**。
- **デッキカード選択画面は「1枚選ぶたびに画面を閉じる」仕様から「画面を開いたまま何枚でも選べる」仕様に変更した**。最初は`CardQuantityModal`で確定すると`DeckDetailViewModel.isShowingCardSelect = false`が呼ばれて毎回デッキ詳細に戻っていたが、この行を削除し、代わりに画面上部にプレビュー（追加済みカードのサムネイル＋枚数）を表示し、ユーザーが「完了」ボタンを押すまで画面を開いたままにする方式に変更した。
- **デッキ一覧の並び替えは、SwiftUI標準の`.onMove`（`List`の編集モード）ではなく、独自の`DragGesture`による隣接入れ替え方式を採用**。理由は「ハンバーガーメニューの2本バージョンのハンドルを行の右端に置き、それだけをドラッグ操作の起点にしたい」という要件があり、標準の並び替えハンドル（3本線、行全体がドラッグ起点になる）ではカスタマイズできなかったため。
- **QRコードにはデッキの全データではなく、カード番号＋枚数のみ（`DeckQRPayload`）を載せている**。カードDBの全内容を載せると情報量が増えすぎるため、読み込み側は`CardRepository`からカード番号を引いて実体（`Card`）を復元する設計。
- **SF Symbol名は必ずXcodeの補完で実在を確認してから使うこと**。過去に`funnel.fill`（存在しない）や`line.2.horizontal`（存在しない）を提示してビルドエラーになったことがある。現在使用しているシンボルは`camera.filters`（フィルタボタン）、`equal`（並び替えハンドル）、`line.3.horizontal.decrease.circle.fill`など、実在確認済みのもの。
- **`UIScreen.main`は使わない**（iOS 26で非推奨）。`DeckImageExporter`の`ImageRenderer.scale`は固定値`3`にしている。
- **写真ライブラリへの保存は`PHPhotoLibrary`＋`.addOnly`権限を使用**。`UIImageWriteToSavedPhotosAlbum`は保存の成否を確実に検知できなかったため切り替えた経緯がある。
- **カード画像は「外部取得＋キャッシュ」方式に決定**（`ImageHost.swift`, `CardImageCell.swift`）。カード枚数が2000枚以上あり、Bundle同梱だとアプリサイズが数百MB〜になるためBundle同梱案は不採用。個人利用専用アプリ（配布しない）という前提のもと、自前のCDN/ストレージは用意せず、**公式サイト（`www.onepiece-cardgame.com`）の画像URLを直接参照**している。`ImageHost.baseURL`で参照先を一元管理しており、URLパターンが変わった場合はここだけ直せばよい。画像の取得・キャッシュには`Kingfisher`を使用（技術選定の章を参照）。
  - **要確認**: この方式は個人利用が前提。今後アプリを公開する可能性が出てきた場合は、著作権・利用規約の観点から自前ホスティングへの切り替えを再検討する必要がある。
- **`Card.id`をUUIDからカード番号ベース（`var id: String { cardNumber }`）に変更した**。UUIDのままだと、実データ（JSON）に`id`が存在しないためデコードできない、かつ起動のたびにIDが変わりデッキ保存等での参照が壊れる、という2つの問題があったため。パラレル版は`cardNumber`自体が`"OP01-001_p1"`のように別番号になるので一意性は保たれる。
- **カードDBの実データは、公式カードリストページ（`https://www.onepiece-cardgame.com/cardlist/`）を`Tools/fetch_cards.py`でスクレイピングして`cards.json`を生成し、Bundle同梱してCardRepositoryが読み込む方式に決定**。外部APIは存在しないため選択肢から除外。スクリプトの詳細・実行方法は6章を参照。
- **カードリストのデフォルト表示順を「発売順」に決定**（`Card+ReleaseSort.swift`, `CardSortKey.releaseOrder`）。並び順は次の優先順位: ①弾の種類（`OP`→`EB`→`PRB`→`ST`→その他） ②同じ種類の中では番号が新しい方が先 ③同じ弾の中ではその弾オリジナルのカードが先、過去弾からの再録カードは末尾（元の弾が古い方から昇順） ④番号順 ⑤ノーマルが先・パラレルが後 ⑥パラレルが複数ある場合はレアリティが低い方が先。単純な1キー比較では表現できないため、`Comparable`な専用キー構造体（`CardReleaseOrder.Key`）を作って比較している。
  - **要確認**: パラレル同士の並びに使っているレアリティ序列（`CardRarity.rarityRank`: `C<UC<R<SR<SEC<L<P<SP<TR`）は実用上の仮置き。実際のゲーム内の並びと一致するか未検証。
  - **要確認**: 「その他」カテゴリ（プロモ、ファミリーデッキセット、限定商品収録カード）の表示位置（現状は`ST`より後ろ）が要件と合っているか未確認。
- **カードが「今収録されている弾」を判定するため、`Card`に`packCode`フィールドを追加した**。`cardNumber`の接頭辞（例: `"OP01-001"`→`"OP01"`）は「カードが最初に収録された弾」を表すが、再録カードは別の弾のページにも掲載されるため、これだけでは「今どの弾に収録されているか」を判定できない。`fetch_cards.py`が実際にスクレイピングしたページ（弾）を`packCode`として保持し、`cardNumber`の接頭辞と食い違う場合を「再録」と判定している。
- **`CardRarity`に`SP`・`TR`を追加した**。公式サイトの実データをスクレイピングした際、当初のenumに無いレアリティ表記（`SPカード`＝Special、`TR`＝Treasure Rare）が見つかったため。他にも未対応のレアリティが見つかる可能性があり、その場合は`fetch_cards.py`実行時のログに「未対応のレアリティ」として出力される。

### あえて採用しなかった案
- リーダー選択・デッキカード選択画面で「カードをタップしたら`CardDetailModal`のように拡大表示してから選択する」という2段階方式は採用せず、**タップ＝即選択（リーダー）／タップ＝枚数モーダルを開く（デッキカード）**という1段階の方式にした。「カード一覧画面と同じ構成の画面を表示」という要件との解釈の分かれ目であり、選択画面としての操作数を優先した。**要確認: この解釈でよいか、実際の要件と食い違う可能性がある**。

### 暫定実装（今後変更される可能性がある点）
- デッキの永続化は一切なく、**アプリを再起動するとデッキデータが消える**（`DeckStore`はメモリ上の配列のみ）。カードDBは`cards.json`（Bundle同梱、`Tools/fetch_cards.py`で生成）を読み込む形に変わったため、こちらは再起動しても消えない。
- カード画像は`CardImageCell.swift`（カードリストのグリッド表示）のみ`KFImage`＋`card.imageURL`（公式サイトの画像URLを`ImageHost.swift`で組み立て）に置き換え済み。**`CardDetailModal.swift`（カード拡大表示）は本セッションの対象外で未着手のまま**、`Image(imageName)`という実在しないローカルアセット参照のプレースホルダーが残っている（ビルドは通るが画像は表示されない状態のはず。要確認）。`CardRow.swift`（現状どの画面からも呼ばれていない可能性がある。使用箇所を要確認）も同様に未着手。
- `BattleHistoryView`は遷移先が存在するだけの空画面。

---

## 5. 未実装・既知の課題

### TODOコメントが残っている箇所（コードから抽出）
- `CardListViewModel.swift`: カード読み込み失敗時のエラー状態をViewに伝える仕組みが無い（現状は`print`のみ）。
- `DeckStore.swift`: `FileManager`でのJSON永続化 or `SwiftData`への差し替えが必要（現状は`save`/`update`/`delete`/`reorder`いずれも「TODO: ディスクへの反映」でメモリ操作のみ）。
- `CardSortKey`（`AppSettings.swift`）: `.releaseOrder`ケースが未追加。本セッションでは`CardSearchCriteria.swift`側に`.releaseOrder`を参照する処理を先に実装したが、`AppSettings.swift`自体は本セッションで共有されなかったため、ケースの追加がまだ反映されていない可能性が高い。**`CardSearchSheet`の並び替えPicker、`SettingsView`の「カードリストのデフォルト並び順」設定など、`CardSortKey.allCases`を参照している箇所全てで表示・動作を確認すること。**
- `Tools/fetch_cards.py`: 実行結果（`cards.json`）を実機・Simulatorで最終確認できていない（本セッション内ではダミーHTMLでのロジック検証のみ）。特に2000枚以上を全件取得した際のパース漏れ・スキップ枚数を確認すること。
- `QRScannerView.swift`: カメラが使えない場合（Simulator等）のエラー表示が未実装。
- `SettingsViewModel.swift`: バージョン番号をBundleから取得する処理はあるが、他の値の集約は今後の課題として明記。
- `SoloPlayViewModel.swift` / `SoloPlayView.swift`: ドロー時に実カードを手札に追加する処理が未実装（`hand.append(...)`はコメントのみ）。マリガン処理も未実装。盤面要素（ドン・キャラエリア等）は仮の`PlayerBoard`構造体のみで、実際のカード配置UI（`BoardArea`）は未実装。

### 既知の制約・注意点
- `card.feature`（"／"区切りの複数タグ）など、一部フィールドのフォーマットは実データ（`fetch_cards.py`が生成する`cards.json`）とサンプルデータで揃えてあるが、全項目を突き合わせた網羅的な検証はできていない。
- **カード画像URL・カードデータの取得は、公式サイト（`www.onepiece-cardgame.com`）のHTML構造・画像URLパターンに依存している。** サイトのリニューアルやURL変更があると、画像が一斉に表示されなくなったり、`Tools/fetch_cards.py`のスクレイピングが失敗したりする（`ImageHost.baseURL`と`fetch_cards.py`のパーサー部分〈`parse_cards`関数〉を要修正）。個人利用前提の実装であり、利用規約上の位置づけも含めて要注意。
- `Tools/fetch_cards.py`の`packCode`抽出は、絞り込み選択肢の表示名が`【XX-NN】`という括弧付き表記であることに依存している。この表記を持たないページ（ファミリーデッキセット・プロモーションカード・限定商品収録カードの3ページ）は`packCode`が`nil`になり、`cardNumber`の接頭辞にフォールバックする（再録扱いにはならない）。
- デッキ一覧の行は「タップで詳細遷移」「右端ハンドルでドラッグ並び替え」「左スワイプで削除」「3アイコンボタン」が同一行内に同居しており、実機でのジェスチャー競合が起きていないか未検証（コード上の実装は競合を避ける設計にしてあるが、実機での網羅的な動作確認はしていない）。
- Info.plistへの以下のキー追加はコード側では自動化できないため、**手動での追加が必須**（未追加の場合、該当機能はクラッシュまたは無反応になる）:
  - `NSCameraUsageDescription`（QRコード読み取り用）
  - `NSPhotoLibraryAddUsageDescription`（デッキ画像の保存用）
- 要確認: 対応OSバージョン（Deployment Target）がどこに設定されているかはXcodeプロジェクト側の設定でありコードからは確認できない。会話内では「iOS 26」「Xcode 26.3」という発言があったが、プロジェクト設定ファイル自体は本リポジトリに含まれていない。

---

## 6. 開発時の注意点

### 踏んではいけない前提・ハマりどころ
1. **`DeckStore`や`CardRepository`のインスタンスを画面ごとにデフォルト引数で新規生成しないこと。** 同じデータを共有する必要がある画面同士（例: `DeckListViewModel`と`DeckDetailViewModel`）は、必ず片方が持つインスタンスをもう片方に明示的に渡すこと（`DeckListView`が`viewModel.store`を`DeckDetailViewModel`に渡している箇所を参照）。
2. **SF Symbol名は必ずXcode上で実在を確認してから使うこと。** 過去に存在しないシンボル名（`funnel.fill`, `line.2.horizontal`）を使ってビルドエラーを出した実績がある。
3. **新規ファイル追加時はXcodeのTarget Membershipを必ず確認すること。** 過去に「Cannot find 'X' in scope」というエラーが、ファイル自体は存在するのにXcodeプロジェクトに追加されていない（＝ターゲットに含まれていない）ことが原因で発生している。
4. **`UIScreen.main`など、新しいOSバージョンで非推奨になったAPIを使わないこと。** 会話内でiOS 26での非推奨警告が実際に発生している。
5. Simulatorでの「スクロールが一瞬止まってから動き出す」ような操作感の問題は、**実装のバグではなくSimulator自体の描画負荷が原因だったことが判明している**。同様の体感異常が出た場合、まずSimulatorの`Slow Animations`設定やビルド構成（Debug/Release）、実機での再現有無を先に確認すること。
6. **`Tools/fetch_cards.py`はXcodeのターゲットに追加しないこと。** アプリに同梱すべきなのは、このスクリプトの実行結果である`cards.json`のみ。
7. **`Card`に新しいフィールドを追加する場合、`cards.json`の再生成（`fetch_cards.py`側の対応する項目の追加）とセットで行うこと。** 現状`Card`は`Codable`でJSONと1対1対応しており、Swift側だけ増やしてもJSONに無ければ単に`nil`/デフォルト値になるだけで気づきにくい。

### cards.jsonの生成方法（`Tools/fetch_cards.py`）
公式カードリスト（`https://www.onepiece-cardgame.com/cardlist/`）から`cards.json`を生成するスクリプト。初回のみ`pip3 install requests beautifulsoup4`が必要。

```
cd Tools
python3 fetch_cards.py              # 全弾を取得（数分かかる。デフォルトで1.5秒間隔を空ける）
python3 fetch_cards.py --series 550101   # 特定の弾だけ取得（動作確認用）
python3 fetch_cards.py --offline    # 取得済みHTML（Tools/raw_html/）だけを使ってJSONを作り直す
python3 fetch_cards.py --refresh    # キャッシュを無視して再取得
```

生成された`cards.json`をXcodeプロジェクトに追加し、アプリ本体のTarget Membershipにチェックを入れる。実行後に表示される「検出したパック」「スキップ」件数のログで、想定通りに取得できているか確認すること。公式サイトのHTML構造が変わった場合は`parse_cards`関数・`pack_code_from_label`関数の修正が必要になる。

### 命名規則・コーディング規約（コードから読み取れるもの）
- View: `<画面名>View.swift`、ViewModel: `<画面名>ViewModel.swift`という1対1の命名。
- 画面専用の小さなサブViewは`Components/`サブフォルダに格納。
- Enumの命名は「Card」を接頭辞に統一（`CardColor`, `CardType`, `CardAttribute`, `CardRarity`, `CardBlockIcon`）。
- プロトコル名は実装名+`Protocol`（`CardRepositoryProtocol`, `DeckStoreProtocol`）。テスト/プレビュー用実装は`Mock`+実装名（`MockCardRepository`）。
- コード内コメントは日本語で、「なぜこの実装にしたか」という設計意図を残す書き方が徹底されている（本READMEの「決定事項」章は主にこれらのコメントから抽出した）。
- `Models/`配下は算出プロパティ（例: `Deck.characterCount`など）を除き、ロジックを持たせない方針。

---

## 要確認リスト（このコードだけでは判断できない事項）

- ターゲットとするiOSの最低バージョン（Deployment Target）の正式な値。
- デッキ・設定の永続化方式（`FileManager`でのJSON保存か、`SwiftData`か、他の方法か）は未決定でTODOコメントのみ。
- リーダー選択・デッキカード選択画面でのカードタップ挙動（拡大表示を挟むかどうか）が、実際の要件と一致しているか。
- 対戦履歴画面（`BattleHistoryView`）で記録すべきデータ構造（勝敗、使用デッキ、対戦相手情報など）。
- Info.plistの`NSCameraUsageDescription`・`NSPhotoLibraryAddUsageDescription`が実際に追加済みかどうか（会話内でユーザーに追加を依頼したが、完了確認は取れていない）。
- `ImageCacheConfig.configure()`が実際に`OPToolkitApp.init()`（またはそれに相当する起動時処理）から呼び出されているか。呼び出されていない場合、Kingfisherのキャッシュ上限・有効期限はデフォルト値のまま動作する。
- カードリスト表示順序の「その他」カテゴリ（プロモ等、`【XX-NN】`形式の弾コードを持たないカード）を`ST`より後ろに置く現在の仕様でよいか。
- `Tools/fetch_cards.py`で全件（2000枚以上）取得した際の最終的な枚数・スキップ枚数・重複解決の結果が、実際のカードDBと一致しているか（本READMEの記載時点でユーザーが実行した際は4987枚・スキップ0枚だったが、その後のパック略号抽出の修正〈`D02`→`ST14`〉を反映した再実行結果は未確認）。


---

## 7. 追記: デッキ機能の実装・改善セッション（最新状態）

> このセクションは、デッキ一覧・デッキ作成/編集・QR共有・デッキ画像の書き出し・カードの複数色/複数属性対応を実装・改善したセッションの内容をまとめたもの。
> **1〜6章と食い違う場合は、このセクションを優先すること。**
>
> 記載の根拠について: 実際に共有・編集したコード、および会話内でユーザーが報告したビルド結果・実機/Simulatorでの確認結果に基づく。共有されなかったファイルの中身は推測せず、「要確認」（7.8）に挙げた。このセッションでは、Claude側でSwiftのビルドは行えず、全変更はユーザーがXcodeでビルドして確認した。確認の範囲は各項目に記載している。

### 7.1 プロジェクト概要（変更点）

- アプリの目的・対象ユーザー・「個人利用のみで公開しない」という前提は、1章から変更なし。
- このセッションの範囲: **②デッキ一覧画面とその関連画面（デッキ詳細・リーダー選択・デッキカード選択）、QRコードでのデッキ共有、デッキ画像の書き出し、デッキの永続化、カードの複数色/複数属性対応**。
- このセッションで**未着手**: ③一人回し画面、④設定画面の修正、対戦履歴画面（`BattleHistoryView`はプレースホルダーのまま）。設定画面と一人回しは、ユーザーが「デッキ一覧の後に進める」と明言している。

### 7.2 アーキテクチャ（追加・変更点）

設計パターン（MVVM、`@Observable`、ViewModelはプロトコルに依存）は1章から変更なし。

#### 追加・変更したファイルと役割

> フォルダは、このセッション内で案内した配置先。実際にXcodeのどのグループに置いたかは、ファイル名のみ共有されパスは見ていないため**要確認**（7.8）。

| ファイル | 配置先 | 区分 | 役割 |
|---|---|---|---|
| `DeckStore.swift` | `Services/` | 変更 | デッキの永続化（JSONファイル）。`prepare()`でカードDBと突き合わせて復元 |
| `StoredDeck.swift` | `Services/` | 新規 | デッキの保存形式（カード番号＋枚数）。`DeckStoreFile`（version付き）も定義 |
| `CardRepository.swift` | `Services/` | 変更 | `cards.json`の読み込み。デコード結果をプロセス内で共有キャッシュ |
| `DeckQRPayload.swift` | `Services/` | 変更 | デッキ⇄QR文字列。短い独自形式（`OPTK1`）。旧JSON形式も読める |
| `QRImageDecoder.swift` | `Services/` | 新規 | 写真に写ったQRコードの読み取り（Vision、フォールバックでCIDetector） |
| `CardThumbnailImage.swift` | `Shared/Components/` | 新規 | カード画像を2.5:3.5の枠いっぱいに表示する共通サムネイル（`KFImage`＋`.resizable()`＋クリップ） |
| `BackSwipeInterceptor.swift` | `Shared/Components/` | 新規 | 左端スワイプでの「戻る」を、変更があるときだけ止めて確認を出すためのUIKitブリッジ |
| `Card.swift` | `Models/` | 変更 | `colors: [CardColor]`、`attributes: [CardAttribute]`（配列）。独自の`Codable`実装 |
| `Deck.swift` | `Models/` | 変更 | `Deck.maxCopiesPerCard`（=4）追加。`featureCounts`の同数時の並び順を固定 |
| `CardSearchCriteria.swift` | `Features/CardList/`（要確認） | 変更 | 色・属性フィルタを「どれか1つでも持っていればOK（OR）」に |
| `DeckListView` / `DeckListViewModel` | `Features/DeckList/` | 変更 | 読み込み状態、保存エラー通知、画像生成中表示、QR読み込み時の同名回避 |
| `DeckDetailView` / `DeckDetailViewModel` | `Features/DeckDetail/` | 変更 | レイアウト変更、保存ボタン、変更検知＋戻る確認、保存エラー処理 |
| `DeckCardSelectView` / `DeckCardSelectViewModel` | `Features/DeckDetail/` | 変更 | タップ追加/長押しモーダル/上部プレビュー、複数色のロック |
| `LeaderSelectViewModel` | `Features/DeckDetail/` | 変更 | 色フィルタをOR判定に |
| `CardQuantityModal` | `Features/DeckDetail/` | 変更 | 0枚にして外せる、レイアウト調整 |
| `DeckImageExportView`（`DeckImageExporter`含む）/ `DeckImagePreviewModal` | `Features/DeckList/`または`DeckDetail/`（要確認） | 変更 | デッキ画像の書き出しと、PNGでの写真保存 |
| `QRScannerView` | 同上（要確認） | 変更 | 「画像から（デフォルト）」と「カメラ」の切り替え、読み取り枠の表示 |
| `RootView.swift` | ルート | 変更 | 4画面すべてのViewModelを`@State`で1回だけ保持 |
| `Tools/fetch_cards.py` | `Tools/` | 変更 | 色・属性をすべて採用、特徴の区切りを`/`と`／`のみに |

#### 技術選定（追加分）

| 技術 | 用途 | 選定理由 |
|---|---|---|
| JSONファイル（`FileManager`、`Application Support/OPToolkit/decks.json`） | デッキの永続化 | 7.4「デッキの永続化」参照。SwiftData等を採用しなかった理由もそこに記載 |
| `Vision`（`VNDetectBarcodesRequest`）＋`CoreImage`（`CIDetector`） | 写真からのQR読み取り | 外部ライブラリ不要。Visionで見つからなければCIDetectorで再試行 |
| `PhotosUI`（`PhotosPicker`） | 写真の選択 | 写真ライブラリへの権限が不要 |
| `Photos`（`PHAssetCreationRequest`＋`addResource(.photo, data:)`） | デッキ画像の保存（PNG） | `UIImage`を渡す方式だとJPEG圧縮で失敗したため（7.4） |
| `AVFoundation`（`rectOfInterest`） | カメラでのQR読み取りを、画面中央の枠の中に限定 | 枠の外のQRを読まないため |
| `Kingfisher`（`KingfisherManager.retrieveImage`） | 画像書き出しの前に、カード画像を事前取得 | `ImageRenderer`は非同期ロードを待たないため（7.4） |
| `SwiftUI`の`sensoryFeedback` | 触覚フィードバック | iOS 17以降。追加/削除/モーダル表示で使用 |
| `onGeometryChange` | 追加済みカード領域の高さの測定 | 枚数（行数）に合わせて高さを伸ばすため |
| UIKit連携（`UINavigationController`のジェスチャー） | 左端スワイプでの戻りの検知 | SwiftUIに公式APIが無いため。壊れやすい点は7.5・7.6 |

#### 並行処理（アクター隔離）について

- ビルド時の警告（`Main actor-isolated static method ... cannot be called from outside of the actor`）から、**このプロジェクトのDefault Actor IsolationはMainActorに設定されている可能性が高い**（Xcodeのビルド設定そのものは未確認。要確認）。
- そのため、バックグラウンドで動かしたい型・メソッドには、明示的に`nonisolated`を付ける必要がある。実例: `QRImageDecoder`の3メソッド、`Card`の`init(from:)`/`encode(to:)`。

### 7.3 画面・機能構成（現状）

#### ② デッキ一覧画面（`DeckListView`）
- 画面表示時に`.task { await viewModel.load() }`で保存済みデッキを復元する。復元前は`ProgressView`を表示し、復元後にデッキが0件なら「デッキがありません」を表示する（`hasLoaded`で切り替え）。
- 各行（`DeckRow`）: 左にリーダー画像、右上にデッキ名、右下に「対戦履歴」「画像作成」「コピー」。行右端の「＝」ハンドルのドラッグで並び替え、左スワイプで削除（`.alert`で確認）。
- 右下のフローティングボタン: 「＋」（デッキ作成）と、その上に「QRから作成」。
- 保存系の失敗（コピー・削除・並び替え・QR作成）は、「保存できません」のアラートで通知する（`storageErrorMessage`）。
- 「画像作成」は、カード画像の取得を待つため非同期。生成中は「画像を作成中…」のインジケーターを全面に出し、連打は無視する。

#### QR読み込み画面（`QRScannerView`）
- 画面上部の切り替えで「**画像から**（デフォルト）」と「**カメラ**」を選ぶ。
  - 画像から: `PhotosPicker`で写真を選び、`QRImageDecoder`で読み取る。見つからなければ画面上にエラー文言を出す。カメラは起動しない。
  - カメラ: 切り替えたときだけ起動する。画面中央（短辺の70%の正方形）の枠の外を暗くし（黒60%）、四隅の目印と3×3のグリッドを重ねる。**読み取り対象も枠の中だけ**（`rectOfInterest`）。
- 読み取った文字列は`DeckQRPayload.decode`→`resolve(using:)`でデッキに復元する。**既存のデッキと同名なら、「デッキ名コピー1」のように番号を付ける**（`DeckListViewModel.uniqueName`、コピーボタンと同じ採番ロジックを共有）。同名が無ければ元の名前のまま。
- 写真の選択に権限は不要。カメラは`NSCameraUsageDescription`が必要。

#### デッキ詳細画面（`DeckDetailView`）
- 構成: デッキ名 → リーダー（サムネイル＋横幅いっぱいの変更ボタン。新規作成時のみ表示）→ デッキカード（サムネイル一覧＋横幅いっぱいの「デッキカードを選択する」ボタン。リーダー未選択のときは無効）→ 情報（`DeckStatsGrid`）→ コスト（`CostBarChart`）→ 特徴（`FeatureCountList`）→ メモ。
- **保存ボタン**は画面下の中央に浮かせて表示する。メモに隠れないよう、スクロール末尾に88ptの余白（`.contentMargins`）を足している。キーボードで入力中は、保存ボタンを隠す。
- **キーボード**: 入力欄以外の場所をタップするか、スクロールすると閉じる（`@FocusState`＋`onTapGesture`＋`scrollDismissesKeyboard`）。
- **戻る操作の確認**: 標準の戻るボタンは使わず（`.navigationBarBackButtonHidden(true)`）、自前の「＜ 戻る」ボタンにしている。デッキ名・リーダー・カード・メモのいずれかが保存時点から変わっているとき（`DeckDetailViewModel.hasChanges`）、「保存して戻る」「破棄して戻る」「キャンセル」の確認を出す。左端からのスワイプで戻る操作も、`BackSwipeInterceptor`で同様に確認を出す。
- 変更の判定は、デッキの中身のスナップショット（名前・リーダーのカード番号・メモ・「カード番号×枚数」の並べ替え済み一覧）の比較。カードを外して入れ直しただけでは「変更あり」にならない。保存に成功すると、スナップショットを更新する。
- 保存に失敗した場合（名前/リーダー未設定、またはディスク書き込み失敗）は、「保存できません」のアラートを出し、画面は閉じない。

#### デッキカード選択画面（`DeckCardSelectView`）
- **カード一覧のカードをタップ → 1枚追加**（上限は`Deck.maxCopiesPerCard`=4）。追加できたときだけ軽く振動する。**上限の4枚に達しているときは何もしない（振動もしない）**。
- **カードを長押し（0.4秒）→ `CardQuantityModal`を開く**（拡大＋枚数を直接指定）。開いた瞬間に、少し強めの振動（`.impact(weight: .medium)`）。閉じるときは振動しない。
- **画面上部「現在のデッキ」のサムネイルをタップ → 1枚減らす**（0枚でデッキから外れる）。追加と同じ強さで振動する。
- 画面上部の追加済みカード領域: サムネイル（幅44pt）を折り返して並べる（`LazyVGrid`＋`.adaptive`）。高さは枚数（行数）に合わせて伸び、**最大3行**を超えたら、この領域の中だけが縦にスクロールする（`maxPreviewRows = 3`）。
- ナビゲーションバーは隠している。「完了」ボタン（下の中央）とフィルタボタン（右下）は、カード一覧の上に浮かせて表示する。スクロール末尾に88ptの余白あり。**枚数モーダルの表示中は、これらを隠す**（モーダルのバツボタンと位置が重なるため）。
- 色フィルタは**リーダーの色に固定**（`lockedColors`）。リーダーが2色なら、**どちらかの色を持つカード**が対象。
- 空のときの案内文: 「カードをタップで追加／長押しで拡大・枚数指定」。

#### 枚数指定モーダル（`CardQuantityModal`）
- ステッパー（0〜4）。既にデッキに入っているカードを0枚にすると、確定ボタンが「**デッキから外す**」（赤）に変わり、押せる。元々入っていないカードが0枚のままなら、押せない。
- カード・名前・ステッパー・確定ボタンは、バツボタンの真上に寄せて配置（下側の`Spacer`は置かない）。

#### デッキ画像の書き出し（`DeckImageExportView`／`DeckImageExporter`／`DeckImagePreviewModal`）
- 幅400pt、`renderer.scale = 3`、`renderer.isOpaque = true`。カードは1行10枚。リーダーと、枚数分に展開した全カードを並べる。右上にQR（100pt）。
- `LazyVGrid`ではなく、`VStack`＋`HStack`の遅延しないレイアウトで組んでいる（7.4）。
- 書き出し前に、`KingfisherManager.shared.retrieveImage`でカード画像を取得し、`Image(uiImage:)`で描画する。取得に失敗したカードはグレーの枠になる。
- 保存は、PNGデータを`PHAssetCreationRequest`で保存する（`.addOnly`権限）。

#### カードの複数色・複数属性
- `Card.colors`（1つ以上）・`Card.attributes`（0個以上）が正。`Card.color`・`Card.attribute`は「先頭の値」を返す計算プロパティ（互換のため残している）。
- 色・属性フィルタは**どれか1つでも持っていればよい（OR）**（カードリスト、リーダー選択、デッキカード選択で共通）。

#### 画面遷移（更新）
```
RootView (TabView)
├─ CardListView
│   └─ CardDetailModal（オーバーレイ）/ CardSearchSheet（fullScreenCover）
├─ DeckListView
│   ├─ DeckDetailView（NavigationStack push、タブバー非表示、標準の戻るボタンは非表示）
│   │   ├─ LeaderSelectView（fullScreenCover、新規作成時のみ）
│   │   └─ DeckCardSelectView（fullScreenCover）
│   │       ├─ CardQuantityModal（オーバーレイ。カードの長押しで表示）
│   │       └─ CardSearchSheet（fullScreenCover、色固定）
│   ├─ BattleHistoryView（NavigationStack push。プレースホルダー）
│   ├─ QRScannerView（fullScreenCover。「画像から」/「カメラ」）
│   └─ DeckImagePreviewModal（オーバーレイ。画像作成ボタン）
├─ SoloPlayView
└─ SettingsView
```

### 7.4 これまでの決定事項・設計判断（このセッション分）

#### デッキの永続化
- **方式: JSONファイル**（`Application Support/OPToolkit/decks.json`）。`Deck`が既に`Codable`で、`DeckStoreProtocol`の各メソッドにそのまま対応でき、並び順も配列の順番で表現できる。
- **保存するのは「カード番号＋枚数」（`StoredDeck`）で、`Card`の実体は保存しない。** `Card`をそのまま保存すると、(a)`Card`に非Optionalのフィールドを足したとき保存済みデッキが全部読めなくなる、(b)`cards.json`の更新が反映されない、という問題があるため。実際に`Card`は過去にIDの形式などを変えている。
- 形式: `{ "version": 1, "decks": [ { "id", "name", "leaderCardNumber", "entries": [{ "cardNumber", "quantity" }], "memo" } ] }`。`id`（UUID）は画面遷移（`Hashable`）で使うため保存する。
- 採用しなかった案: **SwiftData / Core Data**（`@Model`はクラスで、structの`Deck`・`Hashable`な`DeckListRoute`・`DeckStoreProtocol`の大改修になり、デッキ数十個の規模では過剰。iCloud同期が必要になったら再検討）、**UserDefaults**（小さな設定値向けで不向き）。
- 読み込みの設計: ファイルは`init`で同期的に読む。`Card`への復元はカードDB（非同期）が必要なので、画面表示時に`await prepare()`を1回呼ぶ。`fetchAll()`は同期のまま（`prepare()`前は空）。
  - **永続化の正は`stored`（カード番号＋枚数）、復元済みの`decks`はその写し**。`prepare()`前に`save`等が呼ばれても、保存済みデータを壊さない。
  - `cards.json`を読めなかった場合は、デッキを復元しない（復元できないデッキを編集・保存して、カード情報を失わないため）。
  - `decks.json`がデコードできない場合は、`decks.corrupt.json`に退避してから空で始める（次の保存で上書きして消さないため）。
  - `cards.json`から消えたカード番号は、読み込み時に表示から外れるが、**保存ファイル上は残し**、そのデッキを`update`しても引き継ぐ（カードが`cards.json`に戻れば再表示される）。
  - `save`は、同じ`id`が既にあれば`update`として扱う（保存失敗後の再試行で二重に追加されないため）。
- 保存系メソッド（`save`/`update`/`delete`/`reorder`）は`throws`。失敗は`DeckStoreError.writeFailed`で、画面側がアラートで通知する。
- **`DeckDetailViewModel`の`deckStore`引数は、デフォルト値を持たない必須引数にした**。別の`DeckStore()`が書き込むと、もう一方の内容を上書きしてデッキが消える危険があるため。

#### カードDBの読み込み
- `CardRepository`は、デコード結果をプロセス内の`actor`でキャッシュする（約5000枚を、画面ごと・インスタンスごとにデコードしないため。デコードもメインスレッド外）。読み込みに失敗した場合はキャッシュしない。

#### ViewModelの保持
- `RootView`で、4画面すべてのViewModelを`@State`で保持する。`body`が再評価されるたびにViewModel（と`DeckStore`のファイル読み込み）が作り直されるのを避けるため。

#### 画像まわり
- **`KFImage`には必ず`.resizable()`を付ける**。付けないと原寸で描画され、枠からはみ出す。共通部品`CardThumbnailImage`に集約した。
- **デッキ画像の書き出しは、`KFImage`ではなく、事前取得した`UIImage`で描画する**。`ImageRenderer`は非同期ロードを待たないため、`KFImage`のままだと画像が空白になる。取得は現状**直列**（キャッシュ済みなら一瞬。QRで作ったデッキなど未キャッシュが多いと、初回は数秒かかる可能性がある。並列化は未実装）。
- **カード一覧を`LazyVGrid`＋ネストした`ForEach(0..<quantity, id: \.self)`で並べると、エントリ間でIDが重複し、後続のカードが描画されなかった**（画像にリーダーと最初の4枚しか出なかった原因）。展開したカードを10枚ずつの行に分け、遅延しないレイアウトにした。
- **写真への保存は、`UIImage`ではなくPNGデータで行う**。`UIImage`を渡す方式では、写真ライブラリ側のJPEG圧縮が失敗した（コンソールに`CMPhotoCompressionSession+JFIF err=-16990`）。PNGは劣化しないので、QRにじみの面でも有利。あわせて`ImageRenderer.isOpaque = true`にしている。
- Simulatorで保存した画像は、MacのPhotosアプリではなく、**Simulator内の写真アプリ**に入る。

#### QRコード
- **QRの中身を、JSONから短い独自形式（`OPTK1`）に変更した**。デッキ画像に小さく載るQRは、情報量が多いと細かすぎて、写真から読み取れなくなる懸念があったため。デッキ画像上のQRも72ptから100ptに拡大した。
  ```
  OPTK1
  デッキ名
  OP01-001              （リーダーのカード番号。無ければ空行）
  OP01-025:4,OP01-026:3 （カード番号:枚数 をカンマ区切り）
  ```
  読み込みは、この形式と、旧JSON形式の両方に対応（既に作成済みのQR画像も読める。ただし旧JSON形式のQRは細かく、写真からは読み取りにくい可能性がある）。
- **QR読み込みは、デフォルトを「画像から」にし、カメラは切り替えたときだけ起動する**（ユーザー要望）。カメラ権限ダイアログも、切り替えるまで出ない。
- **QRで読み込んだデッキが既存と同名の場合、「コピーN」を付ける**（ユーザー要望）。動作上は`id`（UUID）で区別されるので問題ないが、一覧で見分けにくくなるため。

#### カードの複数色・複数属性
- **`cards.json`は、`colors`・`attributes`（配列）を持つ。旧形式の`color`・`attribute`（先頭の1つ）も残してある。**`Card`のデコーダーは、旧形式だけのJSONでも読める（アプリと`cards.json`の更新順がずれても、カードDBが空にならないため）。
- 色・属性フィルタの複数選択は**OR**（ユーザーが選択）。
- デッキカード選択の色ロックは、`lockedColor`（単数）から`lockedColors`（`Set<CardColor>`）に変更。ルール上、リーダーと1色以上が一致すれば入れられるため、2色リーダーなら、どちらかの色を持つカードが対象。
- **特徴の区切りは`/`と`／`だけにした**（`split_features`）。以前の`split_multi`は「・」でも分割していたため、「ビッグ・マム海賊団」のように名前の中に「・」を含む特徴が、誤って分割されていた可能性がある。空白でも分割しない（「ONE PIECE FILM RED」のような特徴があるため）。色・属性は、`/`・`／`・`・`・空白で分割する。
- **`featureCounts`（特徴別の枚数）は、枚数が同じ場合、デッキ内で先に出てきた順に並べる**。`Dictionary`の並びは再計算のたびに変わるため、以前はメモ入力などで画面が再描画されるたびに、同数の特徴の順番が入れ替わっていた。
- `featureTags`は、前後の空白を除去し、空の要素を捨てる。

#### デッキカード選択の操作（タップ・長押し・上部プレビュー）
- 採用: **タップで+1、長押しでモーダル、上部サムネイルのタップで-1**。追加は1タップで済み、減らす操作は別の場所に分けることで、誤操作が起きにくい。
- 採用しなかった案:
  - **「タップするたびに0→1→2→3→4→0と循環する」方式**: 4枚入れたあとの次のタップで、入れたカードが消える事故が起きやすい。
  - **一覧の各カードに「－」ボタンを重ねる**: 1行5枚で、1枚あたり約70ptしかなく、押し間違えやすい。
  - **モーダルのみで枚数を指定する従来方式**: 何枚も追加するときの手数が多い。
  - **「上限（4枚）で追加できないときに振動」「51枚目を追加しようとしたときに振動」**: ユーザーが不要と判断。「追加できたときだけ振動、できないときは何もしない」が直感的、という理由。**50枚の上限チェック自体は未実装**（表示のみ）。
- 振動は、追加=軽い、削除=追加と同じ強さ（ユーザーが「同じ強さ」を選択）、モーダル表示=一段強い。
- 追加済みカード領域の高さ: **折り返して表示し、高さを枚数に合わせて伸ばし、最大3行まで**（ユーザーが選択）。採用しなかった案: 高さ固定の2段グリッド＋横スクロール（`LazyHGrid`）、縦スクロールの領域、サムネイルを小さくする、タップで展開する折りたたみ式。サムネイルの大きさは変えない（ユーザー指定）。
- **カード選択画面のボタンは、下部のバーではなく、カード一覧の上に浮かせる**（ユーザー指定）。代わりにスクロール末尾に余白を足す。

#### 戻る操作の確認
- 変更ありの状態で戻るとき、確認を出す。標準の戻るボタンは確認を挟めないので、自前の戻るボタンにした。
- 左端スワイプでの戻りは、`BackSwipeInterceptor`が`interactivePopGestureRecognizer`のdelegateを、この画面が表示されている間だけ差し替えて止める（画面が消えるとき、元のdelegateに戻す）。
- **iOS 26の「画面のどこからでも戻れる」スワイプ**（`interactiveContentPopGestureRecognizer`）は、delegateを差し替えず、**変更があるあいだだけ無効にする**（確認は出せない）。SDKのバージョンに依存しないよう、`responds(to:)`で存在を確認してから、KVCで取り出している。左端からのスワイプなら確認が出る。

#### その他
- 設定画面は、このセッションでは**変更していない**（ユーザーが「デッキ一覧と一人回しの実装後に行う」と明言）。7.5を参照。
- Info.plistの`NSPhotoLibraryAddUsageDescription`と`NSCameraUsageDescription`は、**ユーザーが追加済み**（値が空だと警告が出るため、空でない文言を入れること）。

#### 暫定実装・今後変わりうる点
- 画像書き出しの幅（400pt）。1枚あたり約32ptと小さい（実際に見て問題なしとユーザーが判断したが、画質への要望が出たら調整する）。
- 画像書き出し時のカード画像取得が直列であること。
- `BackSwipeInterceptor`が、UIKitの内部挙動（ジェスチャーのdelegate、iOS 26のKVC）に依存していること。OSの更新で挙動が変わる可能性がある。
- 保存失敗の通知は、アラートのみ（リトライの仕組みは無い）。

### 7.5 未実装・既知の課題

#### デッキまわり
- **リーダーを変更しても、すでに追加済みの別色のカードがデッキに残る**（`DeckDetailViewModel.setLeader`が`cardEntries`を整理しない）。2色リーダー対応後は、判定が「リーダーと1色以上が一致するか」になる。
- **ノーマルとパラレルは、カード番号が別（`_p1`など）なので、別カードとして数えられる**。そのため、同名カードが、ノーマル4枚＋パラレル4枚（合計8枚）で入る。
- **50枚の上限は表示（`n/50`）のみで、保存時の検証が無い**。
- `cards.json`から消えたカード番号は、画面に出ず、デッキ側から削除もできない（保存ファイルには残る。7.4）。
- QRは、種類の多いデッキでデータ量が大きくなる。短い形式にしたが、50種類近いデッキで、生成や読み取りが問題ない大きさかは**未検証**。
- 画像書き出しが失敗（nil）した場合、画面上は何も起きない。
- 画像プレビューモーダルは、`shareImage`への代入に`withAnimation`が無いため、`.transition(.opacity)`が効かない。
- `BattleHistoryView`はプレースホルダーのまま（記録する内容が未決定）。
- Simulatorではカメラが使えない（`QRScannerViewController`にTODOコメントのみ。エラー表示は未実装）。

#### カードデータ
- **公式のQ&A情報は取得していない**。`fetch_cards.py`が読む項目は、名前・番号・種類・色・レアリティ・コスト・パワー・カウンター・属性・特徴・ブロックアイコン・効果テキスト・トリガー・画像のみ。効果テキストも、ブロッカー/トリガーの判定にだけ使い、`cards.json`には保存していない。`Card`にもQ&A用のフィールドが無い。
- `Card.color`/`Card.attribute`（先頭の値）を、単一の値として使っている箇所は、2色・2属性のカードを正しく扱えない可能性がある。`.color`の使用箇所は、このセッションで共有されたファイルの範囲でしか確認できていない（7.8）。
- `Card.init`は、`colors`が空だと`precondition`で落ちる。`fetch_cards.py`は、色が読めないカードをスキップするので、現状のデータでは起きないはず。

#### 設定画面（未着手）
- **「カードリストのデフォルトの並び順」設定が、カードリストに反映されていない**。`CardListViewModel`は`CardSearchCriteria()`をそのまま使い、`SettingsStore.Key.defaultSortKey`を読んでいない（`CardListView`にも参照が無い。他の箇所での参照は要確認）。
- **`SettingsView`の`@AppStorage`の初期値と、`SettingsViewModel.sortKey(from:)`のフォールバックが`.name`で、カードリストの実際のデフォルト（`.releaseOrder`）と食い違っている**。保存値が無い初期状態で、設定画面の表示と実際のカードリストの並びがずれる。修正は、両方を`.releaseOrder`にするだけ（このセッションでは提案のみで、コードには反映していない）。

#### 一人回し（未着手）
- 1〜6章の記述（「実カードの手札追加、マリガン、盤面表示が未実装」）から変わっていない。現状の実装は、このセッションでは確認していない（7.8）。

#### その他の既知の課題
- `CardListViewModel`の読み込みエラーは、`print`のみでViewに伝わらない（既存TODO）。
- 公式サイトのHTML構造・画像URLへの依存（5章のとおり）。

### 7.6 開発時の注意点（追加分）

1. **`nonisolated`が必要な場面がある**。Default Actor IsolationがMainActorの設定だと、`enum`の`static`メソッドなどが、暗黙にMainActorになる。バックグラウンド（`Task.detached`やactorの中）から呼ぶ処理には、明示的に`nonisolated`を付けること。
2. **`DeckStore`は、必ず1つのインスタンスを共有する**。`DeckListViewModel`が持つ`store`を、`DeckDetailViewModel`に渡す。`DeckDetailViewModel`の`deckStore`はデフォルト引数なし。プレビューで使うときは、一時ファイルを指す`DeckStore`を渡す（`DeckDetailView`の`#Preview`の例を参照。実際の`decks.json`を触らないため）。
3. **デッキを保存・読み込みするときは、`await deckStore.prepare()`の後に`fetchAll()`を呼ぶ**（`DeckListViewModel.load()`が行っている）。`prepare()`の前の`fetchAll()`は空を返す。
4. **`Card`のフィールドを増やすときは、`Card`の`init(from:)`/`encode(to:)`（`CodingKeys`）も更新する**。このセッションで`Card`は独自の`Codable`実装になったため、フィールドを追加しても自動では反映されない。`fetch_cards.py`の出力、`cards.json`の再生成も必要（6章の7番と同じ）。
5. **`cards.json`の再生成は、`python3 fetch_cards.py --offline`**（キャッシュ済みHTMLのみ使用、通信不要）。実行後のサマリー（複数色・複数属性の枚数、特徴の数ごとの枚数、「・」を含む特徴の一覧）を確認すること。
6. **`KFImage`には`.resizable()`を付ける**。表示は`CardThumbnailImage`を使うと漏れない。`ImageRenderer`で描画するViewには、`KFImage`などの非同期ロードを使わず、取得済みの`UIImage`を渡すこと。
7. **`LazyVGrid`の中で`ForEach(... id: \.self)`をネストしないこと**（IDがエントリ間で重複し、描画されない要素が出る）。`ImageRenderer`で描画するViewでは、`LazyVGrid`自体も避ける。
8. **写真ライブラリへ画像を保存するときは、PNGデータを`PHAssetCreationRequest.addResource`で保存する**（`UIImage`渡しはJPEG圧縮で失敗した実績がある）。
9. **色・属性を判定するときは、`colors`/`attributes`（配列）を使う**。`color`/`attribute`は先頭の値だけを返す。
10. **同じカード（同じカード番号）の上限は`Deck.maxCopiesPerCard`**。モーダルとタップ追加で共有している。
11. **Claude側の注意**: このコードベースの変更は、Claudeがビルドできない環境で書かれることがある。コンパイルエラーや警告は、ユーザーがXcodeで確認して報告する前提。
12. **新規ファイルを追加するときは、配置するフォルダも案内する**（ユーザー要望）。Target Membershipの確認も忘れない（6章の3番）。

#### コーディング規約（追加分）
- 触覚フィードバックは、`.sensoryFeedback`（カウンターの変化をトリガーにする）で統一。
- 画面下に浮かせるボタン（「完了」「保存」）は、同じ見た目（`.borderedProminent`、幅160pt、影付き、下余白20pt）に揃え、スクロール末尾に88ptの余白を足して、コンテンツが隠れないようにする。
- コード内コメントは日本語で、「なぜその実装にしたか」を書く（既存の方針を継続）。

### 7.7 1〜6章のうち、古くなっている記述

| 場所 | 古い記述 | 現状 |
|---|---|---|
| 2章 フォルダ構成 | `DeckStore.swift`: 現状は全てメモリ上のみ | JSONファイルで永続化済み（7.4） |
| 2章 フォルダ構成 | `DeckQRPayload.swift`: デッキ⇄QR文字列（JSON） | 短い独自形式（`OPTK1`）。旧JSONも読める |
| 2章 フォルダ構成 | `Shared/Components/`: `FilterChip`, `ShareSheet` | `CardThumbnailImage`, `BackSwipeInterceptor`が追加。`Services/`にも`StoredDeck`, `QRImageDecoder`が追加 |
| 3章 デッキ一覧 | QR読み込みは`QRScannerView`のカメラスキャナー | 「画像から（デフォルト）」と「カメラ」の切り替え |
| 3章 デッキ詳細 | 保存ボタンの位置・戻る操作・ボタン配置の記述 | 7.3のとおり（保存ボタンは下に浮かせる、変更時は戻る確認を出す、選択ボタンは横幅いっぱいで各セクションの下） |
| 3章 デッキカード選択 | カードタップで`CardQuantityModal`を開く | **タップで+1、長押しでモーダル**、上部サムネイルのタップで-1 |
| 4章 暫定実装 | デッキの永続化は一切なく、再起動するとデータが消える | 永続化済み |
| 4章 暫定実装 | `CardDetailModal.swift`は`Image(imageName)`のプレースホルダーが残っている | このセッションで共有された`CardDetailModal.swift`は、`KFImage`＋`card.imageURL`を使っている（解消済み） |
| 5章 TODO | `DeckStore.swift`の永続化が必要 | 解消済み |
| 5章 TODO | `CardSortKey`に`.releaseOrder`が未追加の可能性 | `CardSearchCriteria`が`.releaseOrder`を参照した状態でビルドが通っているため、追加済み（`AppSettings.swift`自体は未確認。7.8） |
| 5章 注意点 | Info.plistのキー追加が必須（未確認） | `NSCameraUsageDescription`・`NSPhotoLibraryAddUsageDescription`ともに、ユーザーが追加済み |
| 5章 注意点 | デッキ一覧のジェスチャー競合は実機で未検証 | 実機でデッキ一覧・並び替え・削除などを操作し、問題はユーザーから報告されていない（網羅的な検証かは不明） |
| 要確認リスト | Info.plistのキーが追加済みか | 追加済み |
| 要確認リスト | 永続化方式が未決定 | JSONファイルに決定・実装済み |

### 7.8 要確認リスト（このセッションで判断できなかった事項）

- **共有されていないファイルの中身**: `OPToolkitApp.swift`、`ImageHost.swift`、`ImageCacheConfig.swift`（`configure()`が起動時に呼ばれているか）、`Card+ReleaseSort.swift`、`AppSettings.swift`、`String+Search.swift`、`SoloPlayView`およびその配下、`CardRow.swift`、`DeckStatsGrid`/`CostBarChart`/`FeatureCountList`以外の`DeckDetail/Components/`。
- **新規・変更ファイルの、Xcode上の実際のフォルダ位置**（7.2の配置先は、このセッション内で案内したもの）。
- **Xcodeのビルド設定**: Deployment Target、Swiftの言語モード、Default Actor Isolation（警告から、MainActorと推測しているだけ）。
- **未使用の可能性があるもの**: `DeckCreationView`、`ShareSheet`、`DeckListViewModel.move(fromOffsets:)`。共有されたファイルの範囲では、呼び出し元が見つからなかったが、プロジェクト全体の検索はしていない。
- **`.color`/`.attribute`を単一の値として使っている、共有されていないコード**（`Card+ReleaseSort.swift`、一人回し関連など）。`colors`/`attributes`への対応が必要か。
- **設定画面の現状**: 「デフォルトの並び順」設定が、`CardListViewModel`以外の場所で参照されているか。`SettingsView`/`SettingsViewModel`のフォールバック（`.name`）が、実際に修正されないまま残っているか。
- **一人回しの現状**（1〜6章の記述以降に変更があるか）。
- **写真保存の実機での確認**: Simulatorでの確認のみ（実機のiPhoneの写真アプリでの確認は、会話内で報告されていない）。
- **QRの大きさの限界**: 種類の多いデッキ（50種類近く）で、画像のQRが写真から読み取れるか。
- **`cards.json`の最終的な枚数・スキップ枚数**（特徴の分割ルール変更後の再生成結果。ユーザーは問題なしと報告したが、数値は共有されていない）。
- **ターゲットとするiOSの最低バージョン**（1章から変わらず未確認）。
