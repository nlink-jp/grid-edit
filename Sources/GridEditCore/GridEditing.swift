/// A single cell write.
public struct CellEdit: Equatable, Sendable {
    public var row: Int
    public var column: Int
    public var value: String

    public init(row: Int, column: Int, value: String) {
        self.row = row
        self.column = column
        self.value = value
    }
}

extension CSVTable {
    /// State needed to reverse an `apply(_:)` call exactly: the previous
    /// row count plus the previous contents of every touched row. Restoring
    /// exact row arrays (not just cell values) also reverts the padding
    /// that ragged-row writes introduce.
    public struct EditUndo: Equatable, Sendable {
        public var oldRowCount: Int
        public var oldRows: [(index: Int, cells: [String])]

        public static func == (lhs: EditUndo, rhs: EditUndo) -> Bool {
            lhs.oldRowCount == rhs.oldRowCount
                && lhs.oldRows.elementsEqual(rhs.oldRows, by: { $0 == $1 })
        }
    }

    /// Applies a batch of cell writes, growing the table (new rows, padded
    /// cells) as needed, and returns the state required to undo the batch.
    @discardableResult
    public mutating func apply(_ edits: [CellEdit]) -> EditUndo {
        let touched = Set(edits.map(\.row)).sorted()
        let undo = EditUndo(
            oldRowCount: rows.count,
            oldRows: touched.compactMap { index in
                index < rows.count ? (index, rows[index]) : nil
            })

        for edit in edits {
            while rows.count <= edit.row {
                rows.append([])
            }
            if rows[edit.row].count <= edit.column {
                rows[edit.row].append(
                    contentsOf: Array(repeating: "", count: edit.column - rows[edit.row].count + 1))
            }
            rows[edit.row][edit.column] = edit.value
        }
        return undo
    }

    /// Reverses a previous `apply(_:)`.
    public mutating func restore(_ undo: EditUndo) {
        if rows.count > undo.oldRowCount {
            rows.removeSubrange(undo.oldRowCount...)
        }
        for (index, cells) in undo.oldRows where index < rows.count {
            rows[index] = cells
        }
    }
}

/// Decides how a clipboard block lands on the current selection, mirroring
/// csv-editor's paste rules: the block is written from the selection's
/// top-left; a multi-cell selection whose shape differs from the block, or
/// a paste that would extend the table, requires user confirmation first.
public enum PastePlanner {
    public enum Concern: Equatable, Sendable {
        case shapeMismatch(clipRows: Int, clipColumns: Int, selectionRows: Int, selectionColumns: Int)
        case extendsTable(newRowCount: Int, newColumnCount: Int)
    }

    public struct Plan: Equatable, Sendable {
        public var edits: [CellEdit]
        public var concerns: [Concern]
        /// Selection after the paste: the pasted rectangle.
        public var pastedSelection: GridSelection
    }

    public static func plan(
        block: [[String]],
        selection: GridSelection,
        table: CSVTable
    ) -> Plan? {
        guard !block.isEmpty else { return nil }
        let clipRows = block.count
        let clipColumns = block.reduce(0) { Swift.max($0, $1.count) }
        guard clipColumns > 0 else { return nil }

        let origin = selection.origin
        let selectionRows = selection.rowRange.count
        let selectionColumns = selection.columnRange.count

        var concerns: [Concern] = []
        if !selection.isSingleCell
            && (selectionRows != clipRows || selectionColumns != clipColumns) {
            concerns.append(.shapeMismatch(
                clipRows: clipRows, clipColumns: clipColumns,
                selectionRows: selectionRows, selectionColumns: selectionColumns))
        }
        let newRowCount = Swift.max(table.rows.count, origin.row + clipRows)
        let newColumnCount = Swift.max(table.maxColumns, origin.column + clipColumns)
        if newRowCount > table.rows.count || newColumnCount > table.maxColumns {
            concerns.append(.extendsTable(
                newRowCount: newRowCount, newColumnCount: newColumnCount))
        }

        var edits: [CellEdit] = []
        for (r, clipRow) in block.enumerated() {
            for (c, value) in clipRow.enumerated() {
                edits.append(CellEdit(
                    row: origin.row + r, column: origin.column + c, value: value))
            }
        }
        return Plan(
            edits: edits,
            concerns: concerns,
            pastedSelection: GridSelection(
                anchor: origin,
                focus: GridPosition(
                    row: origin.row + clipRows - 1,
                    column: origin.column + clipColumns - 1)))
    }
}
