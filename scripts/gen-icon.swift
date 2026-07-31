// Generates assets/AppIcon-1024.png — a Big-Sur-style squircle with a
// table-card glyph (accent header row, row numbers, content bars).
// Usage: swift scripts/gen-icon.swift assets/AppIcon-1024.png
import AppKit

let size = CGFloat(1024)
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "assets/AppIcon-1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Squircle background (canvas margins per Apple's macOS icon grid).
let squircle = NSBezierPath(
    roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
    xRadius: 185, yRadius: 185)
NSGradient(starting: rgb(0x3E8EE8), ending: rgb(0x1B4FA8))!
    .draw(in: squircle, angle: -90)

// White table card, slightly inset with a soft shadow.
let cardRect = NSRect(x: 196, y: 196, width: 632, height: 632)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 28
NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
rgb(0xFFFFFF).setFill()
NSBezierPath(roundedRect: cardRect, xRadius: 44, yRadius: 44).fill()
NSGraphicsContext.current?.restoreGraphicsState()

// Clip everything table-ish to the card.
NSGraphicsContext.current?.saveGraphicsState()
NSBezierPath(roundedRect: cardRect, xRadius: 44, yRadius: 44).setClip()

// Header row (top of the card; flipped? — AppKit bitmap context origin is
// bottom-left, so the header strip sits at the card's top edge).
let headerHeight = CGFloat(118)
rgb(0x2D6FD1).setFill()
NSRect(
    x: cardRect.minX, y: cardRect.maxY - headerHeight,
    width: cardRect.width, height: headerHeight).fill()

// Grid geometry: narrow row-number column + 3 data columns, 4 data rows.
let rowNumberWidth = CGFloat(96)
let dataColumnWidth = (cardRect.width - rowNumberWidth) / 3
let dataRows = 4
let rowHeight = (cardRect.height - headerHeight) / CGFloat(dataRows)

// Row-number column tint.
rgb(0xF2F4F7).setFill()
NSRect(
    x: cardRect.minX, y: cardRect.minY,
    width: rowNumberWidth, height: cardRect.height - headerHeight).fill()

// Grid lines.
rgb(0xD3D9E0).setStroke()
for i in 1...dataRows - 1 {
    let y = cardRect.minY + CGFloat(i) * rowHeight
    let line = NSBezierPath()
    line.lineWidth = 6
    line.move(to: NSPoint(x: cardRect.minX, y: y))
    line.line(to: NSPoint(x: cardRect.maxX, y: y))
    line.stroke()
}
for i in 0...2 {
    let x = cardRect.minX + rowNumberWidth + CGFloat(i) * dataColumnWidth
    let line = NSBezierPath()
    line.lineWidth = 6
    line.move(to: NSPoint(x: x, y: cardRect.minY))
    line.line(to: NSPoint(x: x, y: cardRect.maxY - headerHeight))
    line.stroke()
}

// Content bars: white in the header, gray in cells, varied widths.
func bar(_ rect: NSRect, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
}
let headerBarY = cardRect.maxY - headerHeight / 2 - 17
for column in 0..<3 {
    let x = cardRect.minX + rowNumberWidth + CGFloat(column) * dataColumnWidth + 28
    bar(NSRect(x: x, y: headerBarY, width: dataColumnWidth - 92, height: 34),
        NSColor.white.withAlphaComponent(0.92))
}
let cellWidths: [[CGFloat]] = [
    [0.62, 0.42, 0.55], [0.45, 0.60, 0.38],
    [0.58, 0.35, 0.50], [0.40, 0.52, 0.44],
]
for (rowIndex, widths) in cellWidths.enumerated() {
    let y = cardRect.maxY - headerHeight - CGFloat(rowIndex + 1) * rowHeight + rowHeight / 2 - 14
    // row-number dot
    bar(NSRect(x: cardRect.minX + 30, y: y, width: 36, height: 28), rgb(0xB8C0CA))
    for (column, ratio) in widths.enumerated() {
        let x = cardRect.minX + rowNumberWidth + CGFloat(column) * dataColumnWidth + 28
        bar(NSRect(x: x, y: y, width: (dataColumnWidth - 56) * ratio, height: 28),
            rgb(0xC7CFD8))
    }
}
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
