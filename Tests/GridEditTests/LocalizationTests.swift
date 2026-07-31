import XCTest
@testable import GridEdit

final class LocalizationTests: XCTestCase {
    /// Parses a .strings file into its key set (line-based; our files are
    /// one `"key" = "value";` per line).
    private func keys(ofStringsFile path: String) throws -> Set<String> {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var keys: Set<String> = []
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\""),
                  let end = trimmed.range(of: "\" = ") else { continue }
            keys.insert(String(trimmed[trimmed.index(after: trimmed.startIndex)..<end.lowerBound]))
        }
        return keys
    }

    private func resourcePath(_ target: String, _ lang: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/GridEditTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/\(target)/Resources/\(lang).lproj/Localizable.strings")
            .path
    }

    func testJapaneseCoversEveryEnglishKey() throws {
        for target in ["GridEdit", "GridEditCore"] {
            let en = try keys(ofStringsFile: resourcePath(target, "en"))
            let ja = try keys(ofStringsFile: resourcePath(target, "ja"))
            XCTAssertFalse(en.isEmpty, "\(target): en table must not be empty")
            XCTAssertEqual(
                en.symmetricDifference(ja), [],
                "\(target): en/ja key sets must match")
        }
    }

    func testLocalizedLookupResolves() {
        // Whatever the process language, the key must resolve to a
        // non-empty string (missing keys echo back the key, which is
        // still non-empty — so also check a known translation pair).
        XCTAssertFalse(L("File").isEmpty)
        let ja = Bundle.module.path(forResource: "ja", ofType: "lproj")
            .flatMap(Bundle.init(path:))
        XCTAssertEqual(
            ja?.localizedString(forKey: "File", value: nil, table: nil),
            "ファイル")
    }

    func testPluralHelper() {
        XCTAssertEqual(
            LPlural(1, one: "Insert Row Above", other: "Insert %d Rows Above"),
            L("Insert Row Above"))
        XCTAssertEqual(
            LPlural(3, one: "Insert Row Above", other: "Insert %d Rows Above"),
            String(format: L("Insert %d Rows Above"), 3))
    }
}
