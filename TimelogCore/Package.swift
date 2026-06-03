// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimelogCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TimelogCore", targets: ["TimelogCore"]),
        .library(name: "TimelogSync", targets: ["TimelogSync"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TimelogCore",
            dependencies: [],
            path: "Sources/TimelogCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "TimelogSync",
            dependencies: ["TimelogCore"],
            path: "Sources/TimelogSync",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TimelogCoreTests",
            dependencies: ["TimelogCore"],
            path: "Tests/TimelogCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
