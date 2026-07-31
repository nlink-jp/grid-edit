/// A cell coordinate in the data grid (0-based row and column).
public struct GridPosition: Equatable, Hashable, Sendable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

/// A rectangular cell selection: an anchor (where selection started) and a
/// focus (the active cell that extends it). The selected rectangle is the
/// bounding box of the two, matching csv-editor's selection semantics.
public struct GridSelection: Equatable, Sendable {
    public var anchor: GridPosition
    public var focus: GridPosition

    public init(anchor: GridPosition, focus: GridPosition? = nil) {
        self.anchor = anchor
        self.focus = focus ?? anchor
    }

    public var rowRange: ClosedRange<Int> {
        min(anchor.row, focus.row)...max(anchor.row, focus.row)
    }

    public var columnRange: ClosedRange<Int> {
        min(anchor.column, focus.column)...max(anchor.column, focus.column)
    }

    public var isSingleCell: Bool {
        anchor == focus
    }

    public func contains(row: Int, column: Int) -> Bool {
        rowRange.contains(row) && columnRange.contains(column)
    }

    /// Top-left corner — the paste target.
    public var origin: GridPosition {
        GridPosition(row: rowRange.lowerBound, column: columnRange.lowerBound)
    }

    public enum Direction: Sendable {
        case up, down, left, right
    }

    /// Moves the focus one step (or to the edge) and either collapses the
    /// selection to it or extends the rectangle, clamped to the grid bounds.
    public func moving(
        _ direction: Direction,
        toEdge: Bool = false,
        extending: Bool = false,
        rowCount: Int,
        columnCount: Int
    ) -> GridSelection {
        var target = focus
        switch direction {
        case .up: target.row = toEdge ? 0 : target.row - 1
        case .down: target.row = toEdge ? rowCount - 1 : target.row + 1
        case .left: target.column = toEdge ? 0 : target.column - 1
        case .right: target.column = toEdge ? columnCount - 1 : target.column + 1
        }
        target.row = Swift.max(0, Swift.min(target.row, rowCount - 1))
        target.column = Swift.max(0, Swift.min(target.column, columnCount - 1))
        return extending
            ? GridSelection(anchor: anchor, focus: target)
            : GridSelection(anchor: target)
    }

    /// The rectangular block of cell values covered by this selection.
    /// Ragged rows are padded with empty strings.
    public func block(in table: CSVTable) -> [[String]] {
        rowRange.compactMap { row in
            guard row < table.rows.count else { return nil }
            let cells = table.rows[row]
            return columnRange.map { column in
                column < cells.count ? cells[column] : ""
            }
        }
    }
}
