/// The EOL convention used in a text file.
public enum LineEnding: String, CaseIterable, Sendable {
    case crlf = "CRLF"
    case lf = "LF"
    case cr = "CR"

    /// Returns the line ending used in `text`, scanning at most the first
    /// 8 KiB. Returns `.lf` when the text contains no line ending.
    public static func detect(in text: String) -> LineEnding {
        var scanned = 0
        var sawCR = false
        for byte in text.utf8 {
            if sawCR {
                return byte == UInt8(ascii: "\n") ? .crlf : .cr
            }
            if byte == UInt8(ascii: "\r") {
                sawCR = true
            } else if byte == UInt8(ascii: "\n") {
                return .lf
            }
            scanned += 1
            if scanned >= 8192 { break }
        }
        return sawCR ? .cr : .lf
    }
}
