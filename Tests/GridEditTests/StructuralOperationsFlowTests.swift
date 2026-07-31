import XCTest
import GridEditCore
@testable import GridEdit

/// Structural operations through the document funnel: undo/redo, view
/// synchronization (columns, titles), and selection updates.
@MainActor
final class StructuralOperationsFlowTests: XCTestCase {
    func makeDocumentAndController(
        header: [String]? = nil,
        rows: [[String]] = [["a", "b"], ["c", "d"], ["e", "f"]]
    ) -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(header: header, rows: rows),
            hasHeader: header != nil)
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func testInsertRowsAboveWithUndo() {
        let (document, vc) = makeDocumentAndController()
        vc.insertRows(1...2, above: true)
        XCTAssertEqual(document.content.table.rows, [
            ["a", "b"], ["", ""], ["", ""], ["c", "d"], ["e", "f"],
        ])
        XCTAssertEqual(vc.selection?.rowRange, 1...2)
        XCTAssertEqual(vc.tableView.numberOfRows, 5)

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.rows, [["a", "b"], ["c", "d"], ["e", "f"]])
        XCTAssertEqual(vc.tableView.numberOfRows, 3)

        document.undoManager?.redo()
        XCTAssertEqual(document.content.table.rows.count, 5)
    }

    func testDeleteRowsClampsSelection() {
        let (document, vc) = makeDocumentAndController()
        vc.deleteRows(1...2)
        XCTAssertEqual(document.content.table.rows, [["a", "b"]])
        XCTAssertEqual(vc.selection?.rowRange, 0...0)
    }

    func testMoveRowsAtEdgeKeepsSelection() {
        let (document, vc) = makeDocumentAndController()
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        vc.moveRows(0...0, up: true) // no-op at edge
        XCTAssertEqual(document.content.table.rows[0], ["a", "b"])
        XCTAssertEqual(vc.selection?.rowRange, 0...0)
        XCTAssertFalse(document.undoManager?.canUndo ?? true, "no-op must not register undo")
    }

    /// NSUndoManager groups registrations per run-loop turn; without a
    /// turn between operations they'd coalesce into one undo group (which
    /// never happens in real interaction).
    private func closeUndoGroup() {
        RunLoop.current.run(until: Date())
    }

    func testColumnOpsKeepTableViewInSync() {
        let (document, vc) = makeDocumentAndController(
            header: ["h1", "h2"], rows: [["a", "b"], ["c", "d"]])
        XCTAssertEqual(vc.tableView.tableColumns.count, 3) // row# + 2

        vc.insertColumns(0...0, left: true)
        closeUndoGroup()
        XCTAssertEqual(document.content.table.header, ["", "h1", "h2"])
        XCTAssertEqual(vc.tableView.tableColumns.count, 4)
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "")
        XCTAssertEqual(vc.tableView.tableColumns[2].title, "h1")

        vc.deleteColumns(0...1)
        closeUndoGroup()
        XCTAssertEqual(document.content.table.header, ["h2"])
        XCTAssertEqual(vc.tableView.tableColumns.count, 2) // shrunk
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "h2")

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.header, ["", "h1", "h2"])
        XCTAssertEqual(vc.tableView.tableColumns.count, 4, "undo must restore columns")
    }

    func testMoveBlockViaAltArrows() {
        let (document, vc) = makeDocumentAndController()
        vc.selection = GridSelection(anchor: GridPosition(row: 1, column: 0))
        vc.moveBlock(.up)
        XCTAssertEqual(document.content.table.rows, [["c", "d"], ["a", "b"], ["e", "f"]])
        XCTAssertEqual(vc.selection?.rowRange, 0...0)
    }

    func testSortThroughDocumentWithUndo() {
        let (document, vc) = makeDocumentAndController(
            rows: [["10", "x"], ["2", "y"], ["1", "z"]])
        vc.sortByColumns(0...0, ascending: true)
        XCTAssertEqual(document.content.table.rows, [["1", "z"], ["2", "y"], ["10", "x"]])
        XCTAssertEqual(document.undoManager?.undoActionName, L("Sort Ascending"))

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.rows, [["10", "x"], ["2", "y"], ["1", "z"]])
    }

    func testRowContextMenuTargetsClickedRowOutsideSelection() throws {
        let (_, vc) = makeDocumentAndController()
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        let menu = try XCTUnwrap(vc.contextMenu(
            for: GridTableView.GridHit(row: 2, dataColumn: nil)))
        XCTAssertEqual(menu.items[0].title, L("Insert Row Above"))
        XCTAssertEqual(vc.selection?.rowRange, 2...2, "click outside selection retargets it")
    }

    func testCellContextMenuOffersInserts() throws {
        let (_, vc) = makeDocumentAndController()
        vc.selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1))
        let menu = try XCTUnwrap(vc.contextMenu(
            for: GridTableView.GridHit(row: 0, dataColumn: 0)))
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains(
            LPlural(2, one: "Insert Row Above", other: "Insert %d Rows Above")))
        XCTAssertTrue(titles.contains(
            LPlural(2, one: "Insert Column Right", other: "Insert %d Columns Right")))
    }

    func testHeaderContextMenuUsesSelectedColumns() throws {
        let (_, vc) = makeDocumentAndController(
            header: ["h1", "h2"], rows: [["a", "b"]])
        vc.selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 0, column: 1))
        let menu = try XCTUnwrap(vc.headerContextMenu(forColumn: 1))
        XCTAssertEqual(
            menu.items[0].title,
            LPlural(2, one: "Insert Column Left", other: "Insert %d Columns Left"))
    }
}
