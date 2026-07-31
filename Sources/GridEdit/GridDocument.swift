import AppKit
import GridEditCore

/// The CSV/TSV document. All byte-level work (detection, parse, serialize,
/// size cap) lives in GridEditCore.DocumentIO; this class is AppKit glue
/// plus the undo-managed mutation funnel.
@objc(GridDocument)
final class GridDocument: NSDocument {
    var content: DocumentContent

    override init() {
        // Untitled documents start with a modest empty grid to type into;
        // pasting grows it as needed.
        content = DocumentContent(
            table: CSVTable(rows: Array(repeating: Array(repeating: "", count: 5), count: 10)))
        super.init()
    }

    override class var autosavesInPlace: Bool { false }

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    private var gridViewController: GridViewController? {
        windowControllers.first?.contentViewController as? GridViewController
    }

    // MARK: Mutations (single funnel, undo-managed)

    /// Applies a batch of cell edits as one undoable action.
    func applyEdits(_ edits: [CellEdit], actionName: String) {
        guard !edits.isEmpty else { return }
        let undo = content.table.apply(edits)
        undoManager?.registerUndo(withTarget: self) { document in
            document.revertEdits(undo, redo: edits, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        gridViewController?.contentDidChange(content, changedRows: Set(edits.map(\.row)))
    }

    private func revertEdits(_ undo: CSVTable.EditUndo, redo: [CellEdit], actionName: String) {
        content.table.restore(undo)
        undoManager?.registerUndo(withTarget: self) { document in
            document.applyEdits(redo, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        gridViewController?.contentDidChange(
            content, changedRows: Set(undo.oldRows.map(\.index)))
    }

    /// Applies a structural table operation (row/column ops, sort, header
    /// rename) as one undoable action. `op` returns false for a no-op, in
    /// which case nothing is registered.
    @discardableResult
    func performTableOperation(_ actionName: String, _ op: (inout CSVTable) -> Bool) -> Bool {
        let before = content.table.snapshot()
        guard op(&content.table) else { return false }
        let after = content.table.snapshot()
        undoManager?.registerUndo(withTarget: self) { document in
            document.applySnapshot(before, opposite: after, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        gridViewController?.contentDidChange(content)
        return true
    }

    private func applySnapshot(
        _ snapshot: CSVTable.Snapshot,
        opposite: CSVTable.Snapshot,
        actionName: String
    ) {
        content.table.restore(snapshot)
        undoManager?.registerUndo(withTarget: self) { document in
            document.applySnapshot(opposite, opposite: snapshot, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        gridViewController?.contentDidChange(content)
    }

    // MARK: Reading / writing

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
        gridViewController?.commitEditIfNeeded()
        return try DocumentIO.write(content)
    }

    // MARK: Window

    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = GridViewController(content: content, document: self)
        // contentViewController sizing follows the view's (empty) fitting
        // size, collapsing the window to its title bar — force the geometry.
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        // State restoration (with proper frame persistence) is Phase 2 work;
        // until then don't let macOS resurrect stale frames after a crash.
        window.isRestorable = false
        if let vc = window.contentViewController as? GridViewController {
            window.initialFirstResponder = vc.tableView
            window.makeFirstResponder(vc.tableView)
        }
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
