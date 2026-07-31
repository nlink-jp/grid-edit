# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
- TSV clipboard: quoted Excel-compatible copy, paste expansion from a
  single cell, confirmation on shape mismatch or table growth
- Undo / Redo through NSDocument's undo manager (batch edits = one step)
- Main menu with standard File/Edit shortcuts
- Project scaffold: SPM package (GridEditCore engine module + GridEdit app),
  Makefile build/sign/notarize pipeline, document-typed Info.plist,
  `--version` CLI response
- RFP (ja/en) under `docs/`
