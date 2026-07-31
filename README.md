# grid-edit

A native macOS CSV/TSV editor, built with Swift/AppKit.

grid-edit is the successor to
[csv-editor](https://github.com/nlink-jp/csv-editor) (Wails/WebView) and the
spiritual successor to [TableTool](https://github.com/jakob/TableTool). The
grid is a real AppKit view — NSDocument + NSTableView — so scrolling, IME
input, focus, and menus behave like macOS, not like a web page.

> **Status: Phase 1 (Core) in development.** See the
> [RFP](docs/en/grid-edit-rfp.md) for the full specification and plan.

## Features (Phase 1, working today)

- Open / Save with **encoding auto-detection** (UTF-8 with or without BOM,
  Shift_JIS, CP932), RFC 4180 parsing, and **delimiter auto-detection**:
  comma / tab / **semicolon** (European CSV). Line endings (LF / CRLF)
  are detected and preserved
- Virtualized native grid (hundreds of thousands of rows) with row numbers
  and header-row column titles
- **Rectangular range selection**: mouse drag, Shift+click, Shift+arrows,
  Cmd+arrow to the edge, Cmd+A
- **Cell editing on the native text system** — Enter during Japanese IME
  composition commits the composition, never the cell; Alt+Enter inserts
  an in-cell newline; Esc cancels; Tab / Enter commit and move
- **Multi-line cells render fully**: rows grow to fit their cells'
  newlines, and the editor grows while you type
- **TSV clipboard** (Excel-compatible): copy writes quoted TSV; pasting
  into a single cell expands across cells; shape mismatches and pastes
  that would grow the table ask for confirmation first
- **Undo / Redo** for every edit, batch edits collapse to one step
- **Row & column operations** (right-click a row number or column header):
  insert above/below or left/right, duplicate, move (also Alt+arrows),
  delete — all undoable
- **Sort** (right-click a column header): ascending / descending,
  multi-key when multiple columns are selected, numeric vs string
  auto-detected per pair
- **Find & Replace** (⌘F find, ⌥⌘F replace — the macOS-native binding;
  csv-editor's Ctrl+H means Hide here): incremental search with match
  count, ⌘G / ⇧⌘G next/previous with wrap-around, case-sensitive /
  regex / whole-cell options, Replace one or All (one undo step)
- Maximum file size: 500 MB (larger files are refused with a clear error)

## Planned (Phase 2 — csv-editor parity)

Find & Replace, header renaming, column auto-fit, numeric right-align,
status bar with save-time format selection (encoding / delimiter / line
ending), Open Recent, and window-frame persistence.

By design, grid-edit is **not** a spreadsheet — no formulas, sheets, charts,
xlsx/ods, or macros. Windows and Linux are not supported.

## Requirements

- macOS 14+ / Apple Silicon (arm64); Intel Macs can build from source
- Building from source: Xcode command line tools with Swift 5.9+

## Building from source

```sh
make build      # swift build -c release
make test       # swift test
make run        # swift run (debug; --version answers without launching UI)
make build-app  # assemble + Developer-ID sign dist/GridEdit.app
make package    # notarize + staple + zip the release asset
```

## Documentation

- [RFP — full specification](docs/en/grid-edit-rfp.md)
  ([日本語](docs/ja/grid-edit-rfp.ja.md))
- [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE) © 2026 nlink-jp

Document architecture and format detection inspired by
[TableTool](https://github.com/jakob/TableTool) (MIT, © Jakob Egger).
