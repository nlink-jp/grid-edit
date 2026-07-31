# RFP: grid-edit

> Generated: 2026-07-31
> Status: Draft

## 1. Problem Statement

[TableTool](https://github.com/jakob/TableTool) (Objective-C, 最終リリース
2017-07-30、最終 push 2020-04) はメンテナンスが停止しており、次期 macOS で
動作しなくなる見込みが高い。その置換として開発した csv-editor (Wails v2,
Go + React/TypeScript) は機能面では十分だが、WebView 製グリッドである以上、
スクロールの慣性・IME を含むセル編集・フォーカス・コンテキストメニュー等の
操作感が macOS ネイティブに到達できない。

grid-edit は Swift/AppKit (NSDocument + NSTableView) による完全ネイティブの
CSV/TSV エディタを新規開発し、csv-editor を完全置換する。grid-edit の
リリース完了後、csv-editor はアーカイブし、Windows サポートは終了する。

対象ユーザーは、macOS 上で日本語エンコーディング (UTF-8 / Shift_JIS /
CP932) の CSV/TSV を日常的に扱うユーザー。

## 2. Functional Specification

### Commands / API Surface

GUI アプリケーション (.app)。CLI としては `--version` への応答のみ必須
(Homebrew tap の `brew test` が呼び出す)。

### Input / Output

- 入力: ローカルの CSV/TSV ファイル (Open / drag & drop / Open Recent)
- 出力: 同形式での保存 (エンコーディングと改行コード LF/CRLF を明示選択可)
- クリップボード: TSV (コピーはタブ区切り・Excel ペースト互換、単一セルへの
  TSV ペーストはセル範囲へ自動展開、形状不一致は確認ダイアログ)

### 機能ベースライン: csv-editor v0.2.1 完全 parity

- エンコーディング自動判定: UTF-8 (BOM 任意) / Shift_JIS / CP932
- RFC 4180 準拠のパース (クォート内改行を含む)
- 矩形レンジ選択 (マウスドラッグ / Shift+クリック / Shift+矢印 / Cmd+A)
- セル編集: IME-safe な Enter、Alt+Enter でセル内改行
- Undo / Redo (構造変更は 1 undo ステップに集約)
- 行・列操作: 挿入 / 複製 / 移動 (Alt+矢印) / 削除
- Find & Replace (インクリメンタル、大小区別 / 全セル一致 / 正規表現)
- 列ソート (昇順 / 降順、複数キー、数値と文字列の自動判別)
- 列幅ドラッグ変更 + auto-fit、数値列の右寄せ表示
- ヘッダ行の On/Off とヘッダ名編集
- 数十万行の仮想スクロール
- 複数ウィンドウ、Open Recent (直近 10 件)、ウィンドウ位置・サイズ復元
- OS ダーク / ライトテーマ追従

### 追加機能 (TableTool 由来)

- デリミタ自動判定: カンマ / タブ / **セミコロン** (欧州系 CSV)。
  保存時にデリミタを明示選択して変換可能。

### Configuration

- 設定ファイルなし。UserDefaults + OS 標準の状態復元 (window restoration)
- Open Recent は NSDocumentController 標準機構を使用

### External Dependencies

なし。完全ローカル動作。ネットワークアクセスなし。

### 制約

- 最大ファイルサイズ 500 MB (csv-editor から継承。超過時は明確なエラー)

## 3. Design Decisions

### 言語 / フレームワーク: Swift + AppKit 主体、SwiftUI 補助

- グリッド本体は **AppKit** (NSDocument + NSTableView + カスタム矩形選択
  モデル)。セル編集は field editor に乗ることで IME の挙動が OS ネイティブに
  なる (csv-editor で「IME-safe Enter」を web 側で再実装した苦労の解消)
- NSDocument により dirty 管理・ウィンドウ復元・Open Recent・複数
  ウィンドウが標準機構で得られる
- 設定画面等の補助 UI のみ SwiftUI (macOS 14+ 前提で安定)
- SwiftUI 主体 (DocumentGroup) を採らない理由: NSDocument 統合の制約が
  多く、数十万行グリッドの編集性能も NSTableView が確実
- CSV エンジン (パース / シリアライズ / エンコーディング・デリミタ・改行
  判定) は UI 非依存の SPM モジュールに分離し、ユニットテスト可能にする
  (org の testability 方針)

### 参照元

- TableTool (MIT) を NSDocument 構造と format detection の設計参照元と
  する。inspired-by 帰属を README / LICENSE に明記
- csv-editor の仕様・テスト期待値 (testdata/) をリグレッション担保に利用

### 既存ツールとの関係

- csv-editor の後継。リリース完了後に csv-editor をアーカイブ
- util-series の GUI アプリ群 (url-shelf, instant-translate 等) と同じ
  Swift ネイティブ路線

### Out of Scope

- スプレッドシート機能: 数式 / 複数シート / グラフ / xlsx・ods ネイティブ
  読み書き / マクロ (csv-editor と同方針。必要なら Excel / Numbers /
  LibreOffice を使う)
- Windows / Linux (grid-edit は macOS 専用)
- Mac App Store 配布
- 行フィルタ / 固定ペイン (csv-editor RFP Discussion Log §9 の判断を継承)

## 4. Development Plan

### Phase 1: Core

- CSV エンジン SPM モジュール: RFC 4180 パース / シリアライズ、
  エンコーディング自動判定 (UTF-8 / Shift_JIS / CP932)、デリミタ自動判定
  (カンマ / タブ / セミコロン)、改行コード判定 — ユニットテスト必須
- NSDocument 統合 (Open / Save / Save As / dirty 管理 / 復元)
- NSTableView グリッド表示 (仮想スクロール、数十万行)
- セル編集 (field editor、IME、Alt+Enter セル内改行)
- 矩形レンジ選択モデル (テスト可能な純粋ロジックとして分離)
- TSV クリップボード (コピー / ペースト展開 / 形状確認)
- Undo / Redo (NSUndoManager)

### Phase 2: Parity

- Find & Replace、列ソート、行・列操作 (挿入 / 複製 / 移動 / 削除)
- ヘッダ行 On/Off + ヘッダ名編集、列幅 auto-fit、数値列右寄せ
- drag & drop オープン、Open Recent、複数ウィンドウ
- ペースト形状不一致の確認ダイアログ
- デリミタ変換保存 UI

### Phase 3: Release

- README.md / README.ja.md / CHANGELOG.md / AGENTS.md 整備
- Developer ID 署名 + notarize、`--version` 応答確認
- GitHub Releases (zip) + homebrew-tap cask (arm64 prebuilt)
- csv-editor の README に後継案内を追記してアーカイブ
- umbrella submodule 追加、org profile 更新、check-org.sh 検証

各 Phase は独立してレビュー可能。

## 5. Required API Scopes / Permissions

None (外部サービス・認証情報なし)。

## 6. Series Placement

Series: util-series
Reason: 置換元 csv-editor と同じ配置。util-series には GUI アプリの実績
(shell-agent-v2, url-shelf, instant-translate 等) があり一貫する。

## 7. External Platform Constraints

- macOS 14+ / Apple Silicon (arm64)。prebuilt バイナリは arm64 のみ、
  Intel はソースビルドで対応
- Developer ID 署名 + notarize 必須 (Gatekeeper)
- Mac App Store は対象外 (GitHub Releases + homebrew-tap 配布)
- 外部 API なし、レート制限等なし

---

## Discussion Log

- **発端**: TableTool (MIT, 2017 年最終リリース) が次期 macOS で動作しなく
  なる見込み。当初「TableTool を参考にモダン化再実装」を検討したが、
  その目的の csv-editor が既に存在することを確認
- **csv-editor の問題**: 機能は十分だが Wails (WebView) 製グリッドの
  操作感が「web アプリ臭く」、macOS ネイティブの体験に到達できない。
  グリッドが DOM 製カスタムウィジェットである以上、磨いても上限がある
  という結論
- **最終形の決定**: 「新規ネイティブ + csv-editor 維持」「完全置換」
  「Wails のまま磨く」を比較し、**新規ネイティブで完全置換** (csv-editor
  アーカイブ・Windows サポート終了) を選択
- **ツール名**: table-editor / csv-studio / grid-edit を比較。ファイル
  形式非依存で将来拡張に耐える **grid-edit** を選択
- **機能範囲**: 「コアのみ先行」案を退け、csv-editor v0.2.1 完全 parity を
  達成してから置換宣言する方針。デリミタはセミコロン自動判定を追加
  (TableTool の format detection の主要価値)。任意 1 文字デリミタは見送り
- **サイズ上限**: 500 MB 継承。mmap / 遅延パースによる上限撤廃は設計
  複雑化に見合わず不採用
- **アーキテクチャ**: AppKit 主体 + SwiftUI 補助を選択。純 AppKit は補助
  UI が冗長、SwiftUI 主体 (DocumentGroup) は NSDocument 統合の制約から
  不採用
- **macOS 下限**: 14+ を選択。「次期 macOS で動くこと」が目的のアプリで
  あり、古い OS への配慮より SwiftUI 補助 UI の安定を優先
- **シリーズ**: lab-series 開始案 (安定後移籍) は移籍の手間が増えるだけ
  として util-series 直行を選択
