import AppKit
import GridEditCore

/// Find & Replace: bar lifecycle, incremental search, navigation, replace.
extension GridViewController {
    // MARK: Menu actions (responder chain)

    @objc func performTextFinderShow(_ sender: Any?) {
        showFindBar(withReplace: false)
    }

    @objc func performTextFinderShowReplace(_ sender: Any?) {
        showFindBar(withReplace: true)
    }

    @objc func findNext(_ sender: Any?) {
        guard !findMatches.isEmpty else { return }
        let next = ((findCurrentIndex ?? -1) + 1) % findMatches.count
        jumpToMatch(at: next)
    }

    @objc func findPrevious(_ sender: Any?) {
        guard !findMatches.isEmpty else { return }
        let count = findMatches.count
        let previous = ((findCurrentIndex ?? 0) - 1 + count) % count
        jumpToMatch(at: previous)
    }

    // MARK: Bar lifecycle

    func wireFindBar() {
        findBar.isHidden = true
        findBar.onQueryChange = { [weak self] _ in self?.refreshFind(jumpToFirst: true) }
        findBar.onOptionsChange = { [weak self] _ in self?.refreshFind(jumpToFirst: true) }
        findBar.onNext = { [weak self] in self?.findNext(nil) }
        findBar.onPrevious = { [weak self] in self?.findPrevious(nil) }
        findBar.onClose = { [weak self] in self?.closeFindBar() }
        findBar.onReplaceOne = { [weak self] replacement in self?.replaceCurrent(with: replacement) }
        findBar.onReplaceAll = { [weak self] replacement in self?.replaceAll(with: replacement) }
    }

    private func showFindBar(withReplace: Bool) {
        commitEditIfNeeded()
        findBar.isHidden = false
        findBar.setReplaceVisible(withReplace)
        // Prefill from the focused cell? No — csv-editor keeps the last query.
        view.window?.makeFirstResponder(findBar.searchField)
        refreshFind(jumpToFirst: false)
    }

    func closeFindBar() {
        findBar.isHidden = true
        findMatches = []
        findCurrentIndex = nil
        view.window?.makeFirstResponder(tableView)
    }

    // MARK: Search

    /// Recomputes matches from the current query/options. Called on every
    /// keystroke in the bar and after every content change while visible.
    func refreshFind(jumpToFirst: Bool) {
        guard !findBar.isHidden else { return }
        let query = findBar.searchField.stringValue
        findMatches = Find.matches(
            query: query, options: findBar.options, rows: content.table.rows)
        if findMatches.isEmpty {
            findCurrentIndex = nil
            findBar.setMatchStatus(current: nil, total: 0)
            return
        }
        if jumpToFirst {
            jumpToMatch(at: 0)
        } else {
            findCurrentIndex = findCurrentIndex.map { min($0, findMatches.count - 1) }
            findBar.setMatchStatus(current: findCurrentIndex, total: findMatches.count)
        }
    }

    private func jumpToMatch(at index: Int) {
        guard index < findMatches.count else { return }
        findCurrentIndex = index
        let match = findMatches[index]
        selection = GridSelection(anchor: GridPosition(row: match.row, column: match.column))
        scrollToFocus()
        findBar.setMatchStatus(current: index, total: findMatches.count)
    }

    // MARK: Replace

    private func replaceCurrent(with replacement: String) {
        guard let index = findCurrentIndex, index < findMatches.count else { return }
        let match = findMatches[index]
        guard let edit = Find.replaceOneEdit(
            match: match, query: findBar.searchField.stringValue,
            replacement: replacement, options: findBar.options,
            rows: content.table.rows) else { return }
        document?.applyEdits([edit], actionName: L("Replace"))
        // contentDidChange already re-ran refreshFind; land on the match
        // that now occupies this position (the next one).
        if !findMatches.isEmpty {
            jumpToMatch(at: min(index, findMatches.count - 1))
        }
    }

    private func replaceAll(with replacement: String) {
        let edits = Find.replaceAllEdits(
            query: findBar.searchField.stringValue, replacement: replacement,
            options: findBar.options, rows: content.table.rows)
        guard !edits.isEmpty else { return }
        document?.applyEdits(edits, actionName: L("Replace All"))
    }
}
