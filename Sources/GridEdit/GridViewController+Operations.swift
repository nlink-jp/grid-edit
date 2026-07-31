import AppKit
import GridEditCore

/// Wraps a closure so an NSMenuItem's representedObject can carry it —
/// avoids target-retain cycles from self-targeting menu items.
private final class MenuActionBox: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

/// Structural operations (rows, columns, sort) and their context menus.
extension GridViewController {
    // MARK: Menu plumbing

    @objc func runBoxedMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuActionBox)?.run()
    }

    private func item(_ title: String, run: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(
            title: title, action: #selector(runBoxedMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = MenuActionBox(run)
        return item
    }

    // MARK: Context targets

    private func fullRowSelection(_ rows: ClosedRange<Int>) -> GridSelection {
        GridSelection(
            anchor: GridPosition(row: rows.lowerBound, column: 0),
            focus: GridPosition(row: rows.upperBound, column: max(0, columnCount - 1)))
    }

    private func fullColumnSelection(_ columns: ClosedRange<Int>) -> GridSelection {
        GridSelection(
            anchor: GridPosition(row: 0, column: columns.lowerBound),
            focus: GridPosition(row: max(0, rowCount - 1), column: columns.upperBound))
    }

    /// Header body click: select the whole column; Shift+click extends the
    /// column selection from the current anchor column.
    func selectColumn(_ column: Int, extending: Bool) {
        commitEditIfNeeded()
        guard rowCount > 0 else { return }
        if extending, let current = selection {
            selection = GridSelection(
                anchor: GridPosition(row: 0, column: current.anchor.column),
                focus: GridPosition(row: max(0, rowCount - 1), column: column))
        } else {
            selection = fullColumnSelection(column...column)
        }
        view.window?.makeFirstResponder(tableView)
    }

    /// Rows the operation applies to: the selection when the click lands
    /// inside it, otherwise the clicked row (which becomes the selection).
    private func targetRows(clicked row: Int) -> ClosedRange<Int> {
        if let selection, selection.rowRange.contains(row) {
            return selection.rowRange
        }
        selection = fullRowSelection(row...row)
        return row...row
    }

    private func targetColumns(clicked column: Int) -> ClosedRange<Int> {
        if let selection, selection.columnRange.contains(column) {
            return selection.columnRange
        }
        selection = fullColumnSelection(column...column)
        return column...column
    }

    // MARK: Menus

    func contextMenu(for hit: GridTableView.GridHit) -> NSMenu? {
        commitEditIfNeeded()
        guard rowCount > 0 else { return nil }
        guard let column = hit.dataColumn else {
            return rowContextMenu(clicked: hit.row)
        }
        if !(selection?.contains(row: hit.row, column: column) ?? false) {
            selection = GridSelection(anchor: GridPosition(row: hit.row, column: column))
        }
        let menu = NSMenu()
        for (title, action) in [
            (L("Cut"), #selector(cut(_:))),
            (L("Copy"), #selector(copy(_:))),
            (L("Paste"), #selector(paste(_:))),
            (L("Clear Contents"), #selector(delete(_:))),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    private func rowContextMenu(clicked row: Int) -> NSMenu {
        let rows = targetRows(clicked: row)
        let n = rows.count
        let menu = NSMenu()
        menu.addItem(item(LPlural(n, one: "Insert Row Above", other: "Insert %d Rows Above")) {
            [weak self] in self?.insertRows(rows, above: true) })
        menu.addItem(item(LPlural(n, one: "Insert Row Below", other: "Insert %d Rows Below")) {
            [weak self] in self?.insertRows(rows, above: false) })
        menu.addItem(item(LPlural(n, one: "Duplicate Row", other: "Duplicate %d Rows")) {
            [weak self] in self?.duplicateRows(rows) })
        menu.addItem(.separator())
        menu.addItem(item(LPlural(n, one: "Move Row Up", other: "Move %d Rows Up")) {
            [weak self] in self?.moveRows(rows, up: true) })
        menu.addItem(item(LPlural(n, one: "Move Row Down", other: "Move %d Rows Down")) {
            [weak self] in self?.moveRows(rows, up: false) })
        menu.addItem(.separator())
        menu.addItem(item(LPlural(n, one: "Delete Row", other: "Delete %d Rows")) {
            [weak self] in self?.deleteRows(rows) })
        return menu
    }

    func headerContextMenu(forColumn column: Int) -> NSMenu? {
        commitEditIfNeeded()
        let columns = targetColumns(clicked: column)
        let n = columns.count
        let menu = NSMenu()
        menu.addItem(item(LPlural(n, one: "Insert Column Left", other: "Insert %d Columns Left")) {
            [weak self] in self?.insertColumns(columns, left: true) })
        menu.addItem(item(LPlural(n, one: "Insert Column Right", other: "Insert %d Columns Right")) {
            [weak self] in self?.insertColumns(columns, left: false) })
        menu.addItem(item(LPlural(n, one: "Duplicate Column", other: "Duplicate %d Columns")) {
            [weak self] in self?.duplicateColumns(columns) })
        menu.addItem(.separator())
        menu.addItem(item(LPlural(n, one: "Move Column Left", other: "Move %d Columns Left")) {
            [weak self] in self?.moveColumns(columns, left: true) })
        menu.addItem(item(LPlural(n, one: "Move Column Right", other: "Move %d Columns Right")) {
            [weak self] in self?.moveColumns(columns, left: false) })
        menu.addItem(.separator())
        menu.addItem(item(L("Sort Ascending")) { [weak self] in self?.sortByColumns(columns, ascending: true) })
        menu.addItem(item(L("Sort Descending")) { [weak self] in self?.sortByColumns(columns, ascending: false) })
        menu.addItem(.separator())
        if content.hasHeader {
            menu.addItem(item(L("Rename Column…")) { [weak self] in
                self?.beginHeaderRename(column: column)
            })
        }
        menu.addItem(item(L("Auto-fit Width")) { [weak self] in
            guard let self else { return }
            for column in columns {
                self.autoFitColumn(column)
            }
        })
        menu.addItem(.separator())
        menu.addItem(item(LPlural(n, one: "Delete Column", other: "Delete %d Columns")) {
            [weak self] in self?.deleteColumns(columns) })
        return menu
    }

    // MARK: Row operations

    func insertRows(_ rows: ClosedRange<Int>, above: Bool) {
        let at = above ? rows.lowerBound : rows.upperBound + 1
        let count = rows.count
        guard document?.performTableOperation(L("Insert Rows"), {
            $0.insertRows(at: at, count: count)
        }) == true else { return }
        selection = fullRowSelection(at...(at + count - 1))
        scrollToFocus()
    }

    func duplicateRows(_ rows: ClosedRange<Int>) {
        let count = rows.count
        guard document?.performTableOperation(L("Duplicate Rows"), {
            $0.duplicateRows(startIndex: rows.lowerBound, count: count)
        }) == true else { return }
        let start = rows.upperBound + 1
        selection = fullRowSelection(start...(start + count - 1))
        scrollToFocus()
    }

    func moveRows(_ rows: ClosedRange<Int>, up: Bool) {
        guard document?.performTableOperation(L("Move Rows"), {
            $0.moveRows(startIndex: rows.lowerBound, count: rows.count, up: up)
        }) == true else { return }
        let offset = up ? -1 : 1
        selection = fullRowSelection((rows.lowerBound + offset)...(rows.upperBound + offset))
        scrollToFocus()
    }

    func deleteRows(_ rows: ClosedRange<Int>) {
        guard document?.performTableOperation(L("Delete Rows"), {
            $0.deleteRows(startIndex: rows.lowerBound, count: rows.count)
        }) == true else { return }
        if rowCount > 0 {
            let row = min(rows.lowerBound, rowCount - 1)
            selection = fullRowSelection(row...row)
        } else {
            selection = nil
        }
    }

    // MARK: Column operations

    func insertColumns(_ columns: ClosedRange<Int>, left: Bool) {
        let at = left ? columns.lowerBound : columns.upperBound + 1
        let count = columns.count
        guard document?.performTableOperation(L("Insert Columns"), {
            $0.insertColumns(at: at, count: count)
        }) == true else { return }
        selection = fullColumnSelection(at...(at + count - 1))
    }

    func duplicateColumns(_ columns: ClosedRange<Int>) {
        let count = columns.count
        guard document?.performTableOperation(L("Duplicate Columns"), {
            $0.duplicateColumns(startIndex: columns.lowerBound, count: count)
        }) == true else { return }
        let start = columns.upperBound + 1
        selection = fullColumnSelection(start...(start + count - 1))
    }

    func moveColumns(_ columns: ClosedRange<Int>, left: Bool) {
        guard document?.performTableOperation(L("Move Columns"), {
            $0.moveColumns(startIndex: columns.lowerBound, count: columns.count, left: left)
        }) == true else { return }
        let offset = left ? -1 : 1
        selection = fullColumnSelection(
            (columns.lowerBound + offset)...(columns.upperBound + offset))
    }

    func deleteColumns(_ columns: ClosedRange<Int>) {
        guard document?.performTableOperation(L("Delete Columns"), {
            $0.deleteColumns(startIndex: columns.lowerBound, count: columns.count)
        }) == true else { return }
        if columnCount > 0 {
            let column = min(columns.lowerBound, columnCount - 1)
            selection = fullColumnSelection(column...column)
        } else {
            selection = nil
        }
    }

    // MARK: Sort

    func sortByColumns(_ columns: ClosedRange<Int>, ascending: Bool) {
        let keys = columns.map { SortKey(columnIndex: $0, ascending: ascending) }
        pendingSortIndicator = (columns, ascending)
        document?.performTableOperation(ascending ? L("Sort Ascending") : L("Sort Descending")) {
            $0.sortRows(by: keys)
        }
        // A no-op sort (already in order) skips contentDidChange — the data
        // IS in the requested order, so show the indicator directly.
        if pendingSortIndicator != nil {
            applySortIndicator(columns, ascending: ascending)
            pendingSortIndicator = nil
        }
    }

    // MARK: Alt+arrow block moves

    func moveBlock(_ direction: GridSelection.Direction) {
        guard let selection else { return }
        switch direction {
        case .up: moveRows(selection.rowRange, up: true)
        case .down: moveRows(selection.rowRange, up: false)
        case .left: moveColumns(selection.columnRange, left: true)
        case .right: moveColumns(selection.columnRange, left: false)
        }
    }

    // MARK: Header rename

    /// Inline header rename via the same NSTextView-overlay pattern as the
    /// cell editor (see AGENTS.md gotchas for why not NSTextField).
    func beginHeaderRename(column: Int) {
        guard content.hasHeader, headerEditor == nil,
              let headerView = tableView.headerView else { return }
        commitEditIfNeeded()
        let tableColumnIndex = column + 1
        guard tableColumnIndex < tableView.tableColumns.count else { return }

        let frame = headerView.headerRect(ofColumn: tableColumnIndex)
        let editor = NSTextView(frame: frame.insetBy(dx: 1, dy: 1))
        editor.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        let currentHeader = content.table.header ?? []
        editor.string = column < currentHeader.count ? currentHeader[column] : ""
        editor.delegate = self
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = true
        editor.backgroundColor = .textBackgroundColor
        editor.textContainerInset = NSSize(width: 0, height: 2)
        editor.wantsLayer = true
        editor.layer?.borderColor = NSColor.controlAccentColor.cgColor
        editor.layer?.borderWidth = 2
        headerView.addSubview(editor)
        headerEditor = editor
        headerEditingColumn = column
        view.window?.makeFirstResponder(editor)
        editor.selectAll(nil)
    }

    func endHeaderRename(commit: Bool) {
        guard let editor = headerEditor, let column = headerEditingColumn else { return }
        headerEditor = nil
        headerEditingColumn = nil
        let newValue = editor.string
        editor.removeFromSuperview()
        view.window?.makeFirstResponder(tableView)
        if commit {
            document?.performTableOperation(L("Rename Column")) {
                $0.renameColumn(at: column, to: newValue)
            }
        }
    }

    // MARK: Column auto-fit

    /// Widest content width for the column (sampled above 20k rows, like
    /// csv-editor's type inference) plus padding, clamped to sane bounds.
    func idealWidth(forColumn column: Int) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var widest = (columnTitleForMeasurement(column) as NSString)
            .size(withAttributes: attributes).width
        let rows = content.table.rows
        let stride = rows.count > 20000 ? (rows.count + 19999) / 20000 : 1
        var r = 0
        while r < rows.count {
            let row = rows[r]
            if column < row.count && !row[column].isEmpty {
                // Only the longest line of a multiline cell matters.
                let cell = row[column]
                var line = cell
                if cell.contains("\n") {
                    let parts: [Substring] = cell.split(
                        separator: "\n" as Character, omittingEmptySubsequences: false)
                    if let longest = parts.max(by: { $0.count < $1.count }) {
                        line = String(longest)
                    }
                }
                let width = (line as NSString).size(withAttributes: attributes).width
                if width > widest { widest = width }
            }
            r += stride
        }
        return min(600, max(24, widest + 12))
    }

    private func columnTitleForMeasurement(_ column: Int) -> String {
        if content.hasHeader, let header = content.table.header, column < header.count {
            return header[column]
        }
        return ""
    }

    func autoFitColumn(_ column: Int) {
        let tableColumnIndex = column + 1
        guard tableColumnIndex < tableView.tableColumns.count else { return }
        tableView.tableColumns[tableColumnIndex].width = idealWidth(forColumn: column)
    }

    /// Double-click on a column divider (NSTableView calls this delegate).
    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn columnIndex: Int) -> CGFloat {
        guard let column = Self.dataColumnIndex(of: tableView.tableColumns[columnIndex]) else {
            return tableView.tableColumns[columnIndex].width
        }
        return idealWidth(forColumn: column)
    }
}
