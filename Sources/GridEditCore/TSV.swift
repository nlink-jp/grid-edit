/// TSV serialization for clipboard interop, ported verbatim from
/// csv-editor's frontend tsv.ts. Excel and most spreadsheet apps expect
/// tab-separated values with RFC-4180-style quoting: fields containing tab,
/// newline, or double-quote are wrapped in double quotes; quotes inside are
/// escaped by doubling.
public enum TSV {
    /// Each row is terminated (not separated) by \n, matching the RFC 4180
    /// convention — this preserves trailing empty rows on round-trip.
    public static func encode(_ rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }
        return rows.map { row in
            row.map { cell in
                if cell.contains("\t") || cell.contains("\n")
                    || cell.contains("\r") || cell.contains("\"") {
                    return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return cell
            }.joined(separator: "\t")
        }.joined(separator: "\n") + "\n"
    }

    /// Parses TSV text into a 2-D array. Honors quoted fields with embedded
    /// tabs, newlines (\n or \r\n), and "" escapes. A trailing line break
    /// does not produce an extra empty row.
    public static func decode(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var inQuotes = false

        let quote = UInt8(ascii: "\"")
        let tab = UInt8(ascii: "\t")
        let cr = UInt8(ascii: "\r")
        let lf = UInt8(ascii: "\n")

        func pushField() {
            row.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }
        func pushRow() {
            rows.append(row)
            row = []
        }

        let bytes = Array(text.utf8)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if inQuotes {
                if b == quote {
                    if i + 1 < bytes.count && bytes[i + 1] == quote {
                        field.append(quote)
                        i += 2
                        continue
                    }
                    inQuotes = false
                    i += 1
                    continue
                }
                field.append(b)
                i += 1
                continue
            }
            switch b {
            case quote where field.isEmpty:
                inQuotes = true
                i += 1
            case tab:
                pushField()
                i += 1
            case cr:
                pushField()
                pushRow()
                i += (i + 1 < bytes.count && bytes[i + 1] == lf) ? 2 : 1
            case lf:
                pushField()
                pushRow()
                i += 1
            default:
                field.append(b)
                i += 1
            }
        }
        if !field.isEmpty || !row.isEmpty {
            pushField()
            pushRow()
        }
        return rows
    }
}
