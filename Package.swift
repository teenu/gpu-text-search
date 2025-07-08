// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUTextSearch",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SearchEngine", targets: ["SearchEngine"]),
        .executable(name: "search-cli", targets: ["SearchCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "SearchEngine", resources: [.process("SearchKernel.metal")]),
        .executableTarget(name: "SearchCLI", dependencies: ["SearchEngine", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(name: "SearchEngineTests", dependencies: ["SearchEngine"])
    ]
)