import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class MultilineRowTests: XCTestCase {
    func testLineCount() {
        XCTAssertEqual(GridViewController.lineCount(of: []), 1)
        XCTAssertEqual(GridViewController.lineCount(of: ["a", "b"]), 1)
        XCTAssertEqual(GridViewController.lineCount(of: ["a\nb", "c"]), 2)
        XCTAssertEqual(GridViewController.lineCount(of: ["a\nb", "x\ny\nz"]), 3)
    }

    func testRowHeightScalesWithLines() {
        let base = GridViewController.baseRowHeight
        XCTAssertEqual(GridViewController.rowHeight(forLineCount: 1), base)
        XCTAssertGreaterThan(GridViewController.rowHeight(forLineCount: 2), base)
    }

    func makeController(rows: [[String]]) -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(table: CSVTable(rows: rows))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func testHeightOfRowFollowsCellNewlines() {
        let (_, vc) = makeController(rows: [["a", "b"], ["multi\nline", "c"]])
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 0),
            GridViewController.baseRowHeight)
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 1),
            GridViewController.rowHeight(forLineCount: 2))
    }

    func testHeightUpdatesAfterEditAndUndo() throws {
        let (document, vc) = makeController(rows: [["a", "b"]])
        document.applyEdits([CellEdit(row: 0, column: 0, value: "x\ny\nz")], actionName: "Edit Cell")
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 0),
            GridViewController.rowHeight(forLineCount: 3))

        document.undoManager?.undo()
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 0),
            GridViewController.baseRowHeight)
    }

    func testHeightForRowsAddedByPaste() {
        let (document, vc) = makeController(rows: [["a"]])
        document.applyEdits([
            CellEdit(row: 2, column: 0, value: "p\nq"),
        ], actionName: "Paste")
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 1),
            GridViewController.baseRowHeight)
        XCTAssertEqual(
            vc.tableView(vc.tableView, heightOfRow: 2),
            GridViewController.rowHeight(forLineCount: 2))
    }

    func testEditingCellIsBlankedAndRestored() throws {
        let (_, vc) = makeController(rows: [["value", "b"]])
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        vc.beginEdit()

        func cellText() throws -> String {
            let view = try XCTUnwrap(vc.tableView(
                vc.tableView, viewFor: vc.tableView.tableColumns[1], row: 0))
            return try XCTUnwrap(view as? NSTextField).stringValue
        }
        XCTAssertEqual(try cellText(), "", "label under the editor must be blank")

        vc.commitEditIfNeeded() // unchanged value → cancel path
        XCTAssertEqual(try cellText(), "value")
    }
}
