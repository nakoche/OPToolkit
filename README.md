# Shared

複数のFeatureから使い回すView・拡張をここに置きます。

例:
- `Components/` … 例えば `CardRow` を一人回し画面（手札プレビュー等）でも使うようになったら、
  `Features/CardList/Components/CardRow.swift` からここへ昇格させてください。
- `Extensions/` … `Color+AppTheme.swift` や `View+CornerRadius.swift` のような汎用拡張。

現時点（4画面テンプレ）ではまだ複数画面をまたぐ共有コンポーネントがないため空です。
