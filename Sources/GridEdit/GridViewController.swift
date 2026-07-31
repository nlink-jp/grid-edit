import AppKit
import GridEditCore

/// Read-only grid over a document's table. View-based NSTableView gives
/// row virtualization for free; cells are reused NSTextFields.
final class GridViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private(set) var content: DocumentContent
    let tableView = NSTableView()

    private static let rowNumberColumnID = NSUserInterfaceItemIdentifier("gridedit.rownumber")
    private static let cellID = NSUserInterfaceItemIdentifier("gridedit.cell")
    private static let rowNumberCellID = NSUserInterfaceItemIdentifier("gridedit.rownumbercell")
    private static let cellFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize(for: .small), weight: .regular)

    init(content: DocumentContent) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        tableView.style = .plain
        tableView.rowHeight = 20
        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        let rowNumber = NSTableColumn(identifier: Self.rowNumberColumnID)
        rowNumber.title = ""
        rowNumber.width = rowNumberColumnWidth()
        rowNumber.resizingMask = []
        tableView.addTableColumn(rowNumber)

        for index in 0..<content.table.maxColumns {
            let column = NSTableColumn(identifier: Self.dataColumnID(index))
            column.title = columnTitle(index)
            column.width = 120
            column.minWidth = 24
            tableView.addTableColumn(column)
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = tableView
        // The window takes its initial size from this view — without an
        // explicit frame the window collapses to the title bar (1×32).
        scroll.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        view = scroll
    }

    static func dataColumnID(_ index: Int) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("gridedit.col.\(index)")
    }

    /// Data-column index for a table column, nil for the row-number column.
    static func dataColumnIndex(of column: NSTableColumn) -> Int? {
        let raw = column.identifier.rawValue
        guard raw.hasPrefix("gridedit.col.") else { return nil }
        return Int(raw.dropFirst("gridedit.col.".count))
    }

    private func columnTitle(_ index: Int) -> String {
        if content.hasHeader, let header = content.table.header, index < header.count {
            return header[index]
        }
        return String(index + 1)
    }

    private func rowNumberColumnWidth() -> CGFloat {
        let digits = max(2, String(content.table.rows.count).count)
        return CGFloat(digits) * 9 + 16
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        content.table.rows.count
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }

        if Self.dataColumnIndex(of: tableColumn) == nil {
            let label = reusableLabel(Self.rowNumberCellID)
            label.stringValue = String(row + 1)
            label.alignment = .right
            label.textColor = .secondaryLabelColor
            return label
        }

        guard let index = Self.dataColumnIndex(of: tableColumn) else { return nil }
        let label = reusableLabel(Self.cellID)
        let cells = content.table.rows[row]
        label.stringValue = index < cells.count ? cells[index] : ""
        label.alignment = .natural
        label.textColor = .labelColor
        return label
    }

    private func reusableLabel(_ identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
        if let recycled = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            return recycled
        }
        let label = NSTextField(labelWithString: "")
        label.identifier = identifier
        label.font = Self.cellFont
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.cell?.truncatesLastVisibleLine = true
        return label
    }
}
