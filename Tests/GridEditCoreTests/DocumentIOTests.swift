import XCTest
@testable import GridEditCore

final class DocumentIOTests: XCTestCase {
    func testReadDetectsEverything() throws {
        let content = try DocumentIO.read(Data("a;b\r\n1;2\r\n".utf8), filename: "x.csv")
        XCTAssertEqual(content.encoding, .utf8)
        XCTAssertEqual(content.delimiter, .semicolon)
        XCTAssertEqual(content.lineEnding, .crlf)
        XCTAssertTrue(content.hasHeader)
        XCTAssertEqual(content.table.header, ["a", "b"])
        XCTAssertEqual(content.table.rows, [["1", "2"]])
    }

    func testReadWithoutHeader() throws {
        let content = try DocumentIO.read(Data("a,b\n1,2\n".utf8), hasHeader: false)
        XCTAssertNil(content.table.header)
        XCTAssertEqual(content.table.rows, [["a", "b"], ["1", "2"]])
    }

    func testTSVExtensionForcesTabWhenNoDelimiterInContent() throws {
        let content = try DocumentIO.read(Data("single\nvalue\n".utf8), filename: "x.tsv")
        XCTAssertEqual(content.delimiter, .tab)
    }

    func testTSVExtensionDoesNotOverrideDetectedContent() throws {
        let content = try DocumentIO.read(Data("a\tb\n1\t2\n".utf8), filename: "x.tsv")
        XCTAssertEqual(content.delimiter, .tab)
        let csvContent = try DocumentIO.read(Data("a,b\n1,2\n".utf8), filename: "renamed.tsv")
        XCTAssertEqual(csvContent.delimiter, .comma)
    }

    func testCSVWithoutDelimiterStaysComma() throws {
        let content = try DocumentIO.read(Data("single\nvalue\n".utf8), filename: "x.csv")
        XCTAssertEqual(content.delimiter, .comma)
    }

    func testWriteUsesContentSettings() throws {
        var content = try DocumentIO.read(Data("a,b\n1,2\n".utf8))
        content.delimiter = .semicolon
        content.lineEnding = .crlf
        content.encoding = .utf8bom
        let out = try DocumentIO.write(content)
        XCTAssertEqual(Array(out.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(
            String(data: out.dropFirst(3), encoding: .utf8),
            "a;b\r\n1;2\r\n")
    }

    func testReadWriteRoundTripCP932() throws {
        let original = try TextEncoding.cp932.encode("名前,年齢\n田中,30\n")
        let content = try DocumentIO.read(original, filename: "x.csv")
        XCTAssertEqual(content.encoding, .cp932)
        XCTAssertEqual(try DocumentIO.write(content), original)
    }

    func testTooLargeIsRefused() {
        // maxFileSize is a constant; fabricate the error path via a Data
        // whose count exceeds it without allocating 500 MB for real.
        XCTAssertThrowsError(
            try DocumentIO.read(Data(count: DocumentIO.maxFileSize + 1))
        ) { error in
            XCTAssertEqual(
                error as? DocumentIO.DocumentError,
                .tooLarge(byteCount: DocumentIO.maxFileSize + 1))
        }
    }

    func testErrorMessagesAreHumanReadable() {
        let message = DocumentIO.DocumentError
            .tooLarge(byteCount: DocumentIO.maxFileSize + 1)
            .errorDescription
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("500 MB") ?? false, "\(message ?? "nil")")
    }
}
