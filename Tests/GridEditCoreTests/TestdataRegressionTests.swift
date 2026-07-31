import XCTest
@testable import GridEditCore

/// End-to-end regression against csv-editor's testdata files — the RFP's
/// parity baseline. The files are byte-for-byte copies from
/// csv-editor/testdata/.
final class TestdataRegressionTests: XCTestCase {
    func load(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "testdata/\(name)", withExtension: nil),
            "missing test resource \(name)")
        return try Data(contentsOf: url)
    }

    /// The canonical parsed form of sample-utf8.csv / sample-cp932.csv
    /// (identical content, different byte encodings).
    private let expectedSample = CSVTable(
        header: ["id", "name", "department", "note"],
        rows: [
            ["1", "田中太郎", "営業部", "カンマ,込みのメモ"],
            ["2", "鈴木花子", "開発部", "複数行\nにまたがる\nセル"],
            ["3", "Yamada", "QA", "hello, \"quoted\" world"],
            ["4", "佐藤", "人事", "普通のセル"],
            ["5", "Watanabe", "Marketing", ""],
        ])

    func testSampleUTF8() throws {
        let data = try load("sample-utf8.csv")
        let encoding = TextEncoding.detect(data)
        XCTAssertEqual(encoding, .utf8)
        let text = try encoding.decode(data)
        XCTAssertEqual(LineEnding.detect(in: text), .lf)
        XCTAssertEqual(Delimiter.detect(in: text), .comma)
        let table = CSV.parse(text, options: .init(hasHeader: true))
        XCTAssertEqual(table, expectedSample)
    }

    func testSampleUTF8BOM() throws {
        let data = try load("sample-utf8-bom.csv")
        let encoding = TextEncoding.detect(data)
        XCTAssertEqual(encoding, .utf8bom)
        let table = CSV.parse(try encoding.decode(data), options: .init(hasHeader: true))
        XCTAssertEqual(table, expectedSample)
    }

    func testSampleCP932() throws {
        let data = try load("sample-cp932.csv")
        let encoding = TextEncoding.detect(data)
        XCTAssertEqual(encoding, .cp932)
        let table = CSV.parse(try encoding.decode(data), options: .init(hasHeader: true))
        XCTAssertEqual(table, expectedSample)
    }

    func testSampleTSV() throws {
        let data = try load("sample-utf8.tsv")
        let text = try TextEncoding.detect(data).decode(data)
        XCTAssertEqual(Delimiter.detect(in: text), .tab)
        let table = CSV.parse(text, options: .init(delimiter: .tab, hasHeader: true))
        XCTAssertEqual(table.header, ["id", "name", "department", "note"])
        XCTAssertEqual(table.rows, [
            ["1", "田中太郎", "営業部", "タブ区切りファイル"],
            ["2", "鈴木花子", "開発部", "日本語入り"],
            ["3", "Yamada", "QA", "English"],
        ])
    }

    func testLarge10k() throws {
        let data = try load("large-10k.csv")
        let text = try TextEncoding.detect(data).decode(data)
        let table = CSV.parse(text, options: .init(hasHeader: true))
        XCTAssertEqual(table.header, ["id", "name", "value", "note"])
        XCTAssertEqual(table.rows.count, 10000)
        XCTAssertEqual(table.rows.first, ["1", "name-1", "7", "日本語テキスト1"])
        XCTAssertEqual(table.rows.last, ["10000", "name-10000", "70000", "日本語テキスト10000"])
        XCTAssertEqual(table.maxColumns, 4)
    }

    func testRoundTripPreservesBytes() throws {
        // open → save with detected settings must reproduce the file exactly.
        for name in ["sample-utf8.csv", "sample-utf8-bom.csv", "sample-cp932.csv", "large-10k.csv"] {
            let data = try load(name)
            let encoding = TextEncoding.detect(data)
            let text = try encoding.decode(data)
            let table = CSV.parse(text, options: .init(hasHeader: true))
            let out = CSV.encode(table, options: .init(
                delimiter: .comma,
                lineEnding: LineEnding.detect(in: text),
                hasHeader: true))
            XCTAssertEqual(try encoding.encode(out), data, "\(name) did not round-trip")
        }
    }

    func testTSVRoundTripPreservesBytes() throws {
        let data = try load("sample-utf8.tsv")
        let encoding = TextEncoding.detect(data)
        let text = try encoding.decode(data)
        let table = CSV.parse(text, options: .init(delimiter: .tab, hasHeader: true))
        let out = CSV.encode(table, options: .init(
            delimiter: .tab,
            lineEnding: LineEnding.detect(in: text),
            hasHeader: true))
        XCTAssertEqual(try encoding.encode(out), data)
    }
}
