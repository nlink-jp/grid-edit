import AppKit

/// Row view that paints the rectangular-selection highlight across the
/// full cell area (including intercell spacing), so the highlight meets
/// the grid lines instead of leaving side gaps the way a label-background
/// highlight does.
final class GridRowView: NSTableRowView {
    /// Horizontal span (table-view x coordinates) of the selected columns
    /// in this row; nil when the row has no selected cells.
    var selectionSpan: NSRect? {
        didSet {
            if selectionSpan != oldValue {
                needsDisplay = true
            }
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect) // alternating row background
        guard var span = selectionSpan else { return }
        span.origin.y = bounds.minY
        span.size.height = bounds.height
        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        span.intersection(dirtyRect).fill()
    }
}
