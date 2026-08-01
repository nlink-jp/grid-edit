import XCTest
import GridEditCore
@testable import GridEdit

final class MinimumGridCoreTests: XCTestCase {
    func testEmptyTableGainsOneCell() {
        var table = CSVTable()
        table.ensureMinimumGrid()
        XCTAssertEqual(table.rows, [[""]])
    }

    func testHeaderOnlyTableGainsRowOfHeaderWidth() {
        var table = CSVTable(header: ["a", "b", "c"])
        table.ensureMinimumGrid()
        XCTAssertEqual(table.rows, [["", "", ""]])
    }

    func testZeroWidthRowsGainOneColumn() {
        var table = CSVTable(rows: [[], []])
        table.ensureMinimumGrid()
        XCTAssertEqual(table.rows, [[""], [""]])
    }

    func testHealthyTableUntouched() {
        var table = CSVTable(rows: [["a"]])
        table.ensureMinimumGrid()
        XCTAssertEqual(table.rows, [["a"]])
    }

    func testOpeningEmptyFileYieldsEditableGrid() throws {
        let content = try DocumentIO.read(Data(), filename: "empty.csv")
        XCTAssertEqual(content.table.rows, [[""]])
    }

    func testOpeningHeaderOnlyFileYieldsEditableGrid() throws {
        let content = try DocumentIO.read(Data("a,b\n".utf8), filename: "x.csv")
        XCTAssertEqual(content.table.header, ["a", "b"])
        XCTAssertEqual(content.table.rows, [["", ""]])
    }

    func testBlankLinesOnlyFileYieldsEditableGrid() throws {
        let content = try DocumentIO.read(Data("\n\n\n".utf8), filename: "x.csv", hasHeader: false)
        XCTAssertEqual(content.table.rows, [[""]])
    }
}

@MainActor
final class MinimumGridFlowTests: XCTestCase {
    func makeDocumentAndController() -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(table: CSVTable(rows: [["a", "b"], ["c", "d"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func testDeletingAllRowsLeavesAnEditableRow() {
        let (document, vc) = makeDocumentAndController()
        vc.deleteRows(0...1)
        // Width information dies with the rows (no header) — a 1×1 grid
        // is the correct floor.
        XCTAssertEqual(document.content.table.rows, [[""]])
        XCTAssertNotNil(vc.selection, "a cell stays selectable")
        XCTAssertEqual(vc.tableView.numberOfRows, 1)

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.rows, [["a", "b"], ["c", "d"]])
    }

    func testDeletingAllColumnsLeavesAnEditableColumn() {
        let (document, vc) = makeDocumentAndController()
        vc.deleteColumns(0...1)
        XCTAssertEqual(document.content.table.rows, [[""], [""]])
        XCTAssertEqual(vc.tableView.tableColumns.count, 2) // row# + 1
    }

    func testHeaderToggleOnSingleRowKeepsAGridRow() {
        let (document, vc) = makeDocumentAndController()
        document.content = DocumentContent(table: CSVTable(rows: [["a", "b"]]))
        vc.contentDidChange(document.content)
        vc.formatBar.onHeaderToggle?(true)
        XCTAssertEqual(document.content.table.header, ["a", "b"])
        XCTAssertEqual(document.content.table.rows, [["", ""]], "promoting the only row must not empty the grid")
    }
}
