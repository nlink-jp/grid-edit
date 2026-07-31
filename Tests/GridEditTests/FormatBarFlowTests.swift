import XCTest
import GridEditCore
@testable import GridEdit

final class SetHasHeaderTests: XCTestCase {
    func testPromoteFirstRowToHeader() {
        var content = DocumentContent(
            table: CSVTable(rows: [["a", "b"], ["1", "2"]]), hasHeader: false)
        XCTAssertTrue(content.setHasHeader(true))
        XCTAssertEqual(content.table.header, ["a", "b"])
        XCTAssertEqual(content.table.rows, [["1", "2"]])
        XCTAssertTrue(content.hasHeader)
    }

    func testDemoteHeaderToFirstRow() {
        var content = DocumentContent(
            table: CSVTable(header: ["a", "b"], rows: [["1", "2"]]), hasHeader: true)
        XCTAssertTrue(content.setHasHeader(false))
        XCTAssertNil(content.table.header)
        XCTAssertEqual(content.table.rows, [["a", "b"], ["1", "2"]])
    }

    func testToggleOnEmptyTable() {
        var content = DocumentContent(table: CSVTable(), hasHeader: false)
        XCTAssertTrue(content.setHasHeader(true))
        XCTAssertEqual(content.table.header, [])
        XCTAssertTrue(content.setHasHeader(false))
        XCTAssertNil(content.table.header)
        XCTAssertEqual(content.table.rows, [])
    }

    func testSameValueIsNoOp() {
        var content = DocumentContent(table: CSVTable(), hasHeader: false)
        XCTAssertFalse(content.setHasHeader(false))
    }

    func testRoundTripPreservesTable() {
        let original = DocumentContent(
            table: CSVTable(header: ["h1", "h2"], rows: [["1", "2"]]), hasHeader: true)
        var content = original
        content.setHasHeader(false)
        content.setHasHeader(true)
        XCTAssertEqual(content, original)
    }
}

@MainActor
final class FormatBarFlowTests: XCTestCase {
    func makeDocumentAndController() -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(header: ["h1", "h2"], rows: [["1", "2"]]),
            hasHeader: true)
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func testEncodingChangeIsUndoableAndAffectsOutput() throws {
        let (document, vc) = makeDocumentAndController()
        vc.formatBar.onEncodingChange?(.utf8bom)
        XCTAssertEqual(document.content.encoding, .utf8bom)
        XCTAssertEqual(document.undoManager?.undoActionName, "Change Encoding")
        let data = try document.data(ofType: "CSV Document")
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        document.undoManager?.undo()
        XCTAssertEqual(document.content.encoding, .utf8)
    }

    func testDelimiterChangeConvertsOnSave() throws {
        let (document, vc) = makeDocumentAndController()
        vc.formatBar.onDelimiterChange?(.semicolon)
        let data = try document.data(ofType: "CSV Document")
        XCTAssertEqual(String(data: data, encoding: .utf8), "h1;h2\n1;2\n")
    }

    func testLineEndingChange() throws {
        let (document, vc) = makeDocumentAndController()
        vc.formatBar.onLineEndingChange?(.crlf)
        let data = try document.data(ofType: "CSV Document")
        XCTAssertEqual(String(data: data, encoding: .utf8), "h1,h2\r\n1,2\r\n")
    }

    func testSameValueChangeRegistersNoUndo() {
        let (document, vc) = makeDocumentAndController()
        vc.formatBar.onEncodingChange?(.utf8)
        XCTAssertFalse(document.undoManager?.canUndo ?? true)
    }

    func testHeaderToggleUpdatesGridAndTitles() {
        let (document, vc) = makeDocumentAndController()
        vc.formatBar.onHeaderToggle?(false)
        XCTAssertNil(document.content.table.header)
        XCTAssertEqual(document.content.table.rows, [["h1", "h2"], ["1", "2"]])
        XCTAssertEqual(vc.tableView.numberOfRows, 2)
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "1", "headerless columns are numbered")

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.header, ["h1", "h2"])
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "h1")
    }
}
