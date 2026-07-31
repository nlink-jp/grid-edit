import AppKit

/// Row view that paints the rectangular-selection highlight across the
/// full cell area (including intercell spacing), so the highlight meets
/// the grid lines instead of leaving side gaps the way a label-background
/// highlight does.
///
/// The span is computed at draw time (not cached): during a live column
/// resize the cells re-layout every frame, and a cached span would lag
/// behind the moving grid lines until the drag ended.
final class GridRowView: NSTableRowView {
    /// Returns the current selection span for this row in table-view
    /// x coordinates, or nil when the row has no selected cells.
    var spanProvider: (() -> NSRect?)?

    override func layout() {
        super.layout()
        // Cells just moved (e.g. live column resize) — repaint the
        // highlight with the new geometry.
        needsDisplay = true
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect) // alternating row background
        guard var span = spanProvider?() else { return }
        span.origin.y = bounds.minY
        span.size.height = bounds.height
        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        span.intersection(dirtyRect).fill()
    }
}
