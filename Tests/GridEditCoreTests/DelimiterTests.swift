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

    func testDetectionSkipsLeadingEmptyLines() {
        XCTAssertEqual(Delimiter.detect(in: "\n\na;b;c\n"), .semicolon)
    }

    func testQuotedCommasDoNotFoolSemicolonDetection() {
        XCTAssertEqual(
            Delimiter.detect(in: "\"a,x\";b\n\"c,y\";d\n\"e,z\";f\n"),
            .semicolon)
    }

    func testDelimiterMustAppearOnEveryLine() {
        // One comma total vs a tab on every line: consistency wins.
        XCTAssertEqual(Delimiter.detect(in: "a\tb\nc,d\te\nf\tg\n"), .tab)
    }

    func testNoDelimiterFallsBackToComma() {
        XCTAssertEqual(Delimiter.detect(in: "plain text\n"), .comma)
    }

    func testEmptySampleFallsBackToComma() {
        XCTAssertEqual(Delimiter.detect(in: ""), .comma)
    }
}
