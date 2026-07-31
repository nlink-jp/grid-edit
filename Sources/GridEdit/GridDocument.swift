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
        window.contentViewController = GridViewController(content: content)
        // contentViewController sizing follows the view's (empty) fitting
        // size, collapsing the window to its title bar — force the geometry.
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        // State restoration (with proper frame persistence) is Phase 2 work;
        // until then don't let macOS resurrect stale frames after a crash.
        window.isRestorable = false
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
