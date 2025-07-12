// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUTextSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "SearchEngine",
            targets: ["SearchEngine"]
        ),
        
        .executable(
            name: "search-cli",
            targets: ["SearchCLI"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.2.0"
        ),
    ],
    targets: [
        .target(
            name: "SearchEngine",
            dependencies: [],
            resources: [
                .process("SearchKernel.metal")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        .executableTarget(
            name: "SearchCLI",
            dependencies: [
                "SearchEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"), 
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        .testTarget(
            name: "SearchEngineTests",
            dependencies: ["SearchEngine"],
            path: "Tests/SearchEngineTests"
        ),
    ]
)
