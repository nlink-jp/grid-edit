# grid-edit

Swift/AppKit 製のネイティブ macOS CSV/TSV エディタ。

grid-edit は [csv-editor](https://github.com/nlink-jp/csv-editor)
(Wails/WebView) の後継であり、[TableTool](https://github.com/jakob/TableTool)
の精神的後継です。グリッドは本物の AppKit ビュー — NSDocument + NSTableView —
なので、スクロール・IME 入力・フォーカス・メニューが Web ページではなく
macOS として振る舞います。

> **Status: Phase 1 (Core) 開発中。** 仕様と計画の全体は
> [RFP](docs/ja/grid-edit-rfp.ja.md) を参照してください。

## 機能 (Phase 1、動作済み)

- **エンコーディング自動判定**付きの Open / Save (UTF-8 BOM 有無 /
  Shift_JIS / CP932)、RFC 4180 パース、**デリミタ自動判定**:
  カンマ / タブ / **セミコロン** (欧州系 CSV)。改行コード (LF / CRLF)
  も判定・保存時維持
- 行番号とヘッダ行タイトル付きの仮想化ネイティブグリッド (数十万行)
- **矩形レンジ選択**: マウスドラッグ、Shift+クリック、Shift+矢印、
  Cmd+矢印で端まで、Cmd+A
- **ネイティブテキストシステムによるセル編集** — 日本語 IME 変換中の
  Enter は変換を確定するだけでセルは確定しない。Alt+Enter でセル内改行、
  Esc でキャンセル、Tab / Enter で確定+移動
- **複数行セルの完全表示**: 行高はセル内改行数に応じて自動で伸び、
  編集中のエディタも入力に合わせて拡大
- **TSV クリップボード** (Excel 互換): コピーはクォート付き TSV。
  単一セルへのペーストはセル範囲へ自動展開。形状不一致やテーブル拡張を
  伴うペーストは事前に確認ダイアログ
- 全編集の **Undo / Redo** (バッチ編集は 1 ステップに集約)
- **行・列操作** (行番号 / 列ヘッダを右クリック): 上下/左右への挿入、
  複製、移動 (Alt+矢印でも)、削除 — すべて undo 可能
- **ソート** (列ヘッダを右クリック): 昇順/降順、複数列選択時はマルチキー、
  数値と文字列はペアごとに自動判別
- **Find & Replace** (⌘F 検索、⌥⌘F 置換 — macOS ネイティブの割り当て。
  csv-editor の Ctrl+H は macOS では Hide のため変更): インクリメンタル
  検索とマッチ数表示、⌘G / ⇧⌘G で次/前 (循環)、大小区別 / 正規表現 /
  セル全体一致オプション、1 件置換 / 全置換 (undo は 1 ステップ)
- 最大ファイルサイズ: 500 MB (超過は明確なエラーで拒否)

## 予定 (Phase 2 — csv-editor parity)

Find & Replace、ヘッダ名編集、列幅 auto-fit、数値列の右寄せ、
ステータスバーと保存時のフォーマット選択 (エンコーディング/デリミタ/改行)、
Open Recent、ウィンドウ位置記憶。

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
