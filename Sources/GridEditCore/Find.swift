import Foundation

/// Cell search and replace, ported from csv-editor's find.ts.
public struct FindOptions: Equatable, Sendable {
    public var caseSensitive: Bool
    public var regex: Bool
    public var wholeCell: Bool

    public init(caseSensitive: Bool = false, regex: Bool = false, wholeCell: Bool = false) {
        self.caseSensitive = caseSensitive
        self.regex = regex
        self.wholeCell = wholeCell
    }
}

/// One match inside one cell. Offsets are UTF-16 (NSRegularExpression's
/// native coordinate space).
public struct FindMatch: Equatable, Sendable {
    public var row: Int
    public var column: Int
    public var matchStart: Int
    public var matchEnd: Int

    public init(row: Int, column: Int, matchStart: Int, matchEnd: Int) {
        self.row = row
        self.column = column
        self.matchStart = matchStart
        self.matchEnd = matchEnd
    }
}

public enum Find {
    /// The search regex, or nil when the query is empty or (in regex mode)
    /// syntactically invalid.
    static func buildRegex(_ query: String, options: FindOptions) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        let pattern = options.regex ? query : NSRegularExpression.escapedPattern(for: query)
        let flags: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: flags)
    }

    public static func matches(
        query: String, options: FindOptions, rows: [[String]]
    ) -> [FindMatch] {
        guard let re = buildRegex(query, options: options) else { return [] }
        var out: [FindMatch] = []
        for (r, row) in rows.enumerated() {
            for (c, cell) in row.enumerated() where !cell.isEmpty {
                let cellRange = NSRange(cell.startIndex..., in: cell)
                re.enumerateMatches(in: cell, range: cellRange) { result, _, _ in
                    guard let result else { return }
                    if options.wholeCell && result.range != cellRange { return }
                    out.append(FindMatch(
                        row: r, column: c,
                        matchStart: result.range.location,
                        matchEnd: result.range.location + result.range.length))
                }
            }
        }
        return out
    }

    /// One edit per cell containing matches. In regex mode $1, $0, …
    /// template substitutions work; otherwise the replacement is literal.
    public static func replaceAllEdits(
        query: String, replacement: String, options: FindOptions, rows: [[String]]
    ) -> [CellEdit] {
        guard let re = buildRegex(query, options: options) else { return [] }
        let template = options.regex
            ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        var edits: [CellEdit] = []
        for (r, row) in rows.enumerated() {
            for (c, cell) in row.enumerated() where !cell.isEmpty {
                let cellRange = NSRange(cell.startIndex..., in: cell)
                if options.wholeCell {
                    guard let match = re.firstMatch(in: cell, range: cellRange),
                          match.range == cellRange else { continue }
                }
                let next = re.stringByReplacingMatches(
                    in: cell, range: cellRange, withTemplate: template)
                if next != cell {
                    edits.append(CellEdit(row: r, column: c, value: next))
                }
            }
        }
        return edits
    }

    /// Applies the replacement to a single match.
    public static func replaceOneEdit(
        match: FindMatch, query: String, replacement: String,
        options: FindOptions, rows: [[String]]
    ) -> CellEdit? {
        guard match.row < rows.count, match.column < rows[match.row].count else { return nil }
        let cell = rows[match.row][match.column]
        let nsCell = cell as NSString
        guard match.matchEnd <= nsCell.length else { return nil }
        let matchRange = NSRange(location: match.matchStart, length: match.matchEnd - match.matchStart)

        let substituted: String
        if options.regex {
            guard let re = buildRegex(query, options: options),
                  let result = re.firstMatch(
                    in: cell,
                    range: NSRange(location: match.matchStart, length: nsCell.length - match.matchStart)),
                  result.range.location == match.matchStart else { return nil }
            substituted = re.replacementString(
                for: result, in: cell, offset: 0, template: replacement)
        } else {
            substituted = replacement
        }
        let next = nsCell.replacingCharacters(in: matchRange, with: substituted)
        return next == cell
            ? nil : CellEdit(row: match.row, column: match.column, value: next)
    }
}
