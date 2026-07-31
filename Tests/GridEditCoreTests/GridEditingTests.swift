import XCTest
@testable import GridEditCore

final class TableEditTests: XCTestCase {
    func testApplySingleEdit() {
        var table = CSVTable(rows: [["a", "b"], ["c", "d"]])
        table.apply([CellEdit(row: 1, column: 0, value: "X")])
        XCTAssertEqual(table.rows, [["a", "b"], ["X", "d"]])
    }

    func testApplyPadsRaggedRow() {
        var table = CSVTable(rows: [["a"]])
        table.apply([CellEdit(row: 0, column: 2, value: "X")])
        XCTAssertEqual(table.rows, [["a", "", "X"]])
    }

    func testApplyGrowsRows() {
        var table = CSVTable(rows: [["a"]])
        table.apply([CellEdit(row: 2, column: 1, value: "X")])
        XCTAssertEqual(table.rows, [["a"], [], ["", "X"]])
    }

    func testUndoRestoresExactState() {
        let original = CSVTable(rows: [["a", "b"], ["c"]])
        var table = original
        let undo = table.apply([
            CellEdit(row: 0, column: 0, value: "X"),
            CellEdit(row: 1, column: 2, value: "Y"),   // pads row 1
            CellEdit(row: 3, column: 0, value: "Z"),   // grows table
        ])
        XCTAssertEqual(table.rows, [["X", "b"], ["c", "", "Y"], [], ["Z"]])
        table.restore(undo)
        XCTAssertEqual(table, original)
    }

    func testUndoIsExactForPaddingToo() {
        let original = CSVTable(rows: [["a"]])
        var table = original
        let undo = table.apply([CellEdit(row: 0, column: 3, value: "X")])
        XCTAssertEqual(table.rows[0].count, 4)
        table.restore(undo)
        XCTAssertEqual(table, original) // padding reverted, not just the value
    }
}

final class PastePlannerTests: XCTestCase {
    let table = CSVTable(rows: [["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]])

    func testSingleCellPasteExpandsWithoutConcern() throws {
        let plan = try XCTUnwrap(PastePlanner.plan(
            block: [["1", "2"], ["3", "4"]],
            selection: GridSelection(anchor: GridPosition(row: 0, column: 0)),
            table: table))
        XCTAssertTrue(plan.concerns.isEmpty)
        XCTAssertEqual(plan.edits, [
            CellEdit(row: 0, column: 0, value: "1"),
            CellEdit(row: 0, column: 1, value: "2"),
            CellEdit(row: 1, column: 0, value: "3"),
            CellEdit(row: 1, column: 1, value: "4"),
        ])
        XCTAssertEqual(plan.pastedSelection, GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1)))
    }

    func testMatchingShapeHasNoConcern() throws {
        let selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 1, column: 1))
        let plan = try XCTUnwrap(PastePlanner.plan(
            block: [["1", "2"], ["3", "4"]], selection: selection, table: table))
        XCTAssertTrue(plan.concerns.isEmpty)
    }

    func testShapeMismatchOnMultiCellSelection() throws {
        let selection = GridSelection(
            anchor: GridPosition(row: 0, column: 0),
            focus: GridPosition(row: 2, column: 2))
        let plan = try XCTUnwrap(PastePlanner.plan(
            block: [["1", "2"]], selection: selection, table: table))
        XCTAssertEqual(plan.concerns, [
            .shapeMismatch(clipRows: 1, clipColumns: 2, selectionRows: 3, selectionColumns: 3),
        ])
    }

    func testExtendingPasteIsFlagged() throws {
        let plan = try XCTUnwrap(PastePlanner.plan(
            block: [["1", "2"], ["3", "4"]],
            selection: GridSelection(anchor: GridPosition(row: 2, column: 2)),
            table: table))
        XCTAssertEqual(plan.concerns, [
            .extendsTable(newRowCount: 4, newColumnCount: 4),
        ])
    }

    func testEmptyBlockYieldsNoPlan() {
        XCTAssertNil(PastePlanner.plan(
            block: [],
            selection: GridSelection(anchor: GridPosition(row: 0, column: 0)),
            table: table))
    }

    func testRaggedBlockWritesOnlyPresentCells() throws {
        let plan = try XCTUnwrap(PastePlanner.plan(
            block: [["1", "2"], ["3"]],
            selection: GridSelection(anchor: GridPosition(row: 0, column: 0)),
            table: table))
        XCTAssertEqual(plan.edits, [
            CellEdit(row: 0, column: 0, value: "1"),
            CellEdit(row: 0, column: 1, value: "2"),
            CellEdit(row: 1, column: 0, value: "3"),
        ])
    }
}
