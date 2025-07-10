import Foundation

/// Handles performance benchmarking and statistical analysis for search operations
final class BenchmarkEngine {
    
    init() {
    }
    
    func benchmark(
        searchEngine: SearchEngine,
        file: URL,
        pattern: String,
        iterations: Int = Configuration.defaultBenchmarkIterations,
        warmup: Bool = true
    ) throws -> BenchmarkResult {
        try Configuration.validateIterations(iterations, max: Configuration.maxBenchmarkIterations)
        
        try searchEngine.mapFile(at: file)
        
        if warmup {
            try searchEngine.warmup()
        }
        
        var results: [SearchResult] = []
        results.reserveCapacity(iterations)
        
        for _ in 0..<iterations {
            let result = try searchEngine.search(pattern: pattern)
            results.append(result)
        }
        
        return BenchmarkResult(
            pattern: pattern,
            fileSize: searchEngine.fileSize,
            results: results
        )
    }
    
    private func calculateStandardDeviation(_ values: [TimeInterval]) -> TimeInterval {
        return SharedUtilities.calculateStandardDeviation(values)
    }
    
    func calculateBenchmarkStatistics(_ results: [SearchResult]) -> [String: Any] {
        guard !results.isEmpty else {
            return [:]
        }
        
        let times = results.map(\.executionTime)
        let throughputs = results.map(\.throughputMBps)
        let matchCounts = results.map(\.matchCount)
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        let avgThroughput = throughputs.reduce(0, +) / Double(throughputs.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let minThroughput = throughputs.min() ?? 0
        let maxThroughput = throughputs.max() ?? 0
        let stdDev = calculateStandardDeviation(times)
        
        let uniqueMatchCounts = Set(matchCounts)
        let isConsistent = uniqueMatchCounts.count == 1
        
        let sortedTimes = times.sorted()
        let p50 = percentile(sortedTimes, 50)
        let p95 = percentile(sortedTimes, 95)
        let p99 = percentile(sortedTimes, 99)
        
        let sortedThroughputs = throughputs.sorted(by: >)
        let throughputP50 = percentile(sortedThroughputs, 50)
        let throughputP95 = percentile(sortedThroughputs, 95)
        let throughputP99 = percentile(sortedThroughputs, 99)
        
        return [
            "iterations": results.count,
            "averageTime": avgTime,
            "averageThroughput": avgThroughput,
            "minTime": minTime,
            "maxTime": maxTime,
            "minThroughput": minThroughput,
            "maxThroughput": maxThroughput,
            "standardDeviation": stdDev,
            "coefficientOfVariation": avgTime > 0 ? stdDev / avgTime : 0,
            "isConsistent": isConsistent,
            "uniqueMatchCounts": uniqueMatchCounts,
            "truncatedResults": results.filter(\.truncated).count,
            "percentiles": [
                "time": [
                    "p50": p50,
                    "p95": p95,
                    "p99": p99
                ],
                "throughput": [
                    "p50": throughputP50,
                    "p95": throughputP95,
                    "p99": throughputP99
                ]
            ]
        ]
    }
    
    private func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        return SharedUtilities.percentile(sortedValues, percentile)
    }
    
    func profilePatterns(
        searchEngine: SearchEngine,
        file: URL,
        patterns: [String],
        iterations: Int = Configuration.defaultProfileIterations
    ) throws -> [String: BenchmarkResult] {
        try Configuration.validateIterations(iterations, max: Configuration.maxProfileIterations)
        
        try searchEngine.mapFile(at: file)
        
        var results: [String: BenchmarkResult] = [:]
        
        for pattern in patterns {
            var patternResults: [SearchResult] = []
            patternResults.reserveCapacity(iterations)
            
            for _ in 0..<iterations {
                let result = try searchEngine.search(pattern: pattern)
                patternResults.append(result)
            }
            
            results[pattern] = BenchmarkResult(
                pattern: pattern,
                fileSize: searchEngine.fileSize,
                results: patternResults
            )
        }
        
        return results
    }
    
    func comparePatternPerformance(_ benchmarkResults: [String: BenchmarkResult]) -> [String: Any] {
        let patterns = Array(benchmarkResults.keys)
        let results = Array(benchmarkResults.values)
        
        let avgTimes = results.map(\.averageTime)
        let avgThroughputs = results.map(\.averageThroughput)
        
        let fastestPattern = patterns[avgTimes.firstIndex(of: avgTimes.min() ?? 0) ?? 0]
        let slowestPattern = patterns[avgTimes.firstIndex(of: avgTimes.max() ?? 0) ?? 0]
        let highestThroughputPattern = patterns[avgThroughputs.firstIndex(of: avgThroughputs.max() ?? 0) ?? 0]
        
        return [
            "fastestPattern": fastestPattern,
            "slowestPattern": slowestPattern,
            "highestThroughputPattern": highestThroughputPattern,
            "speedupRatio": (avgTimes.max() ?? 0) / (avgTimes.min() ?? 1),
            "throughputRatio": (avgThroughputs.max() ?? 0) / (avgThroughputs.min() ?? 1),
            "patternAnalysis": Dictionary(uniqueKeysWithValues: patterns.map { pattern in
                let benchmark = benchmarkResults[pattern]!
                return (pattern, [
                    "averageTime": benchmark.averageTime,
                    "averageThroughput": benchmark.averageThroughput,
                    "patternLength": pattern.count,
                    "matchCount": benchmark.results.first?.matchCount ?? 0,
                    "consistency": calculateStandardDeviation(benchmark.results.map(\.executionTime)) / benchmark.averageTime
                ])
            })
        ]
    }
    
    func exportToCSV(_ benchmarkResult: BenchmarkResult) -> String {
        var csv = "iteration,time_seconds,throughput_mbps,match_count,truncated\n"
        
        for (index, result) in benchmarkResult.results.enumerated() {
            csv += "\(index + 1),\(result.executionTime),\(result.throughputMBps),\(result.matchCount),\(result.truncated)\n"
        }
        
        return csv
    }
    
    func exportComparison(_ comparison: [String: Any]) -> String {
        var output = "=== Pattern Performance Comparison ===\n\n"
        
        if let fastest = comparison["fastestPattern"] as? String {
            output += "Fastest Pattern: \(fastest)\n"
        }
        
        if let slowest = comparison["slowestPattern"] as? String {
            output += "Slowest Pattern: \(slowest)\n"
        }
        
        if let speedup = comparison["speedupRatio"] as? Double {
            output += "Speed Difference: \(String(format: "%.2fx", speedup))\n"
        }
        
        if let analysis = comparison["patternAnalysis"] as? [String: Any] {
            output += "\n=== Pattern Details ===\n"
            for (pattern, data) in analysis {
                if let patternData = data as? [String: Any] {
                    output += "\nPattern: '\(pattern)'\n"
                    if let avgTime = patternData["averageTime"] as? Double {
                        output += "  Average Time: \(String(format: "%.4f", avgTime))s\n"
                    }
                    if let avgThroughput = patternData["averageThroughput"] as? Double {
                        output += "  Average Throughput: \(String(format: "%.2f", avgThroughput)) MB/s\n"
                    }
                    if let matchCount = patternData["matchCount"] as? UInt32 {
                        output += "  Match Count: \(matchCount)\n"
                    }
                }
            }
        }
        
        return output
    }
}