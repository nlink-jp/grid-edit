import XCTest
@testable import GridEditCore

final class DelimiterTests: XCTestCase {
    func testDetectsComma() {
        XCTAssertEqual(Delimiter.detect(in: "a,b,c\n1,2,3\n"), .comma)
    }

    func testDetectsTab() {
        XCTAssertEqual(Delimiter.detect(in: "a\tb\tc\n1\t2\t3\n"), .tab)
    }

    func testDetectsSemicolon() {
        XCTAssertEqual(Delimiter.detect(in: "a;b;c\n1;2;3\n"), .semicolon)
    }

    func testDetectionUsesFirstNonEmptyLine() {
        XCTAssertEqual(Delimiter.detect(in: "\n\na;b;c\n"), .semicolon)
    }

    func testNoDelimiterFallsBackToComma() {
        XCTAssertEqual(Delimiter.detect(in: "plain text\n"), .comma)
    }

    func testEmptySampleFallsBackToComma() {
        XCTAssertEqual(Delimiter.detect(in: ""), .comma)
    }
}
