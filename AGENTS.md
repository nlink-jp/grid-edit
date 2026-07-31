# AGENTS.md — grid-edit

## What it is

Native macOS CSV/TSV editor (Swift, AppKit-first: NSDocument + NSTableView;
SwiftUI only for auxiliary UI). Successor to csv-editor (Wails) — once
grid-edit reaches full parity with csv-editor v0.2.1 and ships, csv-editor is
archived and its Windows support ends. **Apple Silicon, macOS 14+.**

**Status:** scaffold. Build pipeline, document plumbing, and the
delimiter-detection heuristic exist; the grid UI and CSV engine proper are
Phase 1 work. Design of record:
`docs/en/grid-edit-rfp.md` / `docs/ja/grid-edit-rfp.ja.md`.

## Build / test / run

```sh
make build      # swift build -c release
make test       # swift test
make run        # swift run (debug)
make build-app  # assemble + Developer-ID sign dist/GridEdit.app
make package    # notarize + staple + zip the release asset
make brew       # generate the Homebrew cask into ../homebrew-tap
```

- `grid-edit --version` prints the version and exits before AppKit starts
  (`brew test` depends on this).
- Icon and real version can only be verified in the `.app`; bare `swift run`
  has no bundle so `AppInfo.version` falls back to `"dev"`.

## Layout

```
Package.swift               SPM manifest; GridEditCore lib + GridEdit exe + 2 test targets
Info.plist                  bundle template; ${APP_NAME}/${BUNDLE_ID}/${VERSION} substituted by make;
                            declares CSV/TSV document types → GridDocument
Makefile                    build / build-app / package / brew
Sources/GridEditCore/       UI-independent CSV engine (parse/serialize/detection). No AppKit imports.
Sources/GridEdit/           AppKit app: entry point, NSDocument subclass, (Phase 1) grid view
Tests/GridEditCoreTests/    engine unit tests
Tests/GridEditTests/        app-layer unit tests
scripts/                    vendored org templates: codesign/notarize/make-icns/brew
docs/{en,ja}/               RFP (design of record)
assets/                     AppIcon-1024.png source (not yet added)
```

## Project rules

- **GridEditCore never imports AppKit.** Parsing, serialization, encoding /
  delimiter / line-ending detection, and the selection model live here as
  pure, unit-tested logic. UI code consumes them.
- **Feature scope is the RFP.** Full csv-editor v0.2.1 parity + semicolon
  delimiter detection; 500 MB file cap. No spreadsheet features (formulas,
  sheets, charts, xlsx/ods, macros), no row filtering / frozen panes —
  these are deliberate, documented rejections; do not re-add them.
- **Cell editing must ride the AppKit field editor** — native IME behavior is
  the reason this app exists. Do not build a custom text-input path.
- **csv-editor's testdata/ is the regression baseline** for the Phase 1
  engine (same parse/serialize expectations).
- **TableTool (MIT) is a design reference** (NSDocument structure, format
  detection). Keep the inspired-by attribution in README and LICENSE.

## Gotchas

- `Info.plist` `NSDocumentClass` is `GridEdit.GridDocument`; the class is
  `@objc(GridDocument)` — keep both in sync if renaming.
- Signing: pure AppKit needs **no entitlements** — `codesign-darwin-app.sh`
  is called with the entitlements argument intentionally omitted (see
  CONVENTIONS.md §Native Swift / AppKit).
- New behaviour ships with tests, README.md + README.ja.md updated in the
  same commit, and a CHANGELOG entry (org pre-completion checklist).
