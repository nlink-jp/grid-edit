import AppKit
import GridEditCore

/// The CSV/TSV document. Scaffold state: holds the raw file bytes and shows a
/// placeholder window. Phase 1 replaces the storage with the GridEditCore
/// table model (encoding / delimiter / line-ending aware) and the placeholder
/// view with the NSTableView grid.
@objc(GridDocument)
final class GridDocument: NSDocument {
    private var rawData = Data()

    override class var autosavesInPlace: Bool { false }

    override func data(ofType typeName: String) throws -> Data {
        rawData
    }

    override func read(from data: Data, ofType typeName: String) throws {
        rawData = data
    }

    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        let label = NSTextField(labelWithString: "grid-edit scaffold — Phase 1 grid lands here")
        label.alignment = .center
        window.contentView = label
        addWindowController(NSWindowController(window: window))
    }
}
