import AppKit
import GridEditCore

/// NSTableView subclass that owns cell-rectangle selection (NSTableView's
/// native selection is row-based, which a spreadsheet grid can't use) and
/// routes grid keyboard shortcuts. All decisions are delegated to the
/// controller through closures.
final class GridTableView: NSTableView {
    struct GridHit {
        var row: Int
        /// Data column index; nil when the hit is on the row-number column.
        var dataColumn: Int?
    }

    var onSelect: ((GridHit, _ extending: Bool) -> Void)?
    var onDragExtend: ((GridHit) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onMove: ((GridSelection.Direction, _ toEdge: Bool, _ extending: Bool) -> Void)?
    var onClearCells: (() -> Void)?
    var onPage: ((_ down: Bool) -> Void)?
    /// Alt+arrow: move the selected row/column block.
    var onMoveBlock: ((GridSelection.Direction) -> Void)?
    /// Right-click in the grid body.
    var onContextMenu: ((GridHit) -> NSMenu?)?
    /// Click on empty grid area (below the rows / right of the columns).
    var onBackgroundClick: (() -> Void)?

    /// The cell-editor overlay, kept above the row views. reloadData
    /// rebuilds row views lazily on the next layout pass, which would
    /// otherwise stack them over an editor added in the same event cycle
    /// (symptom: double-click shows a blank cell and no editor).
    weak var overlayEditor: NSView?

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if let overlayEditor, subview !== overlayEditor,
           overlayEditor.superview === self {
            addSubview(overlayEditor, positioned: .above, relativeTo: nil)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    /// Header view that forwards clicks (column selection), double-clicks
    /// (rename) and right-clicks (menu) per data column, while leaving the
    /// divider region to NSTableHeaderView so drag-resize and
    /// double-click-to-auto-fit keep working.
    final class HeaderView: NSTableHeaderView {
        var onMenu: ((Int) -> NSMenu?)?
        var onClick: ((Int, _ extending: Bool) -> Void)?
        var onDoubleClick: ((Int) -> Void)?

        private func dataColumn(for event: NSEvent) -> Int? {
            let point = convert(event.locationInWindow, from: nil)
            let columnIndex = column(at: point)
            guard columnIndex >= 0, let tableView else { return nil }
            return GridViewController.dataColumnIndex(of: tableView.tableColumns[columnIndex])
        }

        /// Within the resize hot zone next to a column edge.
        private func isNearDivider(_ event: NSEvent) -> Bool {
            let point = convert(event.locationInWindow, from: nil)
            let columnIndex = column(at: point)
            guard columnIndex >= 0 else { return false }
            let rect = headerRect(ofColumn: columnIndex)
            return point.x - rect.minX < 4 || rect.maxX - point.x < 4
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard let column = dataColumn(for: event) else { return nil }
            return onMenu?(column)
        }

        override func mouseDown(with event: NSEvent) {
            if isNearDivider(event) {
                super.mouseDown(with: event) // divider: resize / auto-fit
                return
            }
            guard let column = dataColumn(for: event) else {
                super.mouseDown(with: event)
                return
            }
            if event.clickCount == 2 {
                onDoubleClick?(column)
            } else {
                onClick?(column, event.modifierFlags.contains(.shift))
            }
        }
    }

    private func gridHit(for event: NSEvent) -> GridHit? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        let column = column(at: point)
        guard row >= 0, column >= 0 else { return nil }
        return GridHit(
            row: row,
            dataColumn: GridViewController.dataColumnIndex(of: tableColumns[column]))
    }

    override func mouseDown(with event: NSEvent) {
        guard let hit = gridHit(for: event) else {
            // Empty area: not a cell, but the click must still end an open
            // edit session — swallowing it makes editing feel stuck.
            onBackgroundClick?()
            return
        }
        if event.clickCount == 2 && hit.dataColumn != nil {
            onSelect?(hit, false)
            onBeginEdit?()
            return
        }
        onSelect?(hit, event.modifierFlags.contains(.shift))

        // Own the drag loop — NSTableView's built-in row selection is unused.
        var dragging = true
        while dragging {
            guard let next = window?.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            switch next.type {
            case .leftMouseDragged:
                autoscroll(with: next)
                if let hit = gridHit(for: next) {
                    onDragExtend?(hit)
                }
            default:
                dragging = false
            }
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let hit = gridHit(for: event) else { return nil }
        return onContextMenu?(hit)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        let extending = flags.contains(.shift)
        let toEdge = flags.contains(.command)

        if flags.contains(.option) {
            switch event.keyCode {
            case 126: onMoveBlock?(.up); return
            case 125: onMoveBlock?(.down); return
            case 123: onMoveBlock?(.left); return
            case 124: onMoveBlock?(.right); return
            default: break
            }
        }

        switch event.keyCode {
        case 126: onMove?(.up, toEdge, extending)
        case 125: onMove?(.down, toEdge, extending)
        case 123: onMove?(.left, toEdge, extending)
        case 124: onMove?(.right, toEdge, extending)
        case 115: onMove?(.left, true, extending)    // Home
        case 119: onMove?(.right, true, extending)   // End
        case 116: onPage?(false)                     // Page Up
        case 121: onPage?(true)                      // Page Down
        case 36, 76: onBeginEdit?()                  // Return, keypad Enter
        case 120: onBeginEdit?()                     // F2
        case 51, 117: onClearCells?()                // Delete, Forward Delete
        case 48:                                     // Tab
            onMove?(extending ? .left : .right, false, false)
        default:
            super.keyDown(with: event)
        }
    }
}
