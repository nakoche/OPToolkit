# OPToolkit

ワンピースカードゲーム（OPTCG）向けのマルチツールアプリ。SwiftUI + MVVMで実装している。

このドキュメントは、このコードベースだけを見て別のセッション（別のClaude、あるいは別の開発者）が開発を引き継げることを目的に、実際のコードから読み取れる内容だけを記載している。憶測が入っている箇所は明示的に「要確認」と記載した。

> **追記範囲について**: 本READMEは複数のセッションにまたがって更新されている。直近のセッションでは、カード画像の取得方式（外部取得＋Kingfisherキャッシュ）、カードデータの取得方式（`Tools/fetch_cards.py`によるスクレイピング）、カードリストのデフォルト表示順（発売順）の3点を実装し、それに関する記述を追記した。このセッションでは`CardList`関連のファイルと`README.md`のみを見ており、`DeckList`/`DeckDetail`/`SoloPlay`/`Settings`関連の記述（既存のもの）は直接確認できていない点に注意。

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
 `ImageCacheConfig.configure()`が実際に`OPToolkitApp.init()`（またはそれに相当する起動時処理）から呼び出されているか。呼び出されていない場合、Kingfisherのキャッシュ上限・有効期限はデフォルト値のまま動作する。
- カードリスト表示順序の「その他」カテゴリ（プロモ等、`【XX-NN】`形式の弾コードを持たないカード）を`ST`より後ろに置く現在の仕様でよいか。
- `Tools/fetch_cards.py`で全件（2000枚以上）取得した際の最終的な枚数・スキップ枚数・重複解決の結果が、実際のカードDBと一致しているか（本READMEの記載時点でユーザーが実行した際は4987枚・スキップ0枚だったが、その後のパック略号抽出の修正〈`D02`→`ST14`〉を反映した再実行結果は未確認）。
