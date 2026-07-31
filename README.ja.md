# grid-edit

Swift/AppKit 製のネイティブ macOS CSV/TSV エディタ。

grid-edit は [csv-editor](https://github.com/nlink-jp/csv-editor)
(Wails/WebView) の後継であり、[TableTool](https://github.com/jakob/TableTool)
の精神的後継です。グリッドは本物の AppKit ビュー — NSDocument + NSTableView —
なので、スクロール・IME 入力・フォーカス・メニューが Web ページではなく
macOS として振る舞います。

> **Status: scaffold。** プロジェクト構造・ビルドパイプライン・CSV エンジン
> モジュールは存在しますが、グリッド UI はまだありません。仕様と計画の全体は
> [RFP](docs/ja/grid-edit-rfp.ja.md) を参照してください。

## 予定機能 (RFP より)

- csv-editor v0.2.1 完全 parity: エンコーディング自動判定
  (UTF-8 / Shift_JIS / CP932)、RFC 4180 パース、矩形レンジ選択、
  IME-safe なセル編集、TSV クリップボード (ペースト展開)、Undo/Redo、
  Find & Replace、ソート、行列操作、仮想スクロール
- デリミタ自動判定: カンマ / タブ / **セミコロン** (欧州系 CSV)、
  保存時のデリミタ変換
- 最大ファイルサイズ: 500 MB

設計方針として grid-edit はスプレッドシートでは**ありません** — 数式・
シート・グラフ・xlsx/ods・マクロは実装しません。Windows / Linux は
サポートしません。

## 動作要件

- macOS 14+ / Apple Silicon (arm64)。Intel Mac はソースビルドで対応
- ソースビルド: Swift 5.9+ を含む Xcode command line tools

## ソースからのビルド

```sh
make build      # swift build -c release
make test       # swift test
make run        # swift run (デバッグ; --version は UI を起動せず応答)
make build-app  # dist/GridEdit.app を組み立てて Developer ID 署名
make package    # notarize + staple + リリース用 zip 作成
```

## ドキュメント

- [RFP — 仕様全体](docs/ja/grid-edit-rfp.ja.md)
  ([English](docs/en/grid-edit-rfp.md))
- [Changelog](CHANGELOG.md)

## ライセンス

[MIT](LICENSE) © 2026 nlink-jp

ドキュメントアーキテクチャと format detection は
[TableTool](https://github.com/jakob/TableTool) (MIT, © Jakob Egger) に
インスパイアされています。
