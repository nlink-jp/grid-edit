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

    /// Picks the most plausible delimiter for a text sample by counting
    /// candidate occurrences in the first non-empty line. Ties (including
    /// a sample with no delimiter at all) fall back to comma.
    ///
    /// This is the scaffold heuristic; the Phase 1 engine will replace it
    /// with quote-aware, multi-line scoring.
    public static func detect(in sample: String) -> Delimiter {
        let firstLine = sample
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .first ?? ""
        var best = Delimiter.comma
        var bestCount = 0
        for candidate in Delimiter.allCases {
            let count = firstLine.filter { $0 == candidate.character }.count
            if count > bestCount {
                best = candidate
                bestCount = count
            }
        }
        return best
    }
}
