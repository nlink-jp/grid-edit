import XCTest
import GridEditCore
@testable import GridEdit

@MainActor
final class GridViewControllerTests: XCTestCase {
    func makeContent(hasHeader: Bool = true) -> DocumentContent {
        DocumentContent(
            table: CSVTable(
                header: hasHeader ? ["name", "age"] : nil,
                rows: [["Alice", "30"], ["Bob", "25"], ["Carol", "41"]]),
            hasHeader: hasHeader)
    }

    func testColumnsAndRowsMatchTable() {
        let vc = GridViewController(content: makeContent())
        _ = vc.view
        // row-number column + 2 data columns
        XCTAssertEqual(vc.tableView.tableColumns.count, 3)
        XCTAssertEqual(vc.tableView.numberOfRows, 3)
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "name")
        XCTAssertEqual(vc.tableView.tableColumns[2].title, "age")
    }

    func testHeaderlessColumnsAreNumbered() {
        let vc = GridViewController(content: makeContent(hasHeader: false))
        _ = vc.view
        XCTAssertEqual(vc.tableView.tableColumns[1].title, "1")
        XCTAssertEqual(vc.tableView.tableColumns[2].title, "2")
    }

    func testCellValuesAndRaggedRowPadding() throws {
        var content = makeContent()
        content.table.rows.append(["Dave"]) // ragged: no second cell
        let vc = GridViewController(content: content)
        _ = vc.view

        func cellText(row: Int, column: Int) throws -> String {
            let view = try XCTUnwrap(vc.tableView(
                vc.tableView, viewFor: vc.tableView.tableColumns[column], row: row))
            return try XCTUnwrap(view as? NSTextField).stringValue
        }

        XCTAssertEqual(try cellText(row: 0, column: 0), "1") // row number
        XCTAssertEqual(try cellText(row: 0, column: 1), "Alice")
        XCTAssertEqual(try cellText(row: 1, column: 2), "25")
        XCTAssertEqual(try cellText(row: 3, column: 1), "Dave")
        XCTAssertEqual(try cellText(row: 3, column: 2), "") // padded blank
    }

    func testDataColumnIndexRoundTrip() {
        let column = NSTableColumn(identifier: GridViewController.dataColumnID(7))
        XCTAssertEqual(GridViewController.dataColumnIndex(of: column), 7)
        let rowNumber = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("gridedit.rownumber"))
        XCTAssertNil(GridViewController.dataColumnIndex(of: rowNumber))
    }
}
