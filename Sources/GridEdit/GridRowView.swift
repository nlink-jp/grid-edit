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
    /// Returns the row-number gutter's x-range (table-view coordinates).
    var gutterProvider: (() -> NSRect?)?

    override func layout() {
        super.layout()
        // Cells just moved (e.g. live column resize) — repaint the
        // highlight with the new geometry.
        needsDisplay = true
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect) // alternating row background

        let span = spanProvider?()

        // Row-number gutter: header-like background so it reads as chrome,
        // not data; rows with selected cells get a subtle accent tint
        // (spreadsheet convention).
        if var gutter = gutterProvider?() {
            gutter.origin.y = bounds.minY
            gutter.size.height = bounds.height
            let gutterRect = gutter.intersection(dirtyRect)
            // labelColor overlay adapts to both themes and stays visibly
            // darker than plain and striped rows alike (windowBackground-
            // Color renders near-white in light mode — not enough).
            NSColor.labelColor.withAlphaComponent(0.07).setFill()
            gutterRect.fill()
            if span != nil {
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                gutterRect.fill()
            }
        }

        if var span {
            span.origin.y = bounds.minY
            span.size.height = bounds.height
            NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
            span.intersection(dirtyRect).fill()
        }
    }
}
