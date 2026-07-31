import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class SortIndicatorTests: XCTestCase {
    func makeDocumentAndController() -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["3", "x"], ["1", "y"], ["2", "z"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    private func indicator(_ vc: GridViewController, column: Int) -> NSImage? {
        vc.tableView.indicatorImage(in: vc.tableView.tableColumns[column + 1])
    }

    func testSortShowsIndicatorOnSortedColumn() {
        let (_, vc) = makeDocumentAndController()
        vc.sortByColumns(0...0, ascending: true)
        XCTAssertEqual(indicator(vc, column: 0)?.name(), "NSAscendingSortIndicator")
        XCTAssertNil(indicator(vc, column: 1))

        vc.sortByColumns(0...0, ascending: false)
        XCTAssertEqual(indicator(vc, column: 0)?.name(), "NSDescendingSortIndicator")
    }

    func testAlreadySortedNoOpStillShowsIndicator() {
        let (_, vc) = makeDocumentAndController()
        vc.sortByColumns(0...0, ascending: true)
        vc.sortByColumns(0...0, ascending: true) // no-op: already sorted
        XCTAssertEqual(indicator(vc, column: 0)?.name(), "NSAscendingSortIndicator")
    }

    func testEditClearsIndicator() {
        let (document, vc) = makeDocumentAndController()
        vc.sortByColumns(0...0, ascending: true)
        document.applyEdits([CellEdit(row: 0, column: 0, value: "9")], actionName: "Edit Cell")
        XCTAssertNil(indicator(vc, column: 0), "an edit may break the order — indicator clears")
    }

    func testUndoOfSortClearsIndicator() {
        let (document, vc) = makeDocumentAndController()
        vc.sortByColumns(0...0, ascending: true)
        document.undoManager?.undo()
        XCTAssertNil(indicator(vc, column: 0))
    }

    func testMultiColumnSortMarksAllKeys() {
        let (_, vc) = makeDocumentAndController()
        vc.sortByColumns(0...1, ascending: true)
        XCTAssertNotNil(indicator(vc, column: 0))
        XCTAssertNotNil(indicator(vc, column: 1))
    }
}
