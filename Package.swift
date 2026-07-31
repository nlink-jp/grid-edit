// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GridEdit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        // UI-independent CSV engine: parse / serialize / encoding,
        // delimiter, and line-ending detection. No AppKit imports allowed.
        .target(
            name: "GridEditCore",
            path: "Sources/GridEditCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "GridEdit",
            dependencies: ["GridEditCore"],
            path: "Sources/GridEdit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GridEditCoreTests",
            dependencies: ["GridEditCore"],
            path: "Tests/GridEditCoreTests",
            resources: [.copy("testdata")]
        ),
        .testTarget(
            name: "GridEditTests",
            dependencies: ["GridEdit"],
            path: "Tests/GridEditTests"
        ),
    ]
)
