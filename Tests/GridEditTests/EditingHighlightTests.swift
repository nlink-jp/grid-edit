import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class EditingHighlightTests: XCTestCase {
    func makeController() -> GridViewController {
        let document = GridDocument()
        document.content = DocumentContent(
            table: CSVTable(rows: [["a", "b"], ["c", "d"]]))
        document.makeWindowControllers()
        let vc = document.windowControllers[0].contentViewController as! GridViewController
        _ = vc.view
        vc.tableView.layoutSubtreeIfNeeded()
        return vc
    }

    func testHighlightSuppressedWhileEditing() {
        let vc = makeController()
        vc.selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        XCTAssertNotNil(vc.selectionSpan(forRow: 0))

        vc.beginEdit()
        XCTAssertNil(vc.selectionSpan(forRow: 0), "no highlight while the editor is open")

        vc.commitEditIfNeeded()
        XCTAssertNotNil(vc.selectionSpan(forRow: 0), "highlight returns after the edit ends")
    }
}
