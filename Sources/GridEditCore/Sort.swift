import Foundation

/// Column sort, ported from csv-editor's sort.ts.
public struct SortKey: Equatable, Sendable {
    public enum Mode: Sendable {
        case auto, string, number
    }

    public var columnIndex: Int
    public var ascending: Bool
    public var mode: Mode

    public init(columnIndex: Int, ascending: Bool, mode: Mode = .auto) {
        self.columnIndex = columnIndex
        self.ascending = ascending
        self.mode = mode
    }
}

public enum ColumnTyping {
    // Same acceptance as csv-editor: optional sign, digits with optional
    // fraction or bare fraction, optional exponent.
    private static let numericRegex =
        try! NSRegularExpression(pattern: #"^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$"#)

    public static func isNumericString(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return numericRegex.firstMatch(in: trimmed, range: range) != nil
    }

    /// One flag per column: true means every non-empty sampled cell is
    /// numeric (drives right-alignment only — values stay strings).
    /// Entirely-empty columns return false. Sampled above 20k rows.
    public static func inferNumericColumns(rows: [[String]], columnCount: Int) -> [Bool] {
        guard columnCount > 0 else { return [] }
        var isNumeric = [Bool](repeating: true, count: columnCount)
        var seenAny = [Bool](repeating: false, count: columnCount)
        let stride = rows.count > 20000 ? (rows.count + 19999) / 20000 : 1
        var r = 0
        while r < rows.count {
            let row = rows[r]
            for c in 0..<Swift.min(columnCount, row.count) where isNumeric[c] {
                let cell = row[c]
                if cell.isEmpty { continue }
                seenAny[c] = true
                if !isNumericString(cell) {
                    isNumeric[c] = false
                }
            }
            r += stride
        }
        for c in 0..<columnCount where !seenAny[c] {
            isNumeric[c] = false
        }
        return isNumeric
    }
}

extension CSVTable {
    /// Sorts rows by the given keys (lexicographic across keys), stably.
    /// Empty cells sort to the end ascending (and to the front descending —
    /// csv-editor parity); in auto mode two numeric cells compare
    /// numerically, otherwise as localized strings. Returns false when
    /// nothing changed.
    @discardableResult
    public mutating func sortRows(by keys: [SortKey]) -> Bool {
        guard !keys.isEmpty, !rows.isEmpty else { return false }
        let indexed = rows.enumerated().map { (index: $0.offset, row: $0.element) }
        let sorted = indexed.sorted { a, b in
            for key in keys {
                let lhs = key.columnIndex < a.row.count ? a.row[key.columnIndex] : ""
                let rhs = key.columnIndex < b.row.count ? b.row[key.columnIndex] : ""
                let cmp = Self.compare(lhs, rhs, mode: key.mode)
                if cmp != 0 {
                    return key.ascending ? cmp < 0 : cmp > 0
                }
            }
            return a.index < b.index // stable fallback
        }
        let newRows = sorted.map(\.row)
        guard !newRows.elementsEqual(rows, by: ==) else { return false }
        rows = newRows
        return true
    }

    private static func compare(_ a: String, _ b: String, mode: SortKey.Mode) -> Int {
        switch (a.isEmpty, b.isEmpty) {
        case (true, true): return 0
        case (true, false): return 1  // empties sort to the end
        case (false, true): return -1
        case (false, false): break
        }
        let numeric = mode == .number
            || (mode == .auto && ColumnTyping.isNumericString(a) && ColumnTyping.isNumericString(b))
        if numeric,
           let na = Double(a.trimmingCharacters(in: .whitespaces)),
           let nb = Double(b.trimmingCharacters(in: .whitespaces)) {
            if na < nb { return -1 }
            if na > nb { return 1 }
            return 0
        }
        switch a.compare(b, options: [], range: nil, locale: .current) {
        case .orderedAscending: return -1
        case .orderedDescending: return 1
        case .orderedSame: return 0
        }
    }
}
