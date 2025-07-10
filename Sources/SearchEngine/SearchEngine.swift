import Foundation
import Metal

/// Represents the result of a single text search operation
public struct SearchResult {
    private let storage: ResultStorage
    public let executionTime: TimeInterval
    public let throughputMBps: Double
    
    public var matchCount: UInt32 { storage.count }
    public var truncated: Bool { storage.truncated }
    public var positions: [UInt32] { storage.getAllPositions() }
    
    public init(positions: [UInt32], totalCount: UInt32, executionTime: TimeInterval, throughputMBps: Double, truncated: Bool) {
        self.storage = ResultStorage(positions: positions, totalCount: totalCount, truncated: truncated)
        self.executionTime = executionTime
        self.throughputMBps = throughputMBps
    }
    
    public func getPositions(limit: Int = Int.max) -> [UInt32] {
        return storage.getPositions(limit: limit)
    }
    
    public func contains(position: UInt32) -> Bool {
        return storage.contains(position: position)
    }
    
    public func memoryUsage() -> Int {
        return storage.memoryUsage()
    }
    
    /// Get the underlying storage for advanced operations
    internal func getStorage() -> ResultStorage {
        return storage
    }
}

public struct BenchmarkResult {
    public let pattern: String
    public let fileSize: Int
    public let results: [SearchResult]
    public let averageTime: TimeInterval
    public let averageThroughput: Double
    
    public init(pattern: String, fileSize: Int, results: [SearchResult]) {
        self.pattern = pattern
        self.fileSize = fileSize
        self.results = results
        guard !results.isEmpty else {
            self.averageTime = 0
            self.averageThroughput = 0
            return
        }
        self.averageTime = results.map(\.executionTime).reduce(0, +) / Double(results.count)
        self.averageThroughput = results.map(\.throughputMBps).reduce(0, +) / Double(results.count)
    }
}

/// High-performance GPU-accelerated text search engine using Metal compute shaders
public final class SearchEngine {
    
    private let metalResourceManager: MetalResourceManager
    private let fileMapper: FileMapper
    private let patternCache: PatternCache
    private let benchmarkEngine: BenchmarkEngine
    
    private var lastSearchResult: SearchResult?
    
    public var gpuName: String { metalResourceManager.gpuName }
    public var isFileMapped: Bool { fileMapper.isFileMapped }
    public var fileSize: Int { fileMapper.fileSize }
    public var maxPositionsToStore: UInt32 { metalResourceManager.maxPositionsToStore }
    
    public init(maxPositions: UInt32? = nil) throws {
        self.metalResourceManager = try MetalResourceManager(maxPositions: maxPositions)
        self.fileMapper = FileMapper(metalResourceManager: metalResourceManager)
        self.patternCache = PatternCache(metalResourceManager: metalResourceManager)
        self.benchmarkEngine = BenchmarkEngine()
    }
    
    public func mapFile(at url: URL) throws {
        try fileMapper.mapFile(at: url)
    }
    
    public func unmapFile() throws {
        try fileMapper.unmapFile()
    }
    
    public func search(pattern: String) throws -> SearchResult {
        guard isFileMapped else {
            throw ValidationError.noFileMapped
        }
        
        try fileMapper.validatePattern(pattern)
        
        if fileSize == 0 {
            return SearchResult(
                positions: [],
                totalCount: 0,
                executionTime: 0,
                throughputMBps: 0,
                truncated: false
            )
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let fileBuffer = try fileMapper.getFileBuffer()
        let patternBuffer = try patternCache.getCachedPatternBuffer(for: pattern)
        let matchCountBuffer = try metalResourceManager.getPersistentMatchCountBuffer()
        let positionsBuffer = try metalResourceManager.getPersistentPositionsBuffer()
        
        let patternLength = UInt32(pattern.utf8.count)
        let textLength = UInt32(fileSize)
        
        let gpuResult = try metalResourceManager.executeGPUSearch(
            fileBuffer: fileBuffer,
            patternBuffer: patternBuffer,
            patternLength: patternLength,
            textLength: textLength,
            matchCountBuffer: matchCountBuffer,
            positionsBuffer: positionsBuffer
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        let throughputMBps = (fileSize > 0 && executionTime > 0)
            ? Double(fileSize) / (executionTime * 1024 * 1024)
            : 0.0
        
        let result = SearchResult(
            positions: gpuResult.positions,
            totalCount: gpuResult.totalCount,
            executionTime: executionTime,
            throughputMBps: throughputMBps,
            truncated: gpuResult.truncated
        )
        
        lastSearchResult = result
        return result
    }
    
    public func exportPositions(to url: URL) throws {
        guard let searchResult = lastSearchResult else {
            throw ValidationError.noSearchPerformed
        }
        
        guard searchResult.matchCount > 0 else {
            throw ValidationError.noSearchPerformed
        }
        
        let exporter = BinaryResultExporter()
        try exporter.exportPositions(searchResult.getStorage(), to: url)
    }
    
    public func warmup() throws {
        guard isFileMapped else {
            throw ValidationError.noFileMapped
        }
        
        _ = try patternCache.getCachedPatternBuffer(for: "X")
    }
    
    public func warmup(iterations: Int = 3) throws {
        guard isFileMapped else {
            throw ValidationError.noFileMapped
        }
        
        // Warm up pattern cache
        _ = try patternCache.getCachedPatternBuffer(for: "WARMUP")
        
        // Warm up GPU pipeline with multiple iterations
        for i in 0..<iterations {
            let warmupPattern = "W\(i)"
            _ = try search(pattern: warmupPattern)
        }
    }
    
    public func benchmark(file: URL, pattern: String, iterations: Int = Configuration.defaultBenchmarkIterations, warmup: Bool = true) throws -> BenchmarkResult {
        return try benchmarkEngine.benchmark(
            searchEngine: self,
            file: file,
            pattern: pattern,
            iterations: iterations,
            warmup: warmup
        )
    }
    
    public func profilePatterns(file: URL, patterns: [String], iterations: Int = Configuration.defaultProfileIterations) throws -> [String: BenchmarkResult] {
        return try benchmarkEngine.profilePatterns(searchEngine: self, file: file, patterns: patterns, iterations: iterations)
    }
    
    public func getCacheStatistics() -> [String: Any] {
        return patternCache.getCacheStatistics()
    }
    
    public func warmupPatternCache(with patterns: [String]) throws {
        try patternCache.warmupCache(with: patterns)
    }
    
    public func clearPatternCache() {
        patternCache.clearCache()
    }
    
    public func getEngineStatistics() -> [String: Any] {
        return [
            "gpu": [
                "name": gpuName,
                "hasUnifiedMemory": (try? metalResourceManager.getDevice().hasUnifiedMemory) ?? false,
                "maxPositionsToStore": metalResourceManager.maxPositionsToStore
            ],
            "fileMapping": [
                "isFileMapped": isFileMapped,
                "fileSize": fileSize
            ],
            "patternCache": patternCache.getCacheStatistics()
        ]
    }
    
    deinit {
        try? unmapFile()
    }
}

