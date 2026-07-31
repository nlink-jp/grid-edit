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
            ("Cut", #selector(cut(_:))),
            ("Copy", #selector(copy(_:))),
            ("Paste", #selector(paste(_:))),
            ("Clear Contents", #selector(delete(_:))),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    private func rowContextMenu(clicked row: Int) -> NSMenu {
        let rows = targetRows(clicked: row)
        let noun = rows.count > 1 ? "\(rows.count) Rows" : "Row"
        let menu = NSMenu()
        menu.addItem(item("Insert \(noun) Above") { [weak self] in self?.insertRows(rows, above: true) })
        menu.addItem(item("Insert \(noun) Below") { [weak self] in self?.insertRows(rows, above: false) })
        menu.addItem(item("Duplicate \(noun)") { [weak self] in self?.duplicateRows(rows) })
        menu.addItem(.separator())
        menu.addItem(item("Move \(noun) Up") { [weak self] in self?.moveRows(rows, up: true) })
        menu.addItem(item("Move \(noun) Down") { [weak self] in self?.moveRows(rows, up: false) })
        menu.addItem(.separator())
        menu.addItem(item("Delete \(noun)") { [weak self] in self?.deleteRows(rows) })
        return menu
    }

    func headerContextMenu(forColumn column: Int) -> NSMenu? {
        commitEditIfNeeded()
        let columns = targetColumns(clicked: column)
        let noun = columns.count > 1 ? "\(columns.count) Columns" : "Column"
        let menu = NSMenu()
        menu.addItem(item("Insert \(noun) Left") { [weak self] in self?.insertColumns(columns, left: true) })
        menu.addItem(item("Insert \(noun) Right") { [weak self] in self?.insertColumns(columns, left: false) })
        menu.addItem(item("Duplicate \(noun)") { [weak self] in self?.duplicateColumns(columns) })
        menu.addItem(.separator())
        menu.addItem(item("Move \(noun) Left") { [weak self] in self?.moveColumns(columns, left: true) })
        menu.addItem(item("Move \(noun) Right") { [weak self] in self?.moveColumns(columns, left: false) })
        menu.addItem(.separator())
        menu.addItem(item("Sort Ascending") { [weak self] in self?.sortByColumns(columns, ascending: true) })
        menu.addItem(item("Sort Descending") { [weak self] in self?.sortByColumns(columns, ascending: false) })
        menu.addItem(.separator())
        menu.addItem(item("Delete \(noun)") { [weak self] in self?.deleteColumns(columns) })
        return menu
    }

    // MARK: Row operations

    func insertRows(_ rows: ClosedRange<Int>, above: Bool) {
        let at = above ? rows.lowerBound : rows.upperBound + 1
        let count = rows.count
        guard document?.performTableOperation("Insert Rows", {
            $0.insertRows(at: at, count: count)
        }) == true else { return }
        selection = fullRowSelection(at...(at + count - 1))
        scrollToFocus()
    }

    func duplicateRows(_ rows: ClosedRange<Int>) {
        let count = rows.count
        guard document?.performTableOperation("Duplicate Rows", {
            $0.duplicateRows(startIndex: rows.lowerBound, count: count)
        }) == true else { return }
        let start = rows.upperBound + 1
        selection = fullRowSelection(start...(start + count - 1))
        scrollToFocus()
    }

    func moveRows(_ rows: ClosedRange<Int>, up: Bool) {
        guard document?.performTableOperation("Move Rows", {
            $0.moveRows(startIndex: rows.lowerBound, count: rows.count, up: up)
        }) == true else { return }
        let offset = up ? -1 : 1
        selection = fullRowSelection((rows.lowerBound + offset)...(rows.upperBound + offset))
        scrollToFocus()
    }

    func deleteRows(_ rows: ClosedRange<Int>) {
        guard document?.performTableOperation("Delete Rows", {
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
        guard document?.performTableOperation("Insert Columns", {
            $0.insertColumns(at: at, count: count)
        }) == true else { return }
        selection = fullColumnSelection(at...(at + count - 1))
    }

    func duplicateColumns(_ columns: ClosedRange<Int>) {
        let count = columns.count
        guard document?.performTableOperation("Duplicate Columns", {
            $0.duplicateColumns(startIndex: columns.lowerBound, count: count)
        }) == true else { return }
        let start = columns.upperBound + 1
        selection = fullColumnSelection(start...(start + count - 1))
    }

    func moveColumns(_ columns: ClosedRange<Int>, left: Bool) {
        guard document?.performTableOperation("Move Columns", {
            $0.moveColumns(startIndex: columns.lowerBound, count: columns.count, left: left)
        }) == true else { return }
        let offset = left ? -1 : 1
        selection = fullColumnSelection(
            (columns.lowerBound + offset)...(columns.upperBound + offset))
    }

    func deleteColumns(_ columns: ClosedRange<Int>) {
        guard document?.performTableOperation("Delete Columns", {
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
        document?.performTableOperation(ascending ? "Sort Ascending" : "Sort Descending") {
            $0.sortRows(by: keys)
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
}
