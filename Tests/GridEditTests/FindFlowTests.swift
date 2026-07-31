import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class FindFlowTests: XCTestCase {
    func makeDocumentAndController() -> (GridDocument, GridViewController) {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["apple", "banana"], ["pineapple", "cherry"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return (document, vc)
    }

    func openFindBar(_ vc: GridViewController, query: String) {
        vc.performTextFinderShow(nil)
        vc.findBar.searchField.stringValue = query
        vc.refreshFind(jumpToFirst: true)
    }

    func testIncrementalSearchSelectsFirstMatch() {
        let (_, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        XCTAssertEqual(vc.findMatches.count, 2)
        XCTAssertEqual(vc.findCurrentIndex, 0)
        XCTAssertEqual(vc.selection, GridSelection(anchor: GridPosition(row: 0, column: 0)))
    }

    func testFindNextWrapsAround() {
        let (_, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        vc.findNext(nil)
        XCTAssertEqual(vc.selection?.focus, GridPosition(row: 1, column: 0))
        vc.findNext(nil)
        XCTAssertEqual(vc.selection?.focus, GridPosition(row: 0, column: 0), "wraps")
        vc.findPrevious(nil)
        XCTAssertEqual(vc.selection?.focus, GridPosition(row: 1, column: 0), "wraps back")
    }

    func testMatchesRefreshAfterContentChange() {
        let (document, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        XCTAssertEqual(vc.findMatches.count, 2)
        document.applyEdits(
            [CellEdit(row: 0, column: 0, value: "grape")], actionName: "Edit Cell")
        XCTAssertEqual(vc.findMatches.count, 1, "matches recompute on edit")
    }

    func testReplaceAllIsOneUndoStep() {
        let (document, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        vc.findBar.onReplaceAll?("kiwi")
        XCTAssertEqual(document.content.table.rows, [["kiwi", "banana"], ["pinekiwi", "cherry"]])
        XCTAssertEqual(vc.findMatches.count, 0)

        document.undoManager?.undo()
        XCTAssertEqual(document.content.table.rows, [["apple", "banana"], ["pineapple", "cherry"]])
        XCTAssertEqual(vc.findMatches.count, 2, "matches restored after undo")
    }

    func testReplaceOneAdvances() {
        let (document, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        vc.findBar.onReplaceOne?("kiwi")
        XCTAssertEqual(document.content.table.rows[0][0], "kiwi")
        XCTAssertEqual(vc.findMatches.count, 1)
        XCTAssertEqual(vc.selection?.focus, GridPosition(row: 1, column: 0), "lands on the next match")
    }

    func testCloseClearsState() {
        let (_, vc) = makeDocumentAndController()
        openFindBar(vc, query: "apple")
        vc.closeFindBar()
        XCTAssertTrue(vc.findBar.isHidden)
        XCTAssertEqual(vc.findMatches.count, 0)
        XCTAssertNil(vc.findCurrentIndex)
    }
}
