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
}
