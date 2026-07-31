import AppKit
import GridEditCore

/// The CSV/TSV document. All byte-level work (detection, parse, serialize,
/// size cap) lives in GridEditCore.DocumentIO; this class is AppKit glue.
@objc(GridDocument)
final class GridDocument: NSDocument {
    var content = DocumentContent()

    override class var autosavesInPlace: Bool { false }

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    override func read(from url: URL, ofType typeName: String) throws {
        // Refuse oversized files before their bytes are loaded into memory.
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size <= DocumentIO.maxFileSize else {
            throw DocumentIO.DocumentError.tooLarge(byteCount: size)
        }
        try super.read(from: url, ofType: typeName)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        content = try DocumentIO.read(data, filename: fileURL?.lastPathComponent)
    }

    override func data(ofType typeName: String) throws -> Data {
        try DocumentIO.write(content)
    }

    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("GridDocumentWindow")
        // Placeholder until the Phase 1 grid view lands: prove the pipeline
        // by summarizing what DocumentIO detected.
        let summary = "\(content.table.rows.count) rows × \(content.table.maxColumns) cols — "
            + "\(content.encoding.rawValue) / \(content.delimiter.displayName) / \(content.lineEnding.rawValue)"
        let label = NSTextField(labelWithString: summary)
        label.alignment = .center
        window.contentView = label
        addWindowController(NSWindowController(window: window))
    }
}

extension Delimiter {
    var displayName: String {
        switch self {
        case .comma: return "Comma"
        case .tab: return "Tab"
        case .semicolon: return "Semicolon"
        }
    }
}
