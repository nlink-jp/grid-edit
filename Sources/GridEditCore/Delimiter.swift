import Foundation

/// A field delimiter grid-edit can read and write.
///
/// Detection scope is fixed by the RFP: comma, tab, and semicolon
/// (European CSV). Arbitrary single-character delimiters are out of scope.
public enum Delimiter: String, CaseIterable, Sendable {
    case comma = ","
    case tab = "\t"
    case semicolon = ";"

    public var character: Character { rawValue.first! }

    /// Picks the most plausible delimiter for a text sample.
    ///
    /// Counts candidate occurrences **outside quoted fields** on up to the
    /// first 16 non-empty lines, so a semicolon-delimited file whose quoted
    /// fields contain commas is not misread as comma-delimited. The winner
    /// is the candidate present on every scanned line (highest per-line
    /// minimum, then highest total). When no candidate appears on every
    /// line, the highest total wins; a sample with no delimiter at all
    /// falls back to comma.
    public static func detect(in sample: String) -> Delimiter {
        let quote = UInt8(ascii: "\"")
        let lf = UInt8(ascii: "\n")
        let cr = UInt8(ascii: "\r")
        let candidates = Delimiter.allCases
        let candidateBytes = candidates.map { UInt8(ascii: $0.rawValue.unicodeScalars.first!) }

        var perLine: [[Int]] = []          // [line][candidate] counts
        var current = [Int](repeating: 0, count: candidates.count)
        var lineHasContent = false
        var inQuotes = false

        func endLine() {
            if lineHasContent {
                perLine.append(current)
            }
            current = [Int](repeating: 0, count: candidates.count)
            lineHasContent = false
        }

        for b in sample.utf8 {
            if perLine.count >= 16 { break }
            if b == quote {
                inQuotes.toggle()
                lineHasContent = true
            } else if !inQuotes && (b == lf || b == cr) {
                endLine()
            } else {
                if !inQuotes, let idx = candidateBytes.firstIndex(of: b) {
                    current[idx] += 1
                }
                lineHasContent = true
            }
        }
        endLine()

        guard !perLine.isEmpty else { return .comma }

        var best = Delimiter.comma
        var bestKey = (minCount: 0, total: 0)
        for (idx, candidate) in candidates.enumerated() {
            let counts = perLine.map { $0[idx] }
            let key = (minCount: counts.min() ?? 0, total: counts.reduce(0, +))
            if key.minCount > bestKey.minCount
                || (key.minCount == bestKey.minCount && key.total > bestKey.total) {
                best = candidate
                bestKey = key
            }
        }
        return best
    }
}
