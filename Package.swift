// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUTextSearch",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .macCatalyst(.v16)
    ],
    products: [
        // MARK: - Library Products
        .library(
            name: "SearchEngine",
            targets: ["SearchEngine"]
        ),
        
        // MARK: - Executable Products
        .executable(
            name: "search-cli",
            targets: ["SearchCLI"]
        ),
    ],
    dependencies: [
        // MARK: - External Dependencies
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.2.0"
        ),
    ],
    targets: [
        // MARK: - Library Targets
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
        
        // MARK: - Executable Targets  
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
        
        // MARK: - Test Targets
        .testTarget(
            name: "SearchEngineTests",
            dependencies: ["SearchEngine"],
            path: "Tests/SearchEngineTests"
        ),
    ]
)
