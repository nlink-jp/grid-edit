import XCTest
@testable import GridEditCore

final class FindTests: XCTestCase {
    let rows = [
        ["Apple pie", "banana"],
        ["apple", "PINEAPPLE"],
        ["cherry", ""],
    ]

    func testCaseInsensitiveByDefault() {
        let matches = Find.matches(query: "apple", options: FindOptions(), rows: rows)
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0], FindMatch(row: 0, column: 0, matchStart: 0, matchEnd: 5))
        XCTAssertEqual(matches[1], FindMatch(row: 1, column: 0, matchStart: 0, matchEnd: 5))
        XCTAssertEqual(matches[2], FindMatch(row: 1, column: 1, matchStart: 4, matchEnd: 9))
    }

    func testCaseSensitive() {
        let matches = Find.matches(
            query: "apple", options: FindOptions(caseSensitive: true), rows: rows)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].row, 1)
    }

    func testWholeCell() {
        let matches = Find.matches(
            query: "apple", options: FindOptions(wholeCell: true), rows: rows)
        XCTAssertEqual(matches, [FindMatch(row: 1, column: 0, matchStart: 0, matchEnd: 5)])
    }

    func testRegexMode() {
        let matches = Find.matches(
            query: "^[ac]", options: FindOptions(regex: true), rows: rows)
        XCTAssertEqual(matches.count, 3) // Apple(pie), apple, cherry (case-insensitive)
    }

    func testInvalidRegexYieldsNoMatches() {
        XCTAssertEqual(
            Find.matches(query: "([", options: FindOptions(regex: true), rows: rows), [])
    }

    func testEmptyQueryYieldsNoMatches() {
        XCTAssertEqual(Find.matches(query: "", options: FindOptions(), rows: rows), [])
    }

    func testLiteralModeEscapesMetacharacters() {
        let rows = [["a.c", "abc"]]
        let matches = Find.matches(query: "a.c", options: FindOptions(), rows: rows)
        XCTAssertEqual(matches, [FindMatch(row: 0, column: 0, matchStart: 0, matchEnd: 3)])
    }

    func testMultipleMatchesInOneCell() {
        let rows = [["aXaXa"]]
        let matches = Find.matches(query: "a", options: FindOptions(), rows: rows)
        XCTAssertEqual(matches.count, 3)
    }

    func testJapaneseQuery() {
        let rows = [["東京都", "京都府"]]
        let matches = Find.matches(query: "京都", options: FindOptions(), rows: rows)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0], FindMatch(row: 0, column: 0, matchStart: 1, matchEnd: 3))
        XCTAssertEqual(matches[1], FindMatch(row: 0, column: 1, matchStart: 0, matchEnd: 2))
    }

    func testReplaceAllLiteral() {
        let edits = Find.replaceAllEdits(
            query: "apple", replacement: "kiwi", options: FindOptions(), rows: rows)
        XCTAssertEqual(edits, [
            CellEdit(row: 0, column: 0, value: "kiwi pie"),
            CellEdit(row: 1, column: 0, value: "kiwi"),
            CellEdit(row: 1, column: 1, value: "PINEkiwi"),
        ])
    }

    func testReplaceAllLiteralDollarIsLiteral() {
        let rows = [["price"]]
        let edits = Find.replaceAllEdits(
            query: "price", replacement: "$1", options: FindOptions(), rows: rows)
        XCTAssertEqual(edits, [CellEdit(row: 0, column: 0, value: "$1")])
    }

    func testReplaceAllRegexTemplate() {
        let rows = [["2026-08-01"]]
        let edits = Find.replaceAllEdits(
            query: #"(\d+)-(\d+)-(\d+)"#, replacement: "$3/$2/$1",
            options: FindOptions(regex: true), rows: rows)
        XCTAssertEqual(edits, [CellEdit(row: 0, column: 0, value: "01/08/2026")])
    }

    func testReplaceAllWholeCell() {
        let edits = Find.replaceAllEdits(
            query: "apple", replacement: "kiwi",
            options: FindOptions(wholeCell: true), rows: rows)
        XCTAssertEqual(edits, [CellEdit(row: 1, column: 0, value: "kiwi")])
    }

    func testReplaceOne() {
        let match = FindMatch(row: 1, column: 1, matchStart: 4, matchEnd: 9)
        let edit = Find.replaceOneEdit(
            match: match, query: "apple", replacement: "kiwi",
            options: FindOptions(), rows: rows)
        XCTAssertEqual(edit, CellEdit(row: 1, column: 1, value: "PINEkiwi"))
    }

    func testReplaceOneRegexWithTemplate() {
        let rows = [["ab12cd34"]]
        let match = FindMatch(row: 0, column: 0, matchStart: 6, matchEnd: 8)
        let edit = Find.replaceOneEdit(
            match: match, query: #"(\d+)"#, replacement: "<$1>",
            options: FindOptions(regex: true), rows: rows)
        XCTAssertEqual(edit, CellEdit(row: 0, column: 0, value: "ab12cd<34>"))
    }

    func testReplaceOneStaleMatchIsNil() {
        let match = FindMatch(row: 9, column: 0, matchStart: 0, matchEnd: 1)
        XCTAssertNil(Find.replaceOneEdit(
            match: match, query: "a", replacement: "b",
            options: FindOptions(), rows: rows))
    }
}
