/// A parsed CSV/TSV document.
/// `header` is nil when the document was parsed without a header row.
public struct CSVTable: Equatable, Sendable {
    public var header: [String]?
    public var rows: [[String]]

    public init(header: [String]? = nil, rows: [[String]] = []) {
        self.header = header
        self.rows = rows
    }

    /// The widest row's column count (0 for an empty table). Used by the UI
    /// to allocate enough column slots when rows have varying widths.
    public var maxColumns: Int {
        var max = header?.count ?? 0
        for row in rows where row.count > max {
            max = row.count
        }
        return max
    }

    /// Guarantees at least one row and one column. A 0×N or N×0 grid is a
    /// dead end for the UI — no cell can be selected, so editing, pasting
    /// and the context menus all become unreachable. Called after opening
    /// a file and after every structural operation.
    public mutating func ensureMinimumGrid() {
        if rows.isEmpty {
            rows = [[String](repeating: "", count: Swift.max(1, maxColumns))]
        } else if maxColumns == 0 {
            rows = rows.map { _ in [""] }
        }
    }
}
