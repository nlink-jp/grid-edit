# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed

- Row-number gutter is visually distinct from data cells (theme-adaptive
  gray fill; rows with selected cells get a subtle accent tint)
- The table visibly ends at its data: row stripes and grid lines no
  longer continue below the last row or right of the last column (the
  grid is now drawn per row; the area outside the data is plain canvas)

## [0.2.0] - 2026-08-01

### Added

- UI localization (English / Japanese): menus, context menus, find and
  format bars, dialogs, undo action names, and error messages follow the
  system (or per-app) language via standard `.lproj` bundles
- Header click selects the whole column (Shift+click extends); the
  divider hot zone keeps drag-resize and double-click auto-fit
- Finder-style sort indicator on the sorted columns' headers, cleared by
  any mutation that could break the order
- Cell context menu offers Insert Row Above/Below and Insert Column
  Left/Right (counts follow the selected span)

### Changed

- Edit menu now says "Clear Contents", matching the cell context menu
  (the action empties cells; it never removes rows/columns)

### Fixed

- Selection highlight reaches the vertical grid lines (was inset by the
  intercell spacing) and tracks live column resizing
- Selection highlight is suppressed while a cell editor is open
- Clicks on empty grid area commit an open cell/header editor instead
  of being ignored
- Find/format bars have fixed heights — controls are no longer clipped

## [0.1.0] - 2026-08-01

First release. Native macOS successor to
[csv-editor](https://github.com/nlink-jp/csv-editor) with full feature
parity (Phase 1 + Phase 2 of the RFP).

### Added

- CSV engine (GridEditCore): RFC 4180 parser/serializer with csv-editor
  semantics (lazy quotes, ragged rows), encoding auto-detection
  (UTF-8 / UTF-8-BOM / Shift_JIS / CP932), quote-aware delimiter detection
  (comma / tab / semicolon), line-ending detection, 500 MB open cap;
  byte-for-byte regression against csv-editor testdata
- Virtualized NSTableView grid with row numbers and header titles
- Rectangular range selection (mouse drag, Shift+click/arrows, Cmd+arrow,
  Cmd+A) and keyboard navigation
- Cell editing on the native text system (IME-safe Enter, Alt+Enter in-cell
  newline, Esc cancel, Tab/Enter commit-and-move)
- Variable row heights: rows grow to show every explicit newline in their
  cells; the cell editor grows with its content and the underlying label
  is blanked while editing (no double-drawn text)
- TSV clipboard: quoted Excel-compatible copy, paste expansion from a
  single cell, confirmation on shape mismatch or table growth
- Undo / Redo through NSDocument's undo manager (batch edits = one step)
- Row/column operations with undo: insert, duplicate, move (Alt+arrows),
  delete via row-number / column-header context menus; cell context menu
  (Cut/Copy/Paste/Clear)
- Column sort: ascending/descending from the header context menu,
  multi-key across a column selection, numeric auto-detection
  (csv-editor sort semantics)
- Find & Replace: ⌘F / ⌥⌘F bar with incremental search, match count,
  ⌘G/⇧⌘G navigation with wrap-around, case/regex/whole-cell options,
  replace one / replace all (single undo step). macOS-native bindings
  (⌥⌘F instead of csv-editor's Ctrl+H, which is Hide on macOS)
- Header renaming (double-click the header or context menu), column
  auto-fit width (divider double-click or context menu, sampled above
  20k rows), automatic right-alignment for numeric columns
- Status bar with undoable format settings (encoding, delimiter
  conversion on save, line ending) and header row toggle, plus a
  rows × cols readout
- Open Recent (AppKit-managed), drag & drop CSV/TSV onto a window to
  open, window position/size persistence with cascading
- Main menu with standard File/Edit shortcuts
- Project scaffold: SPM package (GridEditCore engine module + GridEdit app),
  Makefile build/sign/notarize pipeline, document-typed Info.plist,
  `--version` CLI response
- RFP (ja/en) under `docs/`
