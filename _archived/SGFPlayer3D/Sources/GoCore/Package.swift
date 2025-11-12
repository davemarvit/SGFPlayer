// swift-tools-version: 5.9
// Package manifest for GoCore - Reusable Go game domain models

import PackageDescription

let package = Package(
    name: "GoCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GoCore",
            targets: ["GoCore"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .target(
            name: "GoCore",
            dependencies: [],
            path: "Domain"
        ),
        .testTarget(
            name: "GoCoreTests",
            dependencies: ["GoCore"],
            path: "Tests"
        ),
    ]
)