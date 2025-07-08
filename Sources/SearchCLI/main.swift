import Foundation
import ArgumentParser
import SearchEngine

@main
struct SearchCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search-cli",
        abstract: "GPU-accelerated text search tool"
    )
    
    @Argument(help: "File to search")
    var file: String
    
    @Argument(help: "Pattern to search for")
    var pattern: String
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false
    
    @Flag(name: .shortAndLong, help: "Show only match count")
    var quiet = false
    
    func run() throws {
        let engine = try SearchEngine()
        try engine.mapFile(at: URL(fileURLWithPath: file))
        let result = try engine.search(pattern: pattern)
        
        if quiet {
            print(result.matchCount)
        } else if verbose {
            print("Matches: \(result.matchCount)")
            print("Time: \(String(format: "%.4f", result.executionTime))s")
            print("Throughput: \(String(format: "%.2f", result.throughputMBps)) MB/s")
            if result.truncated { 
                print("(truncated)") 
            }
            if !result.positions.isEmpty {
                print("Positions: \(result.positions.prefix(10).map(String.init).joined(separator: ", "))")
            }
        } else {
            let truncated = result.truncated ? " (truncated)" : ""
            print("Found \(result.matchCount) matches\(truncated) in \(String(format: "%.4f", result.executionTime))s")
        }
    }
}