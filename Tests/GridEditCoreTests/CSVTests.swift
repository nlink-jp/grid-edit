import XCTest
@testable import GridEditCore

/// Parse/encode expectations ported from csv-editor's Go engine tests
/// (app/internal/csvio/csvio_test.go) — the regression baseline the RFP
/// commits to.
final class CSVParseTests: XCTestCase {
    func check(
        _ input: String, _ options: CSV.ParseOptions,
        header: [String]?, rows: [[String]],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let got = CSV.parse(input, options: options)
        XCTAssertEqual(got.header, header, "header", file: file, line: line)
        XCTAssertEqual(got.rows, rows, "rows", file: file, line: line)
    }

    func testSimpleCSVNoHeader() {
        check("a,b,c\n1,2,3\n", .init(), header: nil, rows: [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testSimpleCSVWithHeader() {
        check("name,age\nAlice,30\nBob,25\n", .init(hasHeader: true),
              header: ["name", "age"], rows: [["Alice", "30"], ["Bob", "25"]])
    }

    func testTSV() {
        check("a\tb\n1\t2\n", .init(delimiter: .tab), header: nil, rows: [["a", "b"], ["1", "2"]])
    }

    func testSemicolon() {
        check("a;b\n1;2\n", .init(delimiter: .semicolon), header: nil, rows: [["a", "b"], ["1", "2"]])
    }

    func testQuotedFieldWithEmbeddedComma() {
        check("name,note\nAlice,\"hello, world\"\n", .init(hasHeader: true),
              header: ["name", "note"], rows: [["Alice", "hello, world"]])
    }

    func testQuotedFieldWithEmbeddedNewline() {
        check("a,b\n\"line 1\nline 2\",\"x\"\n", .init(hasHeader: true),
              header: ["a", "b"], rows: [["line 1\nline 2", "x"]])
    }

    func testEscapedQuotes() {
        check("a,b\n\"she said \"\"hi\"\"\",y\n", .init(hasHeader: true),
              header: ["a", "b"], rows: [["she said \"hi\"", "y"]])
    }

    func testCRLFLineEndings() {
        check("a,b\r\n1,2\r\n", .init(hasHeader: true), header: ["a", "b"], rows: [["1", "2"]])
    }

    func testCROnlyLineEndings() {
        check("a,b\r1,2\r3,4\r", .init(), header: nil,
              rows: [["a", "b"], ["1", "2"], ["3", "4"]])
    }

    func testVariableColumnCounts() {
        check("a,b,c\n1,2\n3,4,5,6\n", .init(), header: nil,
              rows: [["a", "b", "c"], ["1", "2"], ["3", "4", "5", "6"]])
    }

    func testEmptyInput() {
        check("", .init(), header: nil, rows: [])
    }

    func testHeaderOnlyNoData() {
        check("a,b,c\n", .init(hasHeader: true), header: ["a", "b", "c"], rows: [])
    }

    func testEmptyCells() {
        check("a,,c\n,,\n", .init(), header: nil, rows: [["a", "", "c"], ["", "", ""]])
    }

    func testJapaneseContent() {
        check("名前,年齢\n田中,30\n", .init(hasHeader: true),
              header: ["名前", "年齢"], rows: [["田中", "30"]])
    }

    func testBlankLinesProduceNoRecord() {
        check("a,b\n\n1,2\n", .init(), header: nil, rows: [["a", "b"], ["1", "2"]])
    }

    func testQuotedEmptyFieldIsARecord() {
        check("\"\"\n", .init(), header: nil, rows: [[""]])
    }

    func testMissingTrailingNewline() {
        check("a,b\n1,2", .init(), header: nil, rows: [["a", "b"], ["1", "2"]])
    }

    func testLazyQuoteInUnquotedField() {
        check("a\"b,c\n", .init(), header: nil, rows: [["a\"b", "c"]])
    }

    func testLazyStrayQuoteInQuotedField() {
        check("\"a\"b\",c\n", .init(), header: nil, rows: [["a\"b", "c"]])
    }

    func testCRLFInsideQuotedFieldNormalizedToLF() {
        check("\"line 1\r\nline 2\",x\r\n", .init(), header: nil,
              rows: [["line 1\nline 2", "x"]])
    }

    func testMaxColumns() {
        XCTAssertEqual(CSVTable().maxColumns, 0)
        XCTAssertEqual(CSVTable(header: ["a", "b", "c"]).maxColumns, 3)
        XCTAssertEqual(CSVTable(rows: [["a", "b"], ["c"]]).maxColumns, 2)
        XCTAssertEqual(CSVTable(header: ["a"], rows: [["a", "b", "c"]]).maxColumns, 3)
        XCTAssertEqual(CSVTable(header: ["a", "b", "c"], rows: [["a"]]).maxColumns, 3)
    }
}

final class CSVEncodeTests: XCTestCase {
    func testSimpleCSVLF() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["a", "b"], ["1", "2"]])),
            "a,b\n1,2\n")
    }

    func testSimpleCSVCRLF() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["a", "b"], ["1", "2"]]),
                       options: .init(lineEnding: .crlf)),
            "a,b\r\n1,2\r\n")
    }

    func testTSV() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["a", "b"], ["1", "2"]]),
                       options: .init(delimiter: .tab)),
            "a\tb\n1\t2\n")
    }

    func testHeaderIncluded() {
        XCTAssertEqual(
            CSV.encode(CSVTable(header: ["name", "age"], rows: [["Alice", "30"]]),
                       options: .init(hasHeader: true)),
            "name,age\nAlice,30\n")
    }

    func testHeaderSkippedWhenHasHeaderFalse() {
        XCTAssertEqual(
            CSV.encode(CSVTable(header: ["name", "age"], rows: [["Alice", "30"]])),
            "Alice,30\n")
    }

    func testEmbeddedCommaIsQuoted() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["hello, world", "x"]])),
            "\"hello, world\",x\n")
    }

    func testEmbeddedQuoteIsEscaped() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["she said \"hi\"", "y"]])),
            "\"she said \"\"hi\"\"\",y\n")
    }

    func testJapaneseContent() {
        XCTAssertEqual(
            CSV.encode(CSVTable(header: ["名前", "年齢"], rows: [["田中", "30"]]),
                       options: .init(hasHeader: true)),
            "名前,年齢\n田中,30\n")
    }

    func testEmptyTable() {
        XCTAssertEqual(CSV.encode(CSVTable()), "")
    }

    func testLeadingWhitespaceIsQuoted() {
        // Go csv.Writer parity: fields with leading space/tab are quoted.
        XCTAssertEqual(CSV.encode(CSVTable(rows: [[" x", "y"]])), "\" x\",y\n")
    }

    func testCRLineEndingWritesLF() {
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["a", "b"]]), options: .init(lineEnding: .cr)),
            "a,b\n")
    }

    func testNewlineInFieldFollowsCRLFMode() {
        // Go csv.Writer parity: in CRLF mode, LF inside a quoted field
        // becomes CRLF and a lone CR is dropped.
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["l1\nl2", "x"]]), options: .init(lineEnding: .crlf)),
            "\"l1\r\nl2\",x\r\n")
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["l1\rl2", "x"]]), options: .init(lineEnding: .crlf)),
            "\"l1l2\",x\r\n")
        XCTAssertEqual(
            CSV.encode(CSVTable(rows: [["l1\rl2", "x"]])),
            "\"l1\rl2\",x\n")
    }

    func testParseEncodeRoundTrip() {
        let inputs = [
            "a,b,c\n1,2,3\n",
            "name,note\nAlice,\"hello, world\"\n",
            "a,b\n\"line 1\nline 2\",x\n",
        ]
        for input in inputs {
            let parsed = CSV.parse(input)
            XCTAssertEqual(CSV.encode(parsed), input)
        }
    }
}

final class LineEndingTests: XCTestCase {
    func testDetect() {
        XCTAssertEqual(LineEnding.detect(in: "a,b\r\n1,2\r\n"), .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a,b\n1,2\n"), .lf)
        XCTAssertEqual(LineEnding.detect(in: "a,b\r1,2\r"), .cr)
        XCTAssertEqual(LineEnding.detect(in: "a,b"), .lf)
        XCTAssertEqual(LineEnding.detect(in: ""), .lf)
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\nc"), .crlf)
    }
}
