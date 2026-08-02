import XCTest

@testable import GridEditCore

/// Regression cover for the v0.2.3 launch crash: SwiftPM's `Bundle.module`
/// never looked in `Contents/Resources`, so a packaged .app only found its
/// localization bundles on the machine that built it.
final class ResourceBundleTests: XCTestCase {
    private let app = URL(fileURLWithPath: "/Applications/GridEdit.app")
    private let resources = URL(
        fileURLWithPath: "/Applications/GridEdit.app/Contents/Resources")
    private let build = URL(fileURLWithPath: "/tmp/.build/release")

    func testAppResourcesDirectoryIsSearchedFirst() {
        let dirs = ResourceBundleLocator.searchDirectories(
            mainResourceURL: resources, mainBundleURL: app, codeDirectoryURL: build)
        XCTAssertEqual(dirs, [resources, app, build])
    }

    func testMissingDirectoriesAreSkipped() {
        let dirs = ResourceBundleLocator.searchDirectories(
            mainResourceURL: nil, mainBundleURL: app, codeDirectoryURL: nil)
        XCTAssertEqual(dirs, [app])
    }

    func testLocatesBundleInPackagedAppResources() {
        let found = ResourceBundleLocator.locate(
            bundleName: "GridEdit_GridEditCore", in: [resources, app, build]
        ) { $0.path == "/Applications/GridEdit.app/Contents/Resources/GridEdit_GridEditCore.bundle" }
        XCTAssertEqual(
            found?.path,
            "/Applications/GridEdit.app/Contents/Resources/GridEdit_GridEditCore.bundle")
    }

    func testLocatesBundleBesideBareExecutable() {
        let found = ResourceBundleLocator.locate(
            bundleName: "GridEdit_GridEditCore", in: [app, build]
        ) { $0.path == "/tmp/.build/release/GridEdit_GridEditCore.bundle" }
        XCTAssertEqual(found?.path, "/tmp/.build/release/GridEdit_GridEditCore.bundle")
    }

    func testReturnsNilWhenNoDirectoryHoldsTheBundle() {
        let found = ResourceBundleLocator.locate(
            bundleName: "GridEdit_GridEditCore", in: [resources, app, build]) { _ in false }
        XCTAssertNil(found)
    }

    func testResolveFallsBackInsteadOfTrappingWhenBundleIsMissing() {
        let fallback = Bundle(for: ResourceBundleTests.self)
        XCTAssertEqual(
            ResourceBundleLocator.resolve(bundleName: "NoSuchBundle", fallback: fallback),
            fallback)
    }

    /// The real lookup must succeed in whatever layout the test run uses;
    /// otherwise the localized error messages silently fall back to keys.
    func testCoreResourcesBundleResolvesToTheRealLocalizationBundle() {
        XCTAssertNotNil(Bundle.coreResources.url(forResource: "ja", withExtension: "lproj"))
    }

    func testLocalizedErrorUsesTheResourceBundle() {
        let message = CSVEngineError.decodeFailed(encoding: .shiftJIS).errorDescription
        XCTAssertNotNil(message)
        XCTAssertFalse(message!.contains("%@"))
    }
}
