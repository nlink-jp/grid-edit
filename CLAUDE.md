# CLAUDE.md — grid-edit

Organization rules: https://github.com/nlink-jp/.github/blob/main/CONVENTIONS.md
Workspace rules also apply (see the parent `nlink-jp/CLAUDE.md`).

## What this is

Native macOS CSV/TSV editor (Swift, AppKit-first). Successor that fully
replaces csv-editor (Wails). **Apple Silicon, macOS 14+.** Design of record:
`docs/ja/grid-edit-rfp.ja.md` / `docs/en/grid-edit-rfp.md` — read it before
changing scope.

## Project rules

- **GridEditCore stays UI-free.** No `import AppKit` in the engine module;
  all engine logic is unit-tested pure code.
- **The AppKit field editor owns cell text input.** Native IME behavior is
  this app's raison d'être — never reimplement text input.
- **Scope is closed.** No spreadsheet features, no row filter / frozen panes,
  no Windows/Linux, no Mac App Store. These were explicitly rejected in the
  RFP; propose an ADR before revisiting.
- **Parity is measured against csv-editor v0.2.1** (its README feature list
  and testdata/ expectations).
- `make build`, never bare `swift build` outputs into the repo root;
  artifacts belong in `dist/` and `.build/`.
- `--version` must keep answering on stdout without launching the UI.
