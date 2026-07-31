import XCTest
@testable import GridEditCore

final class TextEncodingTests: XCTestCase {
    func testDetectBOM() {
        XCTAssertEqual(TextEncoding.detect(Data([0xEF, 0xBB, 0xBF, 0x61])), .utf8bom)
    }

    func testDetectValidUTF8() {
        XCTAssertEqual(TextEncoding.detect(Data("名前,年齢\n".utf8)), .utf8)
        XCTAssertEqual(TextEncoding.detect(Data("a,b\n".utf8)), .utf8)
        XCTAssertEqual(TextEncoding.detect(Data()), .utf8)
    }

    func testDetectInvalidUTF8FallsBackToCP932() {
        // 田 in CP932 is 0x93 0x63 — invalid as UTF-8.
        XCTAssertEqual(TextEncoding.detect(Data([0x93, 0x63])), .cp932)
    }

    func testDecodeCP932() throws {
        XCTAssertEqual(try TextEncoding.cp932.decode(Data([0x93, 0x63])), "田")
    }

    func testCP932ExtensionCharacterDecodes() throws {
        // ① (0x8740) exists in CP932 but not in strict Shift_JIS — the shared
        // codec must accept it, like Go's japanese.ShiftJIS does.
        XCTAssertEqual(try TextEncoding.shiftJIS.decode(Data([0x87, 0x40])), "①")
    }

    func testUTF8BOMDecodeStripsBOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(contentsOf: "abc".utf8)
        XCTAssertEqual(try TextEncoding.utf8bom.decode(data), "abc")
    }

    func testUTF8BOMEncodePrependsBOM() throws {
        XCTAssertEqual(
            Array(try TextEncoding.utf8bom.encode("a")),
            [0xEF, 0xBB, 0xBF, 0x61])
    }

    func testRoundTripAllEncodings() throws {
        let text = "id,名前\n1,田中\n"
        for encoding in TextEncoding.allCases {
            let data = try encoding.encode(text)
            XCTAssertEqual(try encoding.decode(data), text, "\(encoding)")
        }
    }

    func testEncodeUnrepresentableCharacterThrows() {
        XCTAssertThrowsError(try TextEncoding.cp932.encode("🙂"))
    }

    func testDecodeInvalidUTF8Throws() {
        XCTAssertThrowsError(try TextEncoding.utf8.decode(Data([0x93, 0x63])))
    }
}
