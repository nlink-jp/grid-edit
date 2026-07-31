/// Structural row/column operations, mirroring csv-editor's reducer
/// semantics (state.ts) exactly. All operations are copy-on-write friendly:
/// take a `snapshot()` before mutating and the old row storage stays shared,
/// so undo costs one array of references, not a deep copy.
extension CSVTable {
    /// Cheap undo/redo point (CoW references, not deep copies).
    public struct Snapshot: Sendable {
        public let header: [String]?
        public let rows: [[String]]
    }

    public func snapshot() -> Snapshot {
        Snapshot(header: header, rows: rows)
    }

    public mutating func restore(_ snapshot: Snapshot) {
        header = snapshot.header
        rows = snapshot.rows
    }

    // MARK: Rows

    /// Inserts `count` empty rows (padded to the current width) at `index`.
    @discardableResult
    public mutating func insertRows(at index: Int, count: Int) -> Bool {
        guard count > 0 else { return false }
        let width = maxColumns
        let clamped = Swift.max(0, Swift.min(rows.count, index))
        rows.insert(
            contentsOf: (0..<count).map { _ in [String](repeating: "", count: width) },
            at: clamped)
        return true
    }

    @discardableResult
    public mutating func deleteRows(startIndex: Int, count: Int) -> Bool {
        guard count > 0, startIndex < rows.count, startIndex >= 0 else { return false }
        let end = Swift.min(startIndex + count, rows.count)
        rows.removeSubrange(startIndex..<end)
        return true
    }

    /// Duplicates the block and inserts the copy directly below it.
    @discardableResult
    public mutating func duplicateRows(startIndex: Int, count: Int) -> Bool {
        guard count > 0, startIndex >= 0, startIndex < rows.count else { return false }
        let end = Swift.min(startIndex + count, rows.count)
        rows.insert(contentsOf: rows[startIndex..<end], at: end)
        return true
    }

    /// Moves the block one step up or down (the displaced neighbor row hops
    /// over the block).
    @discardableResult
    public mutating func moveRows(startIndex: Int, count: Int, up: Bool) -> Bool {
        guard count > 0, startIndex >= 0 else { return false }
        let end = startIndex + count
        guard end <= rows.count else { return false }
        if up {
            guard startIndex > 0 else { return false }
            let displaced = rows.remove(at: startIndex - 1)
            rows.insert(displaced, at: end - 1)
        } else {
            guard end < rows.count else { return false }
            let displaced = rows.remove(at: end)
            rows.insert(displaced, at: startIndex)
        }
        return true
    }

    // MARK: Columns

    /// Inserts `count` empty columns at `index` in every row (rows shorter
    /// than `index` are padded first) and in the header when present.
    @discardableResult
    public mutating func insertColumns(at index: Int, count: Int) -> Bool {
        guard count > 0, index >= 0 else { return false }
        let fillers = [String](repeating: "", count: count)
        rows = rows.map { row in
            var newRow = row
            while newRow.count < index { newRow.append("") }
            newRow.insert(contentsOf: fillers, at: index)
            return newRow
        }
        if var newHeader = header {
            while newHeader.count < index { newHeader.append("") }
            newHeader.insert(contentsOf: fillers, at: index)
            header = newHeader
        }
        return true
    }

    /// Removes up to `count` columns from `startIndex` in every row that
    /// reaches them, and from the header when present.
    @discardableResult
    public mutating func deleteColumns(startIndex: Int, count: Int) -> Bool {
        guard count > 0, startIndex >= 0 else { return false }
        rows = rows.map { row in
            guard row.count > startIndex else { return row }
            var newRow = row
            newRow.removeSubrange(startIndex..<Swift.min(startIndex + count, newRow.count))
            return newRow
        }
        if var newHeader = header, newHeader.count > startIndex {
            newHeader.removeSubrange(startIndex..<Swift.min(startIndex + count, newHeader.count))
            header = newHeader
        }
        return true
    }

    /// Duplicates the column block and inserts the copy directly to its
    /// right. Short rows that don't reach the block are left untouched.
    @discardableResult
    public mutating func duplicateColumns(startIndex: Int, count: Int) -> Bool {
        guard count > 0, startIndex >= 0 else { return false }
        let insertAt = startIndex + count
        func duplicated(_ row: [String]) -> [String] {
            guard row.count > startIndex else { return row }
            var newRow = row
            var slice = Array(newRow[startIndex..<Swift.min(insertAt, newRow.count)])
            while slice.count < count { slice.append("") }
            newRow.insert(contentsOf: slice, at: Swift.min(insertAt, newRow.count))
            return newRow
        }
        rows = rows.map(duplicated)
        if let currentHeader = header {
            header = duplicated(currentHeader)
        }
        return true
    }

    /// Moves the column block one step left or right (the displaced
    /// neighbor column hops over the block). Rows are padded through the
    /// reorder, matching csv-editor.
    @discardableResult
    public mutating func moveColumns(startIndex: Int, count: Int, left: Bool) -> Bool {
        guard count > 0, startIndex >= 0 else { return false }
        let end = startIndex + count
        let width = maxColumns
        if left {
            guard startIndex > 0 else { return false }
        } else {
            guard end < width else { return false }
        }

        var order: [Int] = []
        if left {
            order.append(contentsOf: 0..<(startIndex - 1))
            order.append(contentsOf: startIndex..<end)
            order.append(startIndex - 1)
            order.append(contentsOf: end..<width)
        } else {
            order.append(contentsOf: 0..<startIndex)
            order.append(end)
            order.append(contentsOf: startIndex..<end)
            order.append(contentsOf: (end + 1)..<width)
        }
        func reorder(_ row: [String]) -> [String] {
            order.map { $0 < row.count ? row[$0] : "" }
        }
        rows = rows.map(reorder)
        if let currentHeader = header {
            header = reorder(currentHeader)
        }
        return true
    }

    /// Renames a header column (pads the header if needed).
    @discardableResult
    public mutating func renameColumn(at index: Int, to value: String) -> Bool {
        guard index >= 0 else { return false }
        var newHeader = header ?? []
        if index < newHeader.count && newHeader[index] == value { return false }
        while newHeader.count <= index { newHeader.append("") }
        newHeader[index] = value
        header = newHeader
        return true
    }
}
