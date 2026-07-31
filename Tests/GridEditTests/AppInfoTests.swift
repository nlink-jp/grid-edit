import XCTest
@testable import GridEdit

final class AppInfoTests: XCTestCase {
    func testNormalizeStripsLeadingV() {
        XCTAssertEqual(AppInfo.normalize("v1.2.3"), "1.2.3")
    }

    func testNormalizeKeepsPlainVersion() {
        XCTAssertEqual(AppInfo.normalize("1.2.3"), "1.2.3")
    }
}
