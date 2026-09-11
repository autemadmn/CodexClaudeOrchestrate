// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "CostCore",
    products: [
        .library(name: "CostCore", targets: ["CostCore"])
    ],
    dependencies: [],
    targets: [
        .target(name: "CostCore", path: "Sources/CostCore"),
        .testTarget(name: "CostCoreTests", dependencies: ["CostCore"], path: "Tests/CostCoreTests")
    ]
)
