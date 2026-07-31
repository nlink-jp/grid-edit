import XCTest
import GridEditCore
@testable import GridEdit

/// Document-level editing flow: mutation funnel, undo/redo, clipboard
/// actions through the view controller.
@MainActor
final class GridEditingFlowTests: XCTestCase {
    func makeDocumentAndController() -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["a", "b"], ["c", "d"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func testApplyEditsUpdatesControllerAndUndoRedo() throws {
        let (document, vc) = makeDocumentAndController()
        let undoManager = try XCTUnwrap(document.undoManager)

        document.applyEdits([CellEdit(row: 0, column: 0, value: "X")], actionName: "Edit Cell")
        XCTAssertEqual(document.content.table.rows[0][0], "X")
        XCTAssertEqual(vc.content.table.rows[0][0], "X")
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoActionName, "Edit Cell")

        undoManager.undo()
        XCTAssertEqual(document.content.table.rows[0][0], "a")
        XCTAssertEqual(vc.content.table.rows[0][0], "a")
        XCTAssertTrue(undoManager.canRedo)

        undoManager.redo()
        XCTAssertEqual(document.content.table.rows[0][0], "X")
        XCTAssertEqual(vc.content.table.rows[0][0], "X")
    }

    func testGrowingPasteAddsColumnsToTableView() {
        let (document, vc) = makeDocumentAndController()
        XCTAssertEqual(vc.tableView.tableColumns.count, 3) // row# + 2

        document.applyEdits([CellEdit(row: 0, column: 4, value: "wide")], actionName: "Paste")
        XCTAssertEqual(document.content.table.maxColumns, 5)
        XCTAssertEqual(vc.tableView.tableColumns.count, 6) // row# + 5
    }

    func testCopyPutsTSVOnPasteboard() {
        let (_, vc) = makeDocumentAndController()
        vc.selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1))
        vc.copy(nil)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "a\tb\nc\td\n")
    }

    func testPasteExpandsFromSingleCell() {
        let (document, vc) = makeDocumentAndController()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("1\t2\n3\t4\n", forType: .string)
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        vc.confirmPaste = { _ in
            XCTFail("no concern expected for a shape-matching paste")
            return false
        }
        vc.paste(nil)
        XCTAssertEqual(document.content.table.rows, [["1", "2"], ["3", "4"]])
        XCTAssertEqual(vc.selection, GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1)))
    }

    func testExtendingPasteAsksForConfirmation() {
        let (document, vc) = makeDocumentAndController()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("1\t2\t3\n", forType: .string)
        vc.selection = GridSelection(anchor: GridPosition(row: 1, column: 1))

        var asked: [PastePlanner.Concern] = []
        vc.confirmPaste = { concerns in
            asked = concerns
            return false // decline
        }
        vc.paste(nil)
        XCTAssertEqual(asked, [.extendsTable(newRowCount: 2, newColumnCount: 4)])
        XCTAssertEqual(document.content.table.rows, [["a", "b"], ["c", "d"]], "declined paste must not apply")

        vc.confirmPaste = { _ in true }
        vc.paste(nil)
        XCTAssertEqual(document.content.table.rows[1], ["c", "1", "2", "3"])
    }

    func testCutCopiesThenClears() {
        let (document, vc) = makeDocumentAndController()
        vc.selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 0, column: 1))
        vc.cut(nil)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "a\tb\n")
        XCTAssertEqual(document.content.table.rows, [["", ""], ["c", "d"]])

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.rows, [["a", "b"], ["c", "d"]])
    }

    func testSelectAllAndDelete() {
        let (document, vc) = makeDocumentAndController()
        vc.selectAll(nil)
        XCTAssertEqual(vc.selection, GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1)))
        vc.delete(nil)
        XCTAssertEqual(document.content.table.rows, [["", ""], ["", ""]])
    }

    func testUntitledDocumentHasStarterGrid() {
        let document = GridDocument()
        XCTAssertEqual(document.content.table.rows.count, 10)
        XCTAssertEqual(document.content.table.maxColumns, 5)
    }

    func testDataOfTypeSerializesCurrentContent() throws {
        let (document, _) = makeDocumentAndController()
        document.applyEdits([CellEdit(row: 0, column: 0, value: "X")], actionName: "Edit Cell")
        let data = try document.data(ofType: "CSV Document")
        XCTAssertEqual(String(data: data, encoding: .utf8), "X,b\nc,d\n")
    }
}
