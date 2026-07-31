import AppKit
import GridEditCore

/// The editable grid over a document's table: rectangular selection,
/// field-editor cell editing, TSV clipboard, and document-routed undo.
final class GridViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    private(set) var content: DocumentContent
    weak var document: GridDocument?
    let tableView = GridTableView()

    var selection: GridSelection? {
        didSet { tableView.reloadData() }
    }

    /// Paste-confirmation hook; tests replace it. Returns true to proceed.
    var confirmPaste: ([PastePlanner.Concern]) -> Bool = { concerns in
        let alert = NSAlert()
        alert.messageText = L("Confirm paste")
        alert.informativeText = concerns.map(\.message).joined(separator: "\n")
        alert.addButton(withTitle: L("Paste"))
        alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private var cellEditor: NSTextView?
    private var editingPosition: GridPosition?

    let findBar = FindBarView()
    var findMatches: [FindMatch] = []
    var findCurrentIndex: Int?

    /// Per-column numeric flags (display-only right alignment).
    var numericColumns: [Bool] = []
    var headerEditor: NSTextView?
    var headerEditingColumn: Int?

    let formatBar = FormatBarView()

    /// Display line count per row (1 for single-line rows). Rows containing
    /// Alt+Enter newlines get proportionally taller rows via heightOfRow.
    private var rowLineCounts: [Int] = []

    private static let rowNumberColumnID = NSUserInterfaceItemIdentifier("gridedit.rownumber")
    private static let cellID = NSUserInterfaceItemIdentifier("gridedit.cell")
    private static let rowNumberCellID = NSUserInterfaceItemIdentifier("gridedit.rownumbercell")
    private static let cellFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
    static let baseRowHeight: CGFloat = 20
    /// Measured, not hardcoded: the label lays out both ASCII and Japanese
    /// lines at exactly this height, so extra lines add exactly this much.
    /// Anything larger leaves a growing blank band under the last line.
    private static let lineHeight: CGFloat =
        ceil(NSLayoutManager().defaultLineHeight(for: cellFont))

    /// Longest explicit-newline line count among the row's cells.
    /// Width-based wrapping deliberately doesn't count (display uses
    /// clipping, not wrapping, so height only depends on the data).
    static func lineCount(of cells: [String]) -> Int {
        var maxLines = 1
        for cell in cells where cell.contains("\n") {
            let lines = cell.reduce(into: 1) { count, ch in
                if ch == "\n" { count += 1 }
            }
            if lines > maxLines { maxLines = lines }
        }
        return maxLines
    }

    static func rowHeight(forLineCount lines: Int) -> CGFloat {
        baseRowHeight + CGFloat(max(0, lines - 1)) * lineHeight
    }

    init(content: DocumentContent, document: GridDocument? = nil) {
        self.content = content
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    var rowCount: Int { content.table.rows.count }
    var columnCount: Int { content.table.maxColumns }

    // MARK: View construction

    override func loadView() {
        // delegate BEFORE dataSource: assigning the dataSource triggers an
        // internal reload, and without the delegate in place every row's
        // height is cached at the default 20 — multiline rows then display
        // single-height until the next reload.
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsColumnReordering = false
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        tableView.style = .plain
        tableView.rowHeight = 20
        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        rebuildRowLineCounts()
        numericColumns = ColumnTyping.inferNumericColumns(
            rows: content.table.rows, columnCount: columnCount)

        let rowNumber = NSTableColumn(identifier: Self.rowNumberColumnID)
        rowNumber.title = ""
        rowNumber.width = rowNumberColumnWidth()
        rowNumber.resizingMask = []
        tableView.addTableColumn(rowNumber)
        syncDataColumns()

        wireGridCallbacks()

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = tableView

        wireFindBar()
        wireFormatBar()
        let stack = NSStackView(views: [findBar, scroll, formatBar])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        // The window takes its initial size from this view — without an
        // explicit frame the window collapses to the title bar (1×32).
        // DropContainerView also accepts CSV/TSV files dropped anywhere on
        // the window and opens them as documents.
        let container = DropContainerView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container

        formatBar.update(content: content)
        tableView.reloadData() // recompute row heights now that everything is wired
    }

    private func wireFormatBar() {
        formatBar.onEncodingChange = { [weak self] encoding in
            self?.document?.performContentChange(L("Change Encoding")) {
                guard $0.encoding != encoding else { return false }
                $0.encoding = encoding
                return true
            }
        }
        formatBar.onDelimiterChange = { [weak self] delimiter in
            self?.document?.performContentChange(L("Change Delimiter")) {
                guard $0.delimiter != delimiter else { return false }
                $0.delimiter = delimiter
                return true
            }
        }
        formatBar.onLineEndingChange = { [weak self] lineEnding in
            self?.document?.performContentChange(L("Change Line Ending")) {
                guard $0.lineEnding != lineEnding else { return false }
                $0.lineEnding = lineEnding
                return true
            }
        }
        formatBar.onHeaderToggle = { [weak self] hasHeader in
            self?.commitEditIfNeeded()
            self?.document?.performContentChange(
                hasHeader ? L("Enable Header") : L("Disable Header")) {
                $0.setHasHeader(hasHeader)
            }
        }
    }

    private func wireGridCallbacks() {
        tableView.onSelect = { [weak self] hit, extending in
            self?.commitEditIfNeeded()
            self?.select(hit, extending: extending)
        }
        tableView.onDragExtend = { [weak self] hit in
            guard let self, let current = self.selection else { return }
            let column = hit.dataColumn ?? (self.columnCount - 1)
            self.selection = GridSelection(
                anchor: current.anchor,
                focus: GridPosition(row: hit.row, column: column))
        }
        tableView.onBeginEdit = { [weak self] in self?.beginEdit() }
        tableView.onMove = { [weak self] direction, toEdge, extending in
            self?.moveSelection(direction, toEdge: toEdge, extending: extending)
        }
        tableView.onClearCells = { [weak self] in self?.clearSelectedCells() }
        tableView.onPage = { [weak self] down in self?.pageSelection(down: down) }
        tableView.onMoveBlock = { [weak self] direction in self?.moveBlock(direction) }
        tableView.onContextMenu = { [weak self] hit in self?.contextMenu(for: hit) }

        let header = GridTableView.HeaderView()
        header.onMenu = { [weak self] dataColumn in self?.headerContextMenu(forColumn: dataColumn) }
        header.onDoubleClick = { [weak self] dataColumn in self?.beginHeaderRename(column: dataColumn) }
        tableView.headerView = header
    }

    private func select(_ hit: GridTableView.GridHit, extending: Bool) {
        let focus: GridPosition
        let anchor: GridPosition
        if let column = hit.dataColumn {
            focus = GridPosition(row: hit.row, column: column)
            anchor = extending ? (selection?.anchor ?? focus) : focus
        } else {
            // Row-number column: select the whole row.
            focus = GridPosition(row: hit.row, column: max(0, columnCount - 1))
            anchor = extending
                ? (selection?.anchor ?? GridPosition(row: hit.row, column: 0))
                : GridPosition(row: hit.row, column: 0)
        }
        selection = GridSelection(anchor: anchor, focus: focus)
        scrollToFocus()
    }

    private func moveSelection(_ direction: GridSelection.Direction, toEdge: Bool, extending: Bool) {
        guard rowCount > 0, columnCount > 0 else { return }
        commitEditIfNeeded()
        let current = selection ?? GridSelection(anchor: GridPosition(row: 0, column: 0))
        selection = current.moving(
            direction, toEdge: toEdge, extending: extending,
            rowCount: rowCount, columnCount: columnCount)
        scrollToFocus()
    }

    private func pageSelection(down: Bool) {
        guard rowCount > 0, columnCount > 0 else { return }
        let visibleRows = max(1, tableView.rows(in: tableView.visibleRect).length - 1)
        let current = selection ?? GridSelection(anchor: GridPosition(row: 0, column: 0))
        var focus = current.focus
        focus.row = max(0, min(rowCount - 1, focus.row + (down ? visibleRows : -visibleRows)))
        selection = GridSelection(anchor: focus)
        scrollToFocus()
    }

    func scrollToFocus() {
        guard let focus = selection?.focus else { return }
        tableView.scrollRowToVisible(focus.row)
        let columnIndex = focus.column + 1 // + row-number column
        if columnIndex < tableView.tableColumns.count {
            tableView.scrollColumnToVisible(columnIndex)
        }
    }

    // MARK: Content updates

    /// Called by the document after every model mutation. `changedRows`
    /// limits the line-count cache update; nil rebuilds it entirely.
    func contentDidChange(_ newContent: DocumentContent, changedRows: Set<Int>? = nil) {
        content = newContent
        rebuildRowLineCounts(changedRows: changedRows)
        numericColumns = ColumnTyping.inferNumericColumns(
            rows: content.table.rows, columnCount: columnCount)
        syncDataColumns()
        tableView.reloadData()
        formatBar.update(content: content)
        refreshFind(jumpToFirst: false)
    }

    private func rebuildRowLineCounts(changedRows: Set<Int>? = nil) {
        if let changedRows, rowLineCounts.count <= rowCount {
            while rowLineCounts.count < rowCount {
                rowLineCounts.append(1)
            }
            for row in changedRows where row < rowCount {
                rowLineCounts[row] = Self.lineCount(of: content.table.rows[row])
            }
        } else {
            rowLineCounts = content.table.rows.map(Self.lineCount(of:))
        }
    }

    private func syncDataColumns() {
        // Structural column ops shrink/grow the table and rewrite header
        // titles — keep NSTableColumn count and titles in lockstep.
        while tableView.tableColumns.count - 1 > columnCount {
            tableView.removeTableColumn(tableView.tableColumns[tableView.tableColumns.count - 1])
        }
        let existing = tableView.tableColumns.count - 1 // minus row-number column
        for index in existing..<columnCount {
            let column = NSTableColumn(identifier: Self.dataColumnID(index))
            column.width = 120
            column.minWidth = 24
            tableView.addTableColumn(column)
        }
        for column in tableView.tableColumns {
            if let index = Self.dataColumnIndex(of: column) {
                column.title = columnTitle(index)
            }
        }
    }

    // MARK: Editing

    func beginEdit() {
        guard let focus = selection?.focus, cellEditor == nil,
              focus.row < rowCount else { return }
        let columnIndex = focus.column + 1
        guard columnIndex < tableView.tableColumns.count else { return }

        tableView.scrollRowToVisible(focus.row)
        tableView.scrollColumnToVisible(columnIndex)

        // The editor is an NSTextView overlay, not an NSTextField: inside an
        // NSTableView the field-editor forwarding (control:textView:
        // doCommandBySelector:) never fires, so Return/Tab/Esc would be
        // swallowed. NSTextView's own delegate path is direct and reliable,
        // and IME composition is native to NSTextView anyway.
        let frame = tableView.frameOfCell(atColumn: columnIndex, row: focus.row)
        let editor = NSTextView(frame: frame.insetBy(dx: -1, dy: -1))
        editor.font = Self.cellFont
        editor.string = cellValue(at: focus)
        editor.delegate = self
        editor.isRichText = false
        editor.isFieldEditor = false // we route Return/Tab ourselves
        editor.allowsUndo = true
        editor.drawsBackground = true
        editor.backgroundColor = .textBackgroundColor
        editor.textContainerInset = NSSize(width: 0, height: 1)
        editor.wantsLayer = true
        editor.layer?.borderColor = NSColor.controlAccentColor.cgColor
        editor.layer?.borderWidth = 2
        tableView.addSubview(editor)
        tableView.overlayEditor = editor
        cellEditor = editor
        editingPosition = focus
        reloadCell(at: focus) // blank the label under the editor
        sizeEditorToFit()
        view.window?.makeFirstResponder(editor)
        editor.selectAll(nil)
    }

    private func reloadCell(at position: GridPosition) {
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: position.row),
            columnIndexes: IndexSet(integer: position.column + 1))
    }

    /// Grows the editor overlay downward to fit its content (multi-line
    /// values from Alt+Enter). It may overlap the rows below while editing —
    /// the committed row height follows via heightOfRow.
    private func sizeEditorToFit() {
        guard let editor = cellEditor, let position = editingPosition,
              let layoutManager = editor.layoutManager,
              let textContainer = editor.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer).height
            + editor.textContainerInset.height * 2
        let cellHeight = tableView
            .frameOfCell(atColumn: position.column + 1, row: position.row)
            .insetBy(dx: -1, dy: -1).height
        let target = max(cellHeight, used + 4)
        if abs(editor.frame.height - target) > 0.5 {
            editor.setFrameSize(NSSize(width: editor.frame.width, height: target))
        }
    }

    func textDidChange(_ notification: Notification) {
        sizeEditorToFit()
    }

    private func cellValue(at position: GridPosition) -> String {
        guard position.row < rowCount else { return "" }
        let cells = content.table.rows[position.row]
        return position.column < cells.count ? cells[position.column] : ""
    }

    /// Ends the current edit session. `commit: false` discards the value.
    private func endEdit(commit: Bool) {
        guard let editor = cellEditor, let position = editingPosition else { return }
        cellEditor = nil
        editingPosition = nil
        tableView.overlayEditor = nil
        let newValue = editor.string
        editor.removeFromSuperview()
        view.window?.makeFirstResponder(tableView)
        if commit && newValue != cellValue(at: position) {
            document?.applyEdits(
                [CellEdit(row: position.row, column: position.column, value: newValue)],
                actionName: L("Edit Cell"))
        } else {
            reloadCell(at: position) // un-blank the label (cancel / unchanged)
        }
    }

    func commitEditIfNeeded() {
        endEdit(commit: true)
    }

    // MARK: NSTextViewDelegate (cell editor)

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if textView === headerEditor {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                endHeaderRename(commit: true)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                endHeaderRename(commit: false)
                return true
            default:
                return false
            }
        }
        guard textView === cellEditor else { return false }
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let event = NSApp.currentEvent
            if event?.type == .keyDown && event?.modifierFlags.contains(.option) == true {
                // Alt+Enter: literal newline inside the cell (RFC 4180
                // quoted multi-line field). Let the text view insert it.
                return false
            }
            endEdit(commit: true)
            moveSelection(.down, toEdge: false, extending: false)
            return true
        case #selector(NSResponder.insertTab(_:)):
            endEdit(commit: true)
            moveSelection(.right, toEdge: false, extending: false)
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            endEdit(commit: true)
            moveSelection(.left, toEdge: false, extending: false)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endEdit(commit: false)
            return true
        default:
            return false
        }
    }

    func textDidEndEditing(_ notification: Notification) {
        // Focus moved elsewhere (click outside, window switch): commit.
        if (notification.object as? NSTextView) === headerEditor {
            endHeaderRename(commit: true)
            return
        }
        endEdit(commit: true)
    }

    // MARK: Clipboard / editing actions (responder chain)

    @objc func copy(_ sender: Any?) {
        guard let selection else { return }
        let tsv = TSV.encode(selection.block(in: content.table))
        guard !tsv.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tsv, forType: .string)
    }

    @objc func cut(_ sender: Any?) {
        copy(sender)
        clearSelectedCells(actionName: L("Cut"))
    }

    @objc func paste(_ sender: Any?) {
        guard let selection,
              let text = NSPasteboard.general.string(forType: .string),
              let plan = PastePlanner.plan(
                block: TSV.decode(text), selection: selection, table: content.table)
        else { return }
        if !plan.concerns.isEmpty && !confirmPaste(plan.concerns) {
            return
        }
        document?.applyEdits(plan.edits, actionName: L("Paste"))
        self.selection = plan.pastedSelection
    }

    @objc func delete(_ sender: Any?) {
        clearSelectedCells()
    }

    @objc override func selectAll(_ sender: Any?) {
        guard rowCount > 0, columnCount > 0 else { return }
        selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: rowCount - 1, column: columnCount - 1))
    }

    func clearSelectedCells(actionName: String = L("Clear")) {
        guard let selection else { return }
        var edits: [CellEdit] = []
        for row in selection.rowRange where row < rowCount {
            let width = content.table.rows[row].count
            for column in selection.columnRange where column < width {
                if !content.table.rows[row][column].isEmpty {
                    edits.append(CellEdit(row: row, column: column, value: ""))
                }
            }
        }
        guard !edits.isEmpty else { return }
        document?.applyEdits(edits, actionName: actionName)
    }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)), #selector(cut(_:)), #selector(delete(_:)):
            return selection != nil
        case #selector(paste(_:)):
            return selection != nil
                && NSPasteboard.general.string(forType: .string) != nil
        default:
            return true
        }
    }

    // MARK: Column helpers

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
        let digits = max(2, String(rowCount).count)
        return CGFloat(digits) * 9 + 16
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        rowCount
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < rowLineCounts.count else { return Self.baseRowHeight }
        return Self.rowHeight(forLineCount: rowLineCounts[row])
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }

        guard let index = Self.dataColumnIndex(of: tableColumn) else {
            let label = reusableLabel(Self.rowNumberCellID)
            label.stringValue = String(row + 1)
            label.alignment = .right
            label.textColor = .secondaryLabelColor
            label.drawsBackground = false
            return label
        }

        let label = reusableLabel(Self.cellID)
        let cells = content.table.rows[row]
        // Blank the cell being edited so the editor overlay isn't
        // double-drawn on top of the label.
        let isEditing = editingPosition == GridPosition(row: row, column: index)
        label.stringValue = isEditing ? "" : (index < cells.count ? cells[index] : "")
        label.alignment = index < numericColumns.count && numericColumns[index]
            ? .right : .natural
        label.textColor = .labelColor
        let selected = selection?.contains(row: row, column: index) ?? false
        label.drawsBackground = selected
        label.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.22)
            : .clear
        return label
    }

    private func reusableLabel(_ identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
        if let recycled = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            return recycled
        }
        let label = NSTextField(labelWithString: "")
        label.identifier = identifier
        label.font = Self.cellFont
        // Multi-line cells (Alt+Enter) render their explicit newlines;
        // long lines clip instead of wrapping so row height only depends
        // on the data's newline count, never on column width.
        label.lineBreakMode = .byClipping
        label.usesSingleLineMode = false
        label.maximumNumberOfLines = 0
        return label
    }
}

extension PastePlanner.Concern {
    var message: String {
        switch self {
        case .shapeMismatch(let clipRows, let clipColumns, let selectionRows, let selectionColumns):
            return String(
                format: L("The clipboard (%d×%d) doesn't match the selected %d×%d range."),
                clipRows, clipColumns, selectionRows, selectionColumns)
        case .extendsTable(let newRowCount, let newColumnCount):
            return String(
                format: L("The paste will extend the table to %d rows × %d columns."),
                newRowCount, newColumnCount)
        }
    }
}
