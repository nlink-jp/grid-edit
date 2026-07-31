import Foundation

/// CSV/TSV parsing and serialization.
///
/// Semantics mirror csv-editor's Go engine (encoding/csv with
/// `LazyQuotes = true`, `FieldsPerRecord = -1`) so that csv-editor's
/// testdata expectations hold unchanged:
///
/// - RFC 4180 quoting; `""` inside a quoted field is a literal quote
/// - Lazy quotes: a bare quote in an unquoted field, or a stray quote in a
///   quoted field, is taken literally instead of erroring
/// - Ragged rows are allowed (no fixed field count)
/// - Blank lines produce no record
/// - CRLF ends a record; inside quoted fields CRLF is normalized to LF and
///   a lone CR is preserved
/// - CR-only files (no LF anywhere) are normalized to LF before parsing
public enum CSV {
    public struct ParseOptions: Sendable {
        public var delimiter: Delimiter
        public var hasHeader: Bool

        public init(delimiter: Delimiter = .comma, hasHeader: Bool = false) {
            self.delimiter = delimiter
            self.hasHeader = hasHeader
        }
    }

    /// Decodes CSV/TSV text into a table. Never fails: lazy quoting and
    /// ragged rows make every input parseable.
    public static func parse(_ text: String, options: ParseOptions = ParseOptions()) -> CSVTable {
        var input = text
        if !input.contains("\n") && input.contains("\r") {
            input = input.replacingOccurrences(of: "\r", with: "\n")
        }

        let quote = UInt8(ascii: "\"")
        let cr = UInt8(ascii: "\r")
        let lf = UInt8(ascii: "\n")
        let delim = UInt8(ascii: options.delimiter.rawValue.unicodeScalars.first!)

        let bytes = Array(input.utf8)
        var records: [[String]] = []
        var record: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var lineHasContent = false

        func endField() {
            record.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }

        func endLine() {
            if lineHasContent {
                endField()
                records.append(record)
                record = []
            }
            lineHasContent = false
        }

        var i = 0
        let end = bytes.count
        while i < end {
            let b = bytes[i]
            if inQuotes {
                switch b {
                case quote:
                    if i + 1 < end && bytes[i + 1] == quote {
                        field.append(quote)
                        i += 2
                    } else if i + 1 == end || bytes[i + 1] == delim
                        || bytes[i + 1] == lf || bytes[i + 1] == cr {
                        inQuotes = false
                        i += 1
                    } else {
                        // Lazy quotes: stray quote inside a quoted field.
                        field.append(quote)
                        i += 1
                    }
                case cr:
                    if i + 1 < end && bytes[i + 1] == lf {
                        field.append(lf)
                        i += 2
                    } else {
                        field.append(cr)
                        i += 1
                    }
                default:
                    field.append(b)
                    i += 1
                }
                continue
            }
            switch b {
            case quote:
                if field.isEmpty {
                    inQuotes = true
                } else {
                    // Lazy quotes: quote in the middle of an unquoted field.
                    field.append(quote)
                }
                lineHasContent = true
                i += 1
            case delim:
                endField()
                lineHasContent = true
                i += 1
            case cr:
                if i + 1 < end && bytes[i + 1] == lf {
                    endLine()
                    i += 2
                } else {
                    field.append(cr)
                    lineHasContent = true
                    i += 1
                }
            case lf:
                endLine()
                i += 1
            default:
                field.append(b)
                lineHasContent = true
                i += 1
            }
        }
        endLine() // unterminated final line (lazy: also closes an open quote)

        var table = CSVTable()
        if options.hasHeader && !records.isEmpty {
            table.header = records[0]
            if records.count > 1 {
                table.rows = Array(records[1...])
            }
        } else {
            table.rows = records
        }
        return table
    }

    public struct EncodeOptions: Sendable {
        public var delimiter: Delimiter
        public var lineEnding: LineEnding
        public var hasHeader: Bool

        public init(
            delimiter: Delimiter = .comma,
            lineEnding: LineEnding = .lf,
            hasHeader: Bool = false
        ) {
            self.delimiter = delimiter
            self.lineEnding = lineEnding
            self.hasHeader = hasHeader
        }
    }

    /// Renders a table to CSV/TSV text. A line ending follows every record,
    /// including the last. LineEnding `.cr` (old Mac) is written as LF —
    /// modern tools don't emit CR-only files. In CRLF mode, LF inside a
    /// quoted field becomes CRLF and a lone CR is dropped (Go writer parity).
    public static func encode(_ table: CSVTable, options: EncodeOptions = EncodeOptions()) -> String {
        let eol = options.lineEnding == .crlf ? "\r\n" : "\n"
        let delimChar = options.delimiter.character
        var out = ""

        func needsQuotes(_ field: String) -> Bool {
            guard let first = field.first else { return false }
            if first == " " || first == "\t" || first == "\r" || first == "\n" {
                return true
            }
            return field.contains(delimChar) || field.contains("\"")
                || field.contains("\r") || field.contains("\n")
        }

        func writeField(_ field: String) {
            guard needsQuotes(field) else {
                out.append(field)
                return
            }
            out.append("\"")
            for ch in field {
                switch ch {
                case "\"":
                    out.append("\"\"")
                case "\n":
                    out.append(eol)
                case "\r":
                    if options.lineEnding != .crlf { out.append("\r") }
                default:
                    out.append(ch)
                }
            }
            out.append("\"")
        }

        func writeRecord(_ record: [String]) {
            for (i, field) in record.enumerated() {
                if i > 0 { out.append(delimChar) }
                writeField(field)
            }
            out.append(eol)
        }

        if options.hasHeader, let header = table.header, !header.isEmpty {
            writeRecord(header)
        }
        for row in table.rows {
            writeRecord(row)
        }
        return out
    }
}
