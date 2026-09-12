// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EuroGasShared",
    platforms: [.iOS(.v18)],
    products: [.library(name: "EuroGasShared", targets: ["EuroGasShared"])],
    targets: [.target(name: "EuroGasShared")]
)
