# RFP: grid-edit

> Generated: 2026-07-31
> Status: Draft

## 1. Problem Statement

[TableTool](https://github.com/jakob/TableTool) (Objective-C, last release
2017-07-30, last push 2020-04) is unmaintained and is likely to stop working
on the next macOS release. csv-editor (Wails v2, Go + React/TypeScript) was
built to replace it and is functionally sufficient, but because its grid is a
WebView-hosted DOM widget, scrolling inertia, IME-aware cell editing, focus
behavior, and context menus can never reach the native macOS experience.

grid-edit is a fully native CSV/TSV editor built with Swift/AppKit
(NSDocument + NSTableView) that completely replaces csv-editor. Once
grid-edit ships, csv-editor will be archived and its Windows support ends.

Target users are people who routinely work with CSV/TSV files in Japanese
encodings (UTF-8 / Shift_JIS / CP932) on macOS.

## 2. Functional Specification

### Commands / API Surface

GUI application (.app). The only required CLI behavior is responding to
`--version` (invoked by `brew test` in the Homebrew tap).

### Input / Output

- Input: local CSV/TSV files (Open / drag & drop / Open Recent)
- Output: save in the same formats, with explicit encoding and line-ending
  (LF / CRLF) selection
- Clipboard: TSV (copies are tab-separated and Excel-paste compatible;
  pasting TSV into a single cell expands across cells; shape mismatches
  raise a confirmation dialog)

### Feature baseline: full parity with csv-editor v0.2.1

- Encoding auto-detection: UTF-8 (BOM optional) / Shift_JIS / CP932
- RFC 4180 parsing (including quoted multi-line fields)
- Rectangular range selection (mouse drag / Shift+click / Shift+arrows /
  Cmd+A)
- Cell editing: IME-safe Enter, Alt+Enter for in-cell newlines
- Undo / Redo (structural changes collapse to one undo step)
- Row/column operations: insert / duplicate / move (Alt+arrows) / delete
- Find & Replace (incremental; case-sensitive / whole-cell / regex)
- Column sort (ascending / descending, multi-key, numeric vs string
  auto-detection)
- Column width drag + auto-fit, right-aligned numeric columns
- Header row on/off and header renaming
- Virtual scrolling for hundreds of thousands of rows
- Multiple windows, Open Recent (last 10), window position/size restoration
- OS dark / light theme

### Additional feature (from TableTool)

- Delimiter auto-detection: comma / tab / **semicolon** (European CSV).
  The delimiter can be explicitly selected on save for format conversion.

### Configuration

- No config file. UserDefaults + standard OS window restoration
- Open Recent uses the standard NSDocumentController mechanism

### External Dependencies

None. Fully local; no network access.

### Constraints

- Maximum file size 500 MB (inherited from csv-editor; larger files are
  refused with a clear error)

## 3. Design Decisions

### Language / framework: Swift, AppKit-first with SwiftUI accents

- The grid itself is **AppKit** (NSDocument + NSTableView + a custom
  rectangular-selection model). Cell editing rides the field editor, so IME
  behavior is OS-native (eliminating the "IME-safe Enter" battle csv-editor
  had to fight on the web side)
- NSDocument provides dirty tracking, window restoration, Open Recent, and
  multi-window behavior through standard machinery
- SwiftUI only for auxiliary UI such as settings (stable on macOS 14+)
- SwiftUI-first (DocumentGroup) was rejected: NSDocument integration is
  constrained, and NSTableView is the proven path for editing performance
  at hundreds of thousands of rows
- The CSV engine (parse / serialize / encoding, delimiter, and line-ending
  detection) is a UI-independent SPM module with unit tests (per the org's
  testability policy)

### References

- TableTool (MIT) serves as the design reference for the NSDocument
  structure and format detection. Inspired-by attribution goes in
  README / LICENSE
- csv-editor's specification and test expectations (testdata/) are reused
  as regression guarantees

### Relationship to existing tools

- Successor to csv-editor; csv-editor is archived after grid-edit ships
- Follows the same native-Swift direction as util-series GUI apps
  (url-shelf, instant-translate, etc.)

### Out of Scope

- Spreadsheet features: formulas / multiple sheets / charts / native
  xlsx / ods read-write / macros (same policy as csv-editor; use Excel,
  Numbers, or LibreOffice)
- Windows / Linux (grid-edit is macOS-only)
- Mac App Store distribution
- Row filtering / frozen panes (inherits the decision in csv-editor RFP
  Discussion Log §9)

## 4. Development Plan

### Phase 1: Core

- CSV engine SPM module: RFC 4180 parse / serialize, encoding
  auto-detection (UTF-8 / Shift_JIS / CP932), delimiter auto-detection
  (comma / tab / semicolon), line-ending detection — unit tests required
- NSDocument integration (Open / Save / Save As / dirty tracking /
  restoration)
- NSTableView grid (virtualized, hundreds of thousands of rows)
- Cell editing (field editor, IME, Alt+Enter in-cell newline)
- Rectangular range-selection model (isolated as testable pure logic)
- TSV clipboard (copy / paste expansion / shape confirmation)
- Undo / Redo (NSUndoManager)

### Phase 2: Parity

- Find & Replace, column sort, row/column operations (insert / duplicate /
  move / delete)
- Header row on/off + renaming, column auto-fit, numeric right-alignment
- Drag & drop open, Open Recent, multiple windows
- Paste shape-mismatch confirmation dialog
- Delimiter-conversion save UI

### Phase 3: Release

- README.md / README.ja.md / CHANGELOG.md / AGENTS.md
- Developer ID signing + notarization, `--version` verification
- GitHub Releases (zip) + homebrew-tap cask (arm64 prebuilt)
- Archive csv-editor with a successor notice in its README
- Umbrella submodule addition, org profile update, check-org.sh

Each phase is independently reviewable.

## 5. Required API Scopes / Permissions

None (no external services or credentials).

## 6. Series Placement

Series: util-series
Reason: same placement as csv-editor, which it replaces. util-series
already hosts GUI apps (shell-agent-v2, url-shelf, instant-translate),
keeping the series consistent.

## 7. External Platform Constraints

- macOS 14+ / Apple Silicon (arm64). Prebuilt binaries are arm64-only;
  Intel Macs build from source
- Developer ID signing + notarization required (Gatekeeper)
- Mac App Store out of scope (GitHub Releases + homebrew-tap distribution)
- No external APIs; no rate limits

---

## Discussion Log

- **Origin**: TableTool (MIT, last released 2017) will likely stop working
  on the next macOS. The initial idea was "modernize and reimplement
  TableTool", but csv-editor already exists for exactly that purpose
- **csv-editor's problem**: functionally sufficient, but the Wails
  (WebView) grid feels "web-app-like"; since the grid is a DOM-based
  custom widget, polishing has a hard ceiling short of native macOS feel
- **Final-form decision**: compared "new native + keep csv-editor",
  "full replacement", and "polish Wails"; chose **full replacement by a
  new native app** (archive csv-editor, end Windows support)
- **Name**: compared table-editor / csv-studio / grid-edit; chose
  **grid-edit** as format-agnostic and future-proof
- **Feature scope**: rejected "core-only first"; full csv-editor v0.2.1
  parity is required before declaring replacement. Semicolon delimiter
  auto-detection added (the main value of TableTool's format detection);
  arbitrary single-character delimiters deferred
- **Size cap**: 500 MB inherited. Removing the cap via mmap / lazy parsing
  was rejected as not worth the design complexity
- **Architecture**: AppKit-first + SwiftUI accents. Pure AppKit is
  redundant for auxiliary UI; SwiftUI-first (DocumentGroup) rejected due
  to NSDocument integration constraints
- **macOS floor**: 14+. The app exists to keep working on the next macOS;
  stability of SwiftUI auxiliary UI outweighs old-OS coverage
- **Series**: rejected starting in lab-series (migration overhead only);
  goes straight to util-series
