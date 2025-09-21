// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TirePressureManager",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "TirePressureManager",
            targets: ["TirePressureManager"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "TirePressureManager",
            dependencies: [],
            path: "Sources/TirePressureManager"
        ),
        .testTarget(
            name: "TirePressureManagerTests",
            dependencies: ["TirePressureManager"],
            path: "Tests"
        ),
    ]
)