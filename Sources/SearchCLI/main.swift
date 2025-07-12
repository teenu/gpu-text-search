import Foundation
import ArgumentParser
import SearchEngine

func formatFileSize(_ bytes: Int) -> String {
    return SharedUtilities.formatFileSize(bytes)
}

func formatNumber(_ number: UInt32) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

func validateFileExists(_ path: String) throws {
    do {
        try SharedUtilities.validateFileExists(path)
    } catch {
        throw ValidationError("File validation failed: \(error.localizedDescription)")
    }
}

func validateIterations(_ iterations: Int, max: Int = Configuration.maxBenchmarkIterations) throws {
    do {
        try Configuration.validateIterations(iterations, max: max)
    } catch {
        throw ValidationError(error.localizedDescription)
    }
}

func initializeEngine(verbose: Bool, quiet: Bool = false, maxPositions: UInt32? = nil) throws -> SearchEngine {
    if verbose && !quiet {
        print("Initializing Metal GPU search engine...")
    }
    return try SearchEngine(maxPositions: maxPositions)
}

func mapFile(engine: SearchEngine, path: String, verbose: Bool, quiet: Bool = false) throws {
    if verbose && !quiet {
        print("Mapping file: \(path)")
    }
    try engine.mapFile(at: URL(fileURLWithPath: path))
    
    if verbose && !quiet {
        print("File size: \(formatFileSize(engine.fileSize))")
        print("GPU: \(engine.gpuName)")
    }
}

func calculateStandardDeviation(_ values: [TimeInterval]) -> TimeInterval {
    return SharedUtilities.calculateStandardDeviation(values)
}

@main
struct SearchCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search-cli",
        abstract: "High-performance GPU-accelerated text search tool",
        discussion: """
        Examples:
          search-cli search file.txt "pattern"
          search-cli benchmark file.txt "pattern" --iterations 50
          search-cli profile file.txt --verbose
        """,
        subcommands: [Search.self, Benchmark.self, Profile.self],
        defaultSubcommand: Search.self
    )
}

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Search for a pattern in a file"
    )
    
    @Argument(help: "File to search in")
    var file: String
    
    @Argument(help: "Pattern to search for")
    var pattern: String
    
    @Flag(name: .shortAndLong, help: "Show verbose output with detailed information")
    var verbose = false
    
    @Flag(name: .shortAndLong, help: "Show only match count (script-friendly)")
    var quiet = false
    
    @Option(name: .shortAndLong, help: "Maximum positions to display (default: \(Configuration.defaultPositionDisplayLimit))")
    var limit: Int = Configuration.defaultPositionDisplayLimit
    
    @Option(help: "Maximum positions to store in memory (default: auto-detect based on available memory)")
    var maxPositions: UInt32?
    
    @Option(help: "Export positions to binary file at specified path")
    var exportBinary: String?
    
    @Flag(help: "Warm up GPU before search for peak performance")
    var warmup = false
    
    @Option(help: "Number of warmup iterations for optimal cold start performance (default: 3)")
    var warmupIterations: Int = 3
    
    @Flag(help: "Measure and report pure initialization time separately from execution")
    var measureInitTime = false
    
    func validate() throws {
        guard limit > 0 else {
            throw ValidationError("Limit must be greater than 0")
        }
        guard warmupIterations > 0 else {
            throw ValidationError("Warmup iterations must be greater than 0")
        }
    }
    
    func run() throws {
        try validateFileExists(file)
        
        let initStartTime = CFAbsoluteTimeGetCurrent()
        let engine = try initializeEngine(verbose: verbose, quiet: quiet, maxPositions: maxPositions)
        let initEndTime = CFAbsoluteTimeGetCurrent()
        let initTime = initEndTime - initStartTime
        
        if measureInitTime || (verbose && !quiet) {
            print("Pure initialization time: \(String(format: "%.4f", initTime)) seconds")
        }
        
        if verbose && !quiet {
            print("Max positions to store: \(formatNumber(engine.maxPositionsToStore))")
            if let requestedPositions = maxPositions, requestedPositions != engine.maxPositionsToStore {
                print("⚠️  Requested \(formatNumber(requestedPositions)) positions, using \(formatNumber(engine.maxPositionsToStore)) (system limit)")
            }
            print("Searching for pattern: '\(pattern)'")
        }
        
        try mapFile(engine: engine, path: file, verbose: verbose, quiet: quiet)
        
        if warmup {
            if verbose && !quiet {
                print("Warming up GPU for peak performance (\(warmupIterations) iterations)...")
            }
            try engine.warmup(iterations: warmupIterations)
        }
        
        let result = try engine.search(pattern: pattern)
        
        if quiet {
            print(result.matchCount)
        } else {
            printSearchResult(result, limit: limit, verbose: verbose)
        }
        
        if let exportPath = exportBinary {
            try engine.exportPositions(to: URL(fileURLWithPath: exportPath))
            if verbose && !quiet {
                print("Exported binary positions to \(exportPath)")
            }
        }
    }
    
    private func printSearchResult(_ result: SearchResult, limit: Int, verbose: Bool) {
        if verbose {
            print("\n--- Search Results ---")
            print("Matches found: \(result.matchCount)")
            print("Execution time: \(String(format: "%.4f", result.executionTime)) seconds")
            print("Throughput: \(String(format: "%.2f", result.throughputMBps)) MB/s")
            if result.truncated {
                print("⚠️  Results truncated (buffer limit reached)")
            }
        } else {
            let truncatedIndicator = result.truncated ? " (truncated)" : ""
            print("Found \(result.matchCount) matches\(truncatedIndicator) in \(String(format: "%.4f", result.executionTime))s (\(String(format: "%.2f", result.throughputMBps)) MB/s)")
        }
        
        let positions = result.getPositions(limit: limit)
        if !positions.isEmpty && !quiet {
            let displayCount = positions.count
            if verbose {
                print("\nFirst \(displayCount) positions:")
            }
            let positionStrings = positions.map(String.init).joined(separator: ", ")
            let ellipsis = result.matchCount > displayCount ? "..." : ""
            print("[\(positionStrings)\(ellipsis)]")
        }
    }
    
}

struct Benchmark: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Benchmark search performance with statistical analysis"
    )
    
    @Argument(help: "File to benchmark")
    var file: String
    
    @Argument(help: "Pattern to search for")
    var pattern: String
    
    @Option(name: .shortAndLong, help: "Number of iterations to run (default: \(Configuration.defaultBenchmarkIterations))")
    var iterations: Int = Configuration.defaultBenchmarkIterations
    
    @Flag(name: .shortAndLong, help: "Show verbose output with detailed statistics")
    var verbose = false
    
    @Flag(help: "Output results in CSV format for analysis")
    var csv = false
    
    @Flag(help: "Skip GPU warmup to test cold performance (warmup enabled by default)")
    var noWarmup = false
    
    func validate() throws {
        try validateIterations(iterations)
    }
    
    func run() throws {
        try validateFileExists(file)
        
        let useWarmup = !noWarmup
        
        if verbose && !csv {
            print("Initializing benchmark...")
            print("File: \(file)")
            print("Pattern: '\(pattern)'")
            print("Iterations: \(iterations)")
            print("GPU Warmup: \(useWarmup ? "enabled" : "disabled")")
            print("Running benchmark...")
        }
        
        let engine = try SearchEngine()
        let benchmark = try engine.benchmark(file: URL(fileURLWithPath: file), pattern: pattern, iterations: iterations, warmup: useWarmup)
        
        if csv {
            printCSVResults(benchmark)
        } else {
            printBenchmarkResults(benchmark, verbose: verbose)
        }
    }
    
    private func printBenchmarkResults(_ benchmark: BenchmarkResult, verbose: Bool) {
        print("\n--- Benchmark Results ---")
        print("Pattern: '\(benchmark.pattern)'")
        print("File size: \(formatFileSize(benchmark.fileSize))")
        print("Iterations: \(benchmark.results.count)")
        print("Average time: \(String(format: "%.4f", benchmark.averageTime)) seconds")
        print("Average throughput: \(String(format: "%.2f", benchmark.averageThroughput)) MB/s")
        
        let times = benchmark.results.map(\.executionTime)
        let throughputs = benchmark.results.map(\.throughputMBps)
        
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let minThroughput = throughputs.min() ?? 0
        let maxThroughput = throughputs.max() ?? 0
        let stdDev = calculateStandardDeviation(times)
        
        print("Min time: \(String(format: "%.4f", minTime)) seconds")
        print("Max time: \(String(format: "%.4f", maxTime)) seconds")
        print("Peak throughput: \(String(format: "%.2f", maxThroughput)) MB/s")
        print("Min throughput: \(String(format: "%.2f", minThroughput)) MB/s")
        print("Std deviation: \(String(format: "%.4f", stdDev)) seconds")
        
        let matchCounts = Set(benchmark.results.map(\.matchCount))
        if matchCounts.count == 1 {
            print("✅ Results consistent: All iterations found \(matchCounts.first!) matches")
        } else {
            print("⚠️  Results inconsistent: Found \(matchCounts.count) different match counts")
        }
        
        if verbose {
            let truncatedResults = benchmark.results.filter(\.truncated)
            if !truncatedResults.isEmpty {
                print("⚠️  \(truncatedResults.count) iterations were truncated")
            }
        }
    }
    
    private func printCSVResults(_ benchmark: BenchmarkResult) {
        print("iteration,time_seconds,throughput_mbps,match_count,truncated")
        for (index, result) in benchmark.results.enumerated() {
            print("\(index + 1),\(result.executionTime),\(result.throughputMBps),\(result.matchCount),\(result.truncated)")
        }
    }
    
}

struct Profile: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Profile search performance across different patterns"
    )
    
    @Argument(help: "File to profile")
    var file: String
    
    @Option(name: .shortAndLong, help: "Number of iterations per pattern (default: \(Configuration.defaultProfileIterations))")
    var iterations: Int = Configuration.defaultProfileIterations
    
    @Flag(name: .shortAndLong, help: "Show verbose output with detailed information")
    var verbose = false
    
    @Option(help: "Custom patterns to test (comma-separated)")
    var patterns: String?
    
    func validate() throws {
        try validateIterations(iterations, max: Configuration.maxProfileIterations)
    }
    
    func run() throws {
        try validateFileExists(file)
        
        let testPatterns: [String]
        if let customPatterns = patterns {
            testPatterns = customPatterns.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            testPatterns = [
                "a",                // Single character
                "the",              // Common 3-char word  
                "function",         // Medium word
                "optimization",     // Longer word
                "searchOptimized",  // Even longer
                "xyz123notfound"    // Likely not found
            ]
        }
        
        if verbose {
            print("Profiling file: \(file)")
            print("Test patterns: \(testPatterns)")
            print("Iterations per pattern: \(iterations)")
            print()
        }
        
        let engine = try SearchEngine()
        try engine.mapFile(at: URL(fileURLWithPath: file))
        
        print("Pattern\t\tLength\tMatches\tAvg Time(s)\tThroughput(MB/s)\tMin(s)\tMax(s)")
        print("-------\t\t------\t-------\t-----------\t---------------\t------\t------")
        
        for pattern in testPatterns {
            var results: [SearchResult] = []
            
            for _ in 0..<iterations {
                let result = try engine.search(pattern: pattern)
                results.append(result)
            }
            
            let times = results.map(\.executionTime)
            let throughputs = results.map(\.throughputMBps)
            
            let avgTime = times.reduce(0, +) / Double(times.count)
            let avgThroughput = throughputs.reduce(0, +) / Double(throughputs.count)
            let minTime = times.min() ?? 0
            let maxTime = times.max() ?? 0
            let matchCount = results.first?.matchCount ?? 0
            
            let patternDisplay = pattern.count > 12 ? String(pattern.prefix(9)) + "..." : pattern
            let truncatedIndicator = results.contains(where: \.truncated) ? "*" : ""
            
            print("\(patternDisplay)\t\t\(pattern.count)\t\(matchCount)\(truncatedIndicator)\t\(String(format: "%.4f", avgTime))\t\t\(String(format: "%.2f", avgThroughput))\t\t\(String(format: "%.4f", minTime))\t\(String(format: "%.4f", maxTime))")
        }
        
        if verbose {
            print("\n* Indicates truncated results (>10M matches)")
            print("Performance varies with pattern complexity and match density")
        }
    }
}

struct ValidationError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        return message
    }
}
