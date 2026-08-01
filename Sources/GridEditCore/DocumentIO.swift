import Foundation

/// Everything a grid-edit document holds: the parsed table plus the format
/// settings detected on read and adjustable on save.
public struct DocumentContent: Equatable, Sendable {
    public var table: CSVTable
    public var encoding: TextEncoding
    public var delimiter: Delimiter
    public var lineEnding: LineEnding
    public var hasHeader: Bool

    public init(
        table: CSVTable = CSVTable(),
        encoding: TextEncoding = .utf8,
        delimiter: Delimiter = .comma,
        lineEnding: LineEnding = .lf,
        hasHeader: Bool = false
    ) {
        self.table = table
        self.encoding = encoding
        self.delimiter = delimiter
        self.lineEnding = lineEnding
        self.hasHeader = hasHeader
    }

    /// Toggles the header row, promoting the first data row to header
    /// (on) or demoting the header into the data rows (off) — csv-editor
    /// SET_HAS_HEADER semantics. Returns false when nothing changed.
    @discardableResult
    public mutating func setHasHeader(_ value: Bool) -> Bool {
        guard value != hasHeader else { return false }
        if value {
            table.header = table.rows.isEmpty ? [] : table.rows.removeFirst()
        } else {
            if let header = table.header, !header.isEmpty {
                table.rows.insert(header, at: 0)
            }
            table.header = nil
        }
        hasHeader = value
        return true
    }
}

/// Byte-level document open/save: detection on read, explicit settings on
/// write. Pure functions — GridDocument delegates here so the whole I/O
/// path is unit-testable without AppKit.
public enum DocumentIO {
    /// Files larger than this are refused with a clear error instead of
    /// being loaded into memory (RFP constraint, inherited from csv-editor).
    public static let maxFileSize = 500 * 1024 * 1024

    public enum DocumentError: Error, Equatable, LocalizedError {
        case tooLarge(byteCount: Int)

        public var errorDescription: String? {
            switch self {
            case .tooLarge(let byteCount):
                let size = ByteCountFormatter.string(
                    fromByteCount: Int64(byteCount), countStyle: .binary)
                let limit = ByteCountFormatter.string(
                    fromByteCount: Int64(DocumentIO.maxFileSize), countStyle: .binary)
                return String(
                    format: NSLocalizedString(
                        "This file is %@; grid-edit opens files up to %@.",
                        bundle: .module, comment: ""),
                    size, limit)
            }
        }
    }

    /// Parses raw file bytes into a document, auto-detecting encoding,
    /// delimiter, and line ending. A `.tsv`/`.tab` filename forces the tab
    /// delimiter when the content itself shows no delimiter at all
    /// (e.g. a single-column file).
    public static func read(_ data: Data, filename: String? = nil, hasHeader: Bool = true) throws -> DocumentContent {
        guard data.count <= maxFileSize else {
            throw DocumentError.tooLarge(byteCount: data.count)
        }
        let encoding = TextEncoding.detect(data)
        let text = try encoding.decode(data)
        let lineEnding = LineEnding.detect(in: text)

        var delimiter = Delimiter.detect(in: text)
        if delimiter == .comma, !text.contains(","),
           let ext = filename.map({ ($0 as NSString).pathExtension.lowercased() }),
           ext == "tsv" || ext == "tab" {
            delimiter = .tab
        }

        var table = CSV.parse(text, options: .init(delimiter: delimiter, hasHeader: hasHeader))
        table.ensureMinimumGrid() // empty / header-only files must stay editable
        return DocumentContent(
            table: table,
            encoding: encoding,
            delimiter: delimiter,
            lineEnding: lineEnding,
            hasHeader: hasHeader)
    }

    /// Renders a document back to file bytes using its current settings.
    public static func write(_ content: DocumentContent) throws -> Data {
        let text = CSV.encode(content.table, options: .init(
            delimiter: content.delimiter,
            lineEnding: content.lineEnding,
            hasHeader: content.hasHeader))
        return try content.encoding.encode(text)
    }
}
