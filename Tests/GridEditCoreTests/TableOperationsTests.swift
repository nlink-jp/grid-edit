import XCTest
@testable import GridEditCore

final class RowOperationsTests: XCTestCase {
    var table = CSVTable(rows: [["a", "b"], ["c", "d"], ["e", "f"]])

    func testInsertRows() {
        XCTAssertTrue(table.insertRows(at: 1, count: 2))
        XCTAssertEqual(table.rows, [["a", "b"], ["", ""], ["", ""], ["c", "d"], ["e", "f"]])
    }

    func testInsertRowsClampsIndex() {
        XCTAssertTrue(table.insertRows(at: 99, count: 1))
        XCTAssertEqual(table.rows.last, ["", ""])
        XCTAssertEqual(table.rows.count, 4)
    }

    func testInsertRowsPadsToMaxColumns() {
        var ragged = CSVTable(rows: [["a"], ["b", "c", "d"]])
        ragged.insertRows(at: 0, count: 1)
        XCTAssertEqual(ragged.rows[0], ["", "", ""])
    }

    func testDeleteRows() {
        XCTAssertTrue(table.deleteRows(startIndex: 1, count: 1))
        XCTAssertEqual(table.rows, [["a", "b"], ["e", "f"]])
    }

    func testDeleteRowsBeyondEndClamps() {
        XCTAssertTrue(table.deleteRows(startIndex: 1, count: 99))
        XCTAssertEqual(table.rows, [["a", "b"]])
    }

    func testDeleteRowsOutOfRangeIsNoOp() {
        XCTAssertFalse(table.deleteRows(startIndex: 3, count: 1))
    }

    func testDuplicateRowsInsertsBelowBlock() {
        XCTAssertTrue(table.duplicateRows(startIndex: 0, count: 2))
        XCTAssertEqual(table.rows, [["a", "b"], ["c", "d"], ["a", "b"], ["c", "d"], ["e", "f"]])
    }

    func testMoveRowsUp() {
        XCTAssertTrue(table.moveRows(startIndex: 1, count: 2, up: true))
        XCTAssertEqual(table.rows, [["c", "d"], ["e", "f"], ["a", "b"]])
    }

    func testMoveRowsDown() {
        XCTAssertTrue(table.moveRows(startIndex: 0, count: 2, up: false))
        XCTAssertEqual(table.rows, [["e", "f"], ["a", "b"], ["c", "d"]])
    }

    func testMoveRowsAtEdgeIsNoOp() {
        XCTAssertFalse(table.moveRows(startIndex: 0, count: 1, up: true))
        XCTAssertFalse(table.moveRows(startIndex: 1, count: 2, up: false))
    }

    func testSnapshotRestoreRoundTrip() {
        let snap = table.snapshot()
        table.deleteRows(startIndex: 0, count: 3)
        table.insertRows(at: 0, count: 1)
        table.restore(snap)
        XCTAssertEqual(table.rows, [["a", "b"], ["c", "d"], ["e", "f"]])
    }
}

final class ColumnOperationsTests: XCTestCase {
    var table = CSVTable(
        header: ["h1", "h2", "h3"],
        rows: [["a", "b", "c"], ["d"], ["e", "f", "g"]])

    func testInsertColumns() {
        XCTAssertTrue(table.insertColumns(at: 1, count: 1))
        XCTAssertEqual(table.header, ["h1", "", "h2", "h3"])
        XCTAssertEqual(table.rows, [["a", "", "b", "c"], ["d", ""], ["e", "", "f", "g"]])
    }

    func testInsertColumnsPadsShortRows() {
        XCTAssertTrue(table.insertColumns(at: 2, count: 1))
        XCTAssertEqual(table.rows[1], ["d", "", ""])
    }

    func testDeleteColumns() {
        XCTAssertTrue(table.deleteColumns(startIndex: 1, count: 1))
        XCTAssertEqual(table.header, ["h1", "h3"])
        XCTAssertEqual(table.rows, [["a", "c"], ["d"], ["e", "g"]])
    }

    func testDeleteColumnsSkipsShortRows() {
        XCTAssertTrue(table.deleteColumns(startIndex: 2, count: 5))
        XCTAssertEqual(table.rows, [["a", "b"], ["d"], ["e", "f"]])
        XCTAssertEqual(table.header, ["h1", "h2"])
    }

    func testDuplicateColumns() {
        XCTAssertTrue(table.duplicateColumns(startIndex: 0, count: 2))
        XCTAssertEqual(table.header, ["h1", "h2", "h1", "h2", "h3"])
        XCTAssertEqual(table.rows[0], ["a", "b", "a", "b", "c"])
        // Short row: block truncated at row end, padded copy inserted.
        XCTAssertEqual(table.rows[1], ["d", "d", ""])
    }

    func testMoveColumnsLeft() {
        XCTAssertTrue(table.moveColumns(startIndex: 1, count: 2, left: true))
        XCTAssertEqual(table.header, ["h2", "h3", "h1"])
        XCTAssertEqual(table.rows[0], ["b", "c", "a"])
        XCTAssertEqual(table.rows[1], ["", "", "d"]) // short row padded through reorder
    }

    func testMoveColumnsRight() {
        XCTAssertTrue(table.moveColumns(startIndex: 0, count: 1, left: false))
        XCTAssertEqual(table.header, ["h2", "h1", "h3"])
        XCTAssertEqual(table.rows[0], ["b", "a", "c"])
    }

    func testMoveColumnsAtEdgeIsNoOp() {
        XCTAssertFalse(table.moveColumns(startIndex: 0, count: 1, left: true))
        XCTAssertFalse(table.moveColumns(startIndex: 1, count: 2, left: false))
    }

    func testRenameColumn() {
        XCTAssertTrue(table.renameColumn(at: 1, to: "renamed"))
        XCTAssertEqual(table.header, ["h1", "renamed", "h3"])
        XCTAssertFalse(table.renameColumn(at: 1, to: "renamed"), "same value is a no-op")
    }

    func testRenameColumnPadsHeader() {
        XCTAssertTrue(table.renameColumn(at: 4, to: "x"))
        XCTAssertEqual(table.header, ["h1", "h2", "h3", "", "x"])
    }
}

final class SortTests: XCTestCase {
    func testNumericDetection() {
        XCTAssertTrue(ColumnTyping.isNumericString("42"))
        XCTAssertTrue(ColumnTyping.isNumericString("-3.5"))
        XCTAssertTrue(ColumnTyping.isNumericString(".5"))
        XCTAssertTrue(ColumnTyping.isNumericString("1e10"))
        XCTAssertTrue(ColumnTyping.isNumericString(" 7 "))
        XCTAssertFalse(ColumnTyping.isNumericString(""))
        XCTAssertFalse(ColumnTyping.isNumericString("abc"))
        XCTAssertFalse(ColumnTyping.isNumericString("1,000"))
    }

    func testAutoModeSortsNumericallyWhenBothNumeric() {
        var table = CSVTable(rows: [["10"], ["9"], ["100"]])
        table.sortRows(by: [SortKey(columnIndex: 0, ascending: true)])
        XCTAssertEqual(table.rows, [["9"], ["10"], ["100"]])
    }

    func testStringSort() {
        var table = CSVTable(rows: [["banana"], ["apple"], ["cherry"]])
        table.sortRows(by: [SortKey(columnIndex: 0, ascending: true)])
        XCTAssertEqual(table.rows, [["apple"], ["banana"], ["cherry"]])
    }

    func testDescending() {
        var table = CSVTable(rows: [["1"], ["3"], ["2"]])
        table.sortRows(by: [SortKey(columnIndex: 0, ascending: false)])
        XCTAssertEqual(table.rows, [["3"], ["2"], ["1"]])
    }

    func testEmptyCellsSortToEndAscending() {
        // csv-editor parity: empties sort last ascending (and consequently
        // first descending — the key negation flips them).
        var table = CSVTable(rows: [[""], ["b"], ["a"]])
        table.sortRows(by: [SortKey(columnIndex: 0, ascending: true)])
        XCTAssertEqual(table.rows, [["a"], ["b"], [""]])
        table.sortRows(by: [SortKey(columnIndex: 0, ascending: false)])
        XCTAssertEqual(table.rows, [[""], ["b"], ["a"]])
    }

    func testMultiKey() {
        var table = CSVTable(rows: [
            ["b", "2"], ["a", "2"], ["b", "1"], ["a", "1"],
        ])
        table.sortRows(by: [
            SortKey(columnIndex: 0, ascending: true),
            SortKey(columnIndex: 1, ascending: false),
        ])
        XCTAssertEqual(table.rows, [["a", "2"], ["a", "1"], ["b", "2"], ["b", "1"]])
    }

    func testStableForEqualKeys() {
        var table = CSVTable(rows: [["x", "1"], ["y", "1"], ["z", "1"]])
        table.sortRows(by: [SortKey(columnIndex: 1, ascending: true)])
        XCTAssertEqual(table.rows, [["x", "1"], ["y", "1"], ["z", "1"]])
    }

    func testNoChangeReturnsFalse() {
        var table = CSVTable(rows: [["a"], ["b"]])
        XCTAssertFalse(table.sortRows(by: [SortKey(columnIndex: 0, ascending: true)]))
        XCTAssertFalse(table.sortRows(by: []))
    }

    func testShortRowsTreatedAsEmpty() {
        var table = CSVTable(rows: [["x", "2"], ["y"], ["z", "1"]])
        table.sortRows(by: [SortKey(columnIndex: 1, ascending: true)])
        XCTAssertEqual(table.rows, [["z", "1"], ["x", "2"], ["y"]])
    }

    func testInferNumericColumns() {
        let rows = [["1", "a", ""], ["2.5", "b", ""], ["", "c", ""]]
        XCTAssertEqual(
            ColumnTyping.inferNumericColumns(rows: rows, columnCount: 3),
            [true, false, false]) // empty column is not numeric
    }
}
