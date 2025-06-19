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
            from: "1.5.0"
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
                // Future Swift features for better performance and safety
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
                
                // Performance optimizations
                .unsafeFlags([
                    "-O",                           // Optimize for speed
                    "-whole-module-optimization",   // Cross-module optimization
                    "-cross-module-optimization",   // Enhanced cross-module optimization
                    "-enforce-exclusivity=unchecked" // Disable memory exclusivity checking for performance
                ], .when(configuration: .release))
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
                // Future Swift features for better performance and safety
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"), 
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
                
                // Performance optimizations
                .unsafeFlags([
                    "-O",                           // Optimize for speed
                    "-whole-module-optimization",   // Cross-module optimization
                    "-cross-module-optimization",   // Enhanced cross-module optimization
                    "-enforce-exclusivity=unchecked" // Disable memory exclusivity checking for performance
                ], .when(configuration: .release))
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
