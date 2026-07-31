import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class ColumnSelectionTests: XCTestCase {
    func makeController() -> GridViewController {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["a", "b", "c"], ["d", "e", "f"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        return vc
    }

    func testHeaderClickSelectsWholeColumn() {
        let vc = makeController()
        vc.selectColumn(1, extending: false)
        XCTAssertEqual(vc.selection, GridSelection(
            anchor: GridPosition(row: 0, column: 1),
            focus: GridPosition(row: 1, column: 1)))
    }

    func testShiftClickExtendsColumnRange() {
        let vc = makeController()
        vc.selectColumn(0, extending: false)
        vc.selectColumn(2, extending: true)
        XCTAssertEqual(vc.selection?.columnRange, 0...2)
        XCTAssertEqual(vc.selection?.rowRange, 0...1)
    }

    func testShiftClickWithoutSelectionSelectsColumn() {
        let vc = makeController()
        vc.selection = nil
        vc.selectColumn(1, extending: true)
        XCTAssertEqual(vc.selection?.columnRange, 1...1)
    }
}
