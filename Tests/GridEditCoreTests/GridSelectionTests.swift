import XCTest
@testable import GridEditCore

final class GridSelectionTests: XCTestCase {
    func testBoundsAreNormalized() {
        let selection = GridSelection(
            anchor: GridPosition(row: 5, column: 4),
            focus: GridPosition(row: 2, column: 6))
        XCTAssertEqual(selection.rowRange, 2...5)
        XCTAssertEqual(selection.columnRange, 4...6)
        XCTAssertEqual(selection.origin, GridPosition(row: 2, column: 4))
        XCTAssertFalse(selection.isSingleCell)
        XCTAssertTrue(selection.contains(row: 3, column: 5))
        XCTAssertFalse(selection.contains(row: 1, column: 5))
    }

    func testMoveCollapsesSelection() {
        let selection = GridSelection(
            anchor: GridPosition(row: 1, column: 1),
            focus: GridPosition(row: 3, column: 3))
        let moved = selection.moving(.down, rowCount: 10, columnCount: 10)
        XCTAssertEqual(moved, GridSelection(anchor: GridPosition(row: 4, column: 3)))
    }

    func testMoveExtendingKeepsAnchor() {
        let selection = GridSelection(anchor: GridPosition(row: 1, column: 1))
        let extended = selection
            .moving(.down, extending: true, rowCount: 10, columnCount: 10)
            .moving(.right, extending: true, rowCount: 10, columnCount: 10)
        XCTAssertEqual(extended.anchor, GridPosition(row: 1, column: 1))
        XCTAssertEqual(extended.focus, GridPosition(row: 2, column: 2))
    }

    func testMoveClampsAtBounds() {
        let selection = GridSelection(anchor: GridPosition(row: 0, column: 0))
        XCTAssertEqual(
            selection.moving(.up, rowCount: 3, columnCount: 3),
            GridSelection(anchor: GridPosition(row: 0, column: 0)))
        XCTAssertEqual(
            selection.moving(.left, rowCount: 3, columnCount: 3),
            GridSelection(anchor: GridPosition(row: 0, column: 0)))
    }

    func testMoveToEdge() {
        let selection = GridSelection(anchor: GridPosition(row: 1, column: 1))
        XCTAssertEqual(
            selection.moving(.down, toEdge: true, rowCount: 100, columnCount: 5).focus,
            GridPosition(row: 99, column: 1))
        XCTAssertEqual(
            selection.moving(.right, toEdge: true, rowCount: 100, columnCount: 5).focus,
            GridPosition(row: 1, column: 4))
    }

    func testBlockPadsRaggedRows() {
        let table = CSVTable(rows: [["a", "b", "c"], ["d"], ["e", "f"]])
        let selection = GridSelection(
            anchor: GridPosition(row: 0, column: 1),
            focus: GridPosition(row: 2, column: 2))
        XCTAssertEqual(
            selection.block(in: table),
            [["b", "c"], ["", ""], ["f", ""]])
    }
}

final class TSVTests: XCTestCase {
    func testEncodeSimple() {
        XCTAssertEqual(TSV.encode([["a", "b"], ["1", "2"]]), "a\tb\n1\t2\n")
    }

    func testEncodeEmpty() {
        XCTAssertEqual(TSV.encode([]), "")
    }

    func testEncodeQuotesSpecialCharacters() {
        XCTAssertEqual(TSV.encode([["a\tb", "c\nd", "e\"f"]]),
                       "\"a\tb\"\t\"c\nd\"\t\"e\"\"f\"\n")
    }

    func testDecodeSimple() {
        XCTAssertEqual(TSV.decode("a\tb\n1\t2\n"), [["a", "b"], ["1", "2"]])
    }

    func testDecodeTrailingNewlineAddsNoRow() {
        XCTAssertEqual(TSV.decode("a\n"), [["a"]])
        XCTAssertEqual(TSV.decode("a"), [["a"]])
    }

    func testDecodeQuotedFields() {
        XCTAssertEqual(TSV.decode("\"a\tb\"\t\"c\nd\"\t\"e\"\"f\"\n"),
                       [["a\tb", "c\nd", "e\"f"]])
    }

    func testDecodeCRLF() {
        XCTAssertEqual(TSV.decode("a\tb\r\n1\t2\r\n"), [["a", "b"], ["1", "2"]])
    }

    func testRoundTrip() {
        let block = [["a\tb", "c\nd"], ["e\"f", ""], ["", ""]]
        XCTAssertEqual(TSV.decode(TSV.encode(block)), block)
    }
}
