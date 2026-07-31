import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class HeaderColumnPolishTests: XCTestCase {
    func makeDocumentAndController(
        header: [String]? = ["name", "count"],
        rows: [[String]] = [["Alice", "3"], ["Bob", "1200"]]
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

    func testNumericColumnIsRightAligned() throws {
        let (_, vc) = makeDocumentAndController()

        func alignment(column: Int) throws -> NSTextAlignment {
            let view = try XCTUnwrap(vc.tableView(
                vc.tableView, viewFor: vc.tableView.tableColumns[column + 1], row: 0))
            return try XCTUnwrap(view as? NSTextField).alignment
        }
        XCTAssertEqual(try alignment(column: 0), .natural)
        XCTAssertEqual(try alignment(column: 1), .right)
    }

    func testAlignmentUpdatesWhenColumnTurnsNonNumeric() throws {
        let (document, vc) = makeDocumentAndController()
        document.applyEdits([CellEdit(row: 0, column: 1, value: "n/a")], actionName: "Edit Cell")
        let view = try XCTUnwrap(vc.tableView(
            vc.tableView, viewFor: vc.tableView.tableColumns[2], row: 0))
        XCTAssertEqual((view as? NSTextField)?.alignment, .natural)
    }

    func testHeaderRenameThroughDocument() {
        let (document, vc) = makeDocumentAndController()
        vc.beginHeaderRename(column: 0)
        XCTAssertNotNil(vc.headerEditor)
        vc.headerEditor?.string = "renamed"
        vc.endHeaderRename(commit: true)
        XCTAssertEqual(document.content.table.header, ["renamed", "count"])
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "renamed")

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.header, ["name", "count"])
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "name")
    }

    func testHeaderRenameCancelKeepsTitle() {
        let (document, vc) = makeDocumentAndController()
        vc.beginHeaderRename(column: 0)
        vc.headerEditor?.string = "discarded"
        vc.endHeaderRename(commit: false)
        XCTAssertEqual(document.content.table.header, ["name", "count"])
        XCTAssertFalse(document.undoManager?.canUndo ?? true)
    }

    func testHeaderRenameRequiresHeader() {
        let (_, vc) = makeDocumentAndController(header: nil)
        vc.beginHeaderRename(column: 0)
        XCTAssertNil(vc.headerEditor)
    }

    func testIdealWidthGrowsWithContent() {
        let (_, vc) = makeDocumentAndController(
            header: ["h", "h2"],
            rows: [["short", "a considerably longer cell value here"], ["x", "y"]])
        let narrow = vc.idealWidth(forColumn: 0)
        let wide = vc.idealWidth(forColumn: 1)
        XCTAssertGreaterThan(wide, narrow)
        XCTAssertGreaterThanOrEqual(narrow, 24)
        XCTAssertLessThanOrEqual(wide, 600)
    }

    func testIdealWidthUsesLongestLineOfMultilineCell() {
        let (_, vc) = makeDocumentAndController(
            header: ["h"], rows: [["tiny\nthe-longest-line-in-the-cell\nmid"]])
        let (_, vc2) = makeDocumentAndController(
            header: ["h"], rows: [["the-longest-line-in-the-cell"]])
        XCTAssertEqual(vc.idealWidth(forColumn: 0), vc2.idealWidth(forColumn: 0), accuracy: 0.5)
    }

    func testAutoFitSetsColumnWidth() {
        let (_, vc) = makeDocumentAndController()
        let before = vc.tableView.tableColumns[1].width
        vc.autoFitColumn(0)
        XCTAssertNotEqual(vc.tableView.tableColumns[1].width, before)
        XCTAssertEqual(vc.tableView.tableColumns[1].width, vc.idealWidth(forColumn: 0), accuracy: 0.5)
    }
}
