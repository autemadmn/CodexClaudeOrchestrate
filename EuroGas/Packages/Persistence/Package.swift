// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [
        .package(path: "../CostCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.10.0")
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: ["CostCore", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Persistence",
            resources: [.process("Migrations")]
        ),
        .testTarget(
            name: "PersistenceSwiftTests",
            dependencies: ["Persistence", "CostCore"],
            path: "Tests/PersistenceSwiftTests"
        )
    ]
)
