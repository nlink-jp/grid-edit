import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class SelectionHighlightTests: XCTestCase {
    func makeController() -> GridViewController {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["a", "b", "c"], ["d", "e", "f"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        vc.tableView.layoutSubtreeIfNeeded()
        return vc
    }

    func testSelectionSpanCoversFullColumnRects() throws {
        let vc = makeController()
        vc.selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 0, column: 1))
        let span = try XCTUnwrap(vc.selectionSpan(forRow: 0))
        let firstRect = vc.tableView.rect(ofColumn: 1)
        let lastRect = vc.tableView.rect(ofColumn: 2)
        XCTAssertEqual(span.minX, firstRect.minX)
        XCTAssertEqual(span.maxX, lastRect.maxX, "span reaches the far grid line, not the label edge")
    }

    func testNoSpanOutsideSelectedRows() {
        let vc = makeController()
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        XCTAssertNotNil(vc.selectionSpan(forRow: 0))
        XCTAssertNil(vc.selectionSpan(forRow: 1))
        vc.selection = nil
        XCTAssertNil(vc.selectionSpan(forRow: 0))
    }

    func testRowViewCarriesSpan() throws {
        let vc = makeController()
        vc.selection = GridSelection(anchor: GridPosition(row: 1, column: 2))
        let rowView = try XCTUnwrap(
            vc.tableView(vc.tableView, rowViewForRow: 1) as? GridRowView)
        XCTAssertNotNil(rowView.selectionSpan)
        let unselected = try XCTUnwrap(
            vc.tableView(vc.tableView, rowViewForRow: 0) as? GridRowView)
        XCTAssertNil(unselected.selectionSpan)
    }

    func testCellLabelNeverDrawsBackground() throws {
        let vc = makeController()
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        let view = try XCTUnwrap(vc.tableView(
            vc.tableView, viewFor: vc.tableView.tableColumns[1], row: 0))
        XCTAssertEqual((view as? NSTextField)?.drawsBackground, false)
    }
}
