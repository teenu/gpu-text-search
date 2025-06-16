import Foundation
import Metal
import System

// MARK: - Public Result Types

/// Represents the result of a single text search operation
public struct SearchResult {
    /// Total number of pattern matches found
    public let matchCount: UInt32
    
    /// Array of byte positions where matches were found
    public let positions: [UInt32]
    
    /// Time taken to execute the search operation
    public let executionTime: TimeInterval
    
    /// Search throughput in megabytes per second
    public let throughputMBps: Double
    
    /// Whether results were truncated due to buffer limits
    public let truncated: Bool
    
    public init(matchCount: UInt32, positions: [UInt32], executionTime: TimeInterval, throughputMBps: Double, truncated: Bool) {
        self.matchCount = matchCount
        self.positions = positions
        self.executionTime = executionTime
        self.throughputMBps = throughputMBps
        self.truncated = truncated
    }
}

/// Represents the result of a benchmark test with multiple iterations
public struct BenchmarkResult {
    /// The search pattern used in the benchmark
    public let pattern: String
    
    /// Size of the file that was searched in bytes
    public let fileSize: Int
    
    /// Array of individual search results for each iteration
    public let results: [SearchResult]
    
    /// Average execution time across all iterations
    public let averageTime: TimeInterval
    
    /// Average throughput across all iterations
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

// MARK: - Core Search Engine

/// High-performance GPU-accelerated text search engine using Metal compute shaders
///
/// This class provides zero-copy file mapping and parallel GPU pattern matching
/// for extremely fast text search operations on large files.
public final class SearchEngine {
    
    // MARK: - Constants
    
    /// Maximum number of match positions that can be stored in GPU memory (computed dynamically)
    private let maxPositionsToStore: UInt32
    
    /// Name of the Metal compute kernel function
    private static let kernelFunctionName = "searchOptimizedKernel"
    
    // MARK: - Metal Resources
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var searchPipeline: MTLComputePipelineState?
    private var binaryArchive: MTLBinaryArchive?
    
    // MARK: - Public Properties
    
    /// Name of the GPU device being used
    public var gpuName: String { device.name }
    
    /// Whether a file is currently mapped into memory
    public var isFileMapped: Bool { mappedFileLength >= 0 }
    
    /// Size of the currently mapped file in bytes
    public var fileSize: Int { max(0, mappedFileLength) }
    
    // MARK: - File Mapping State
    
    private var mappedFilePtr: UnsafeMutableRawPointer?
    private var mappedFileLength: Int = -1  // -1 indicates no file mapped
    
    // MARK: - Metal Buffers
    
    private var fileBuffer: MTLBuffer?
    private var patternBuffer: MTLBuffer?
    private var matchCountBuffer: MTLBuffer?
    private var positionsBuffer: MTLBuffer?
    
    // MARK: - Persistent Buffer Pool
    
    private var persistentMatchCountBuffer: MTLBuffer?
    private var persistentPositionsBuffer: MTLBuffer?
    
    // MARK: - Pattern Buffer Cache
    
    private var patternCache: [String: MTLBuffer] = [:]
    private var accessOrder: [String] = []  // Track access order for proper LRU
    private static let maxCacheSize = 32  // Cache up to 32 recent patterns
    
    // MARK: - Initialization
    
    /// Initialize the search engine with Metal GPU support
    /// - Throws: SearchEngineError if Metal is not available or setup fails
    public init() throws {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            throw SearchEngineError.noMetalDevice
        }
        self.device = defaultDevice
        
        guard let queue = device.makeCommandQueue() else {
            throw SearchEngineError.failedToCreateCommandQueue
        }
        self.commandQueue = queue
        
        // Calculate optimal buffer size based on GPU memory
        self.maxPositionsToStore = Self.calculateOptimalBufferSize(for: defaultDevice)
        
        try setupBinaryArchive()
        try setupSearchPipeline()
        try setupPersistentBuffers()
    }
    
    // MARK: - Binary Archive Setup
    
    private func setupBinaryArchive() throws {
        let archiveDescriptor = MTLBinaryArchiveDescriptor()
        
        // Try to load existing archive from app bundle or create new one
        if let archiveURL = getBinaryArchiveURL() {
            archiveDescriptor.url = archiveURL
        }
        
        do {
            binaryArchive = try device.makeBinaryArchive(descriptor: archiveDescriptor)
        } catch {
            // If loading fails, create a new archive
            let newDescriptor = MTLBinaryArchiveDescriptor()
            binaryArchive = try device.makeBinaryArchive(descriptor: newDescriptor)
        }
    }
    
    private func getBinaryArchiveURL() -> URL? {
        // Look for bundled binary archive
        if let bundleURL = Bundle.main.url(forResource: "SearchKernelArchive", withExtension: "metallib") {
            return bundleURL
        }
        
        // Fall back to caches directory for runtime-generated archive
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cacheDir?.appendingPathComponent("SearchKernelArchive.metallib")
    }
    
    private func setupPersistentBuffers() throws {
        let resourceOptions = optimalStorageMode()
        
        // Pre-allocate persistent match count buffer
        var initialCount: UInt32 = 0
        persistentMatchCountBuffer = device.makeBuffer(
            bytes: &initialCount,
            length: MemoryLayout<UInt32>.size,
            options: resourceOptions
        )
        persistentMatchCountBuffer?.label = "Persistent Match Count Buffer"
        
        // Pre-allocate persistent positions buffer at maximum size
        let positionsBufferSize = Int(maxPositionsToStore) * MemoryLayout<UInt32>.size
        persistentPositionsBuffer = device.makeBuffer(
            length: positionsBufferSize,
            options: resourceOptions
        )
        persistentPositionsBuffer?.label = "Persistent Positions Buffer"
        
        guard persistentMatchCountBuffer != nil && persistentPositionsBuffer != nil else {
            throw SearchEngineError.failedToCreateBuffer("persistent buffers")
        }
    }
    
    // MARK: - Helper Functions
    
    private func optimalStorageMode() -> MTLResourceOptions {
        // Optimize storage mode for Apple Silicon unified memory architecture
        return device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
    }
    
    private static func calculateOptimalBufferSize(for device: MTLDevice) -> UInt32 {
        // Get available GPU memory (returns 0 on unified memory systems like Apple Silicon)
        let recommendedWorkingSetSize = device.recommendedMaxWorkingSetSize
        
        if device.hasUnifiedMemory {
            // Apple Silicon: Use system memory info and allocate 10-20% for result buffer
            let systemMemory = ProcessInfo.processInfo.physicalMemory
            let maxBufferMemory = systemMemory / 10  // Use 10% of system memory
            let positionsPerUInt32 = maxBufferMemory / UInt64(MemoryLayout<UInt32>.size)
            
            // Clamp between reasonable bounds: 1M - 50M positions
            return UInt32(min(max(positionsPerUInt32, 1_000_000), 50_000_000))
        } else {
            // Discrete GPU: Use recommended working set size
            if recommendedWorkingSetSize > 0 {
                let maxBufferMemory = recommendedWorkingSetSize / 4  // Use 25% for result buffer
                let positions = maxBufferMemory / UInt64(MemoryLayout<UInt32>.size)
                
                // Clamp between reasonable bounds: 1M - 100M positions
                return UInt32(min(max(positions, 1_000_000), 100_000_000))
            } else {
                // Fallback to conservative default
                return 10_000_000
            }
        }
    }
    
    private func getCachedPatternBuffer(for pattern: String) throws -> MTLBuffer {
        // Check cache first
        if let cachedBuffer = patternCache[pattern] {
            // Move to end of access order (most recently used)
            if let index = accessOrder.firstIndex(of: pattern) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(pattern)
            return cachedBuffer
        }
        
        // Create new buffer (pattern already validated at entry point)
        let patternData = pattern.data(using: .utf8)!
        
        let buffer = device.makeBuffer(
            bytes: [UInt8](patternData),
            length: patternData.count,
            options: optimalStorageMode()
        )
        
        guard let buffer = buffer else {
            throw SearchEngineError.failedToCreateBuffer("pattern")
        }
        
        buffer.label = "Pattern Buffer: \(pattern)"
        
        // Add to cache, evicting LRU if needed
        if patternCache.count >= Self.maxCacheSize {
            // Remove least recently used entry (first in accessOrder)
            let lruKey = accessOrder.removeFirst()
            patternCache.removeValue(forKey: lruKey)
        }
        
        patternCache[pattern] = buffer
        accessOrder.append(pattern)
        return buffer
    }
    
    // MARK: - Metal Pipeline Setup
    
    private func setupSearchPipeline() throws {
        // Try to load precompiled library first, then compile from source if needed
        let library: MTLLibrary
        if let bundleLibrary = device.makeDefaultLibrary() {
            library = bundleLibrary
        } else {
            // Fallback to runtime compilation for development/testing
            library = try compileKernelFromSource()
        }
        
        guard let kernelFunction = library.makeFunction(name: Self.kernelFunctionName) else {
            throw SearchEngineError.kernelFunctionNotFound(Self.kernelFunctionName)
        }
        
        do {
            // Create pipeline descriptor with binary archive for caching
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.computeFunction = kernelFunction
            pipelineDescriptor.label = "Search Kernel Pipeline"
            
            // Use binary archive for PSO caching
            if let archive = binaryArchive {
                pipelineDescriptor.binaryArchives = [archive]
            }
            
            searchPipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
            // Binary archive will automatically cache the pipeline state
            // No explicit addition needed - it's handled during pipeline creation
        } catch {
            throw SearchEngineError.failedToCreatePipeline(error)
        }
    }
    
    private func compileKernelFromSource() throws -> MTLLibrary {
        // Load Metal source from bundle and compile at runtime
        let bundle = Bundle.module
        guard let metalURL = bundle.url(forResource: "SearchKernel", withExtension: "metal") else {
            throw SearchEngineError.failedToCreateLibrary
        }
        
        let kernelSource = try String(contentsOf: metalURL)
        
        do {
            return try device.makeLibrary(source: kernelSource, options: nil)
        } catch {
            throw SearchEngineError.failedToCreateLibrary
        }
    }
    
    // MARK: - File Management
    
    /// Map a file into memory for searching
    /// - Parameter url: URL of the file to map
    /// - Throws: SearchEngineError if mapping fails
    public func mapFile(at url: URL) throws {
        // Unmap any existing file first
        try unmapFile()
        
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw SearchEngineError.failedToOpenFile(url.path, String(cString: strerror(errno)))
        }
        defer { close(fd) }
        
        var stats = stat()
        guard fstat(fd, &stats) == 0 else {
            throw SearchEngineError.failedToGetFileStats(String(cString: strerror(errno)))
        }
        
        let fileSize = Int(stats.st_size)
        guard fileSize >= 0 else {
            throw SearchEngineError.invalidFileSize(fileSize)
        }
        
        // Handle empty files
        if fileSize == 0 {
            mappedFilePtr = nil
            mappedFileLength = 0
            fileBuffer = nil
            return
        }
        
        // Memory map the file
        let ptr = mmap(nil, fileSize, PROT_READ, MAP_PRIVATE, fd, 0)
        guard ptr != MAP_FAILED else {
            throw SearchEngineError.memoryMappingFailed(String(cString: strerror(errno)))
        }
        
        mappedFilePtr = ptr
        mappedFileLength = fileSize
        fileBuffer = nil // Will be created on demand
    }
    
    /// Unmap the currently mapped file
    /// - Throws: SearchEngineError if unmapping fails
    public func unmapFile() throws {
        defer {
            mappedFilePtr = nil
            mappedFileLength = -1
            clearMetalBuffers()
        }
        
        guard let ptr = mappedFilePtr, mappedFileLength > 0 else {
            return // Nothing to unmap
        }
        
        if munmap(ptr, mappedFileLength) != 0 {
            throw SearchEngineError.unmappingFailed(String(cString: strerror(errno)))
        }
    }
    
    private func clearMetalBuffers() {
        fileBuffer = nil
        patternBuffer = nil
        // Don't clear persistent buffers - they're reused
        matchCountBuffer = nil
        positionsBuffer = nil
    }
    
    // MARK: - Metal Resource Preparation
    
    private func prepareMetalResources(for pattern: String) throws {
        guard isFileMapped else {
            throw SearchEngineError.noFileMapped
        }
        
        // Handle empty files
        guard mappedFileLength > 0 else {
            clearMetalBuffers()
            return
        }
        
        guard let mappedPtr = mappedFilePtr else {
            throw SearchEngineError.internalError("File mapped but pointer is nil")
        }
        
        // Create file buffer (zero-copy) if needed
        if fileBuffer == nil || fileBuffer?.length != mappedFileLength {
            fileBuffer = device.makeBuffer(
                bytesNoCopy: mappedPtr,
                length: mappedFileLength,
                options: optimalStorageMode(),
                deallocator: nil
            )
            guard fileBuffer != nil else {
                throw SearchEngineError.failedToCreateBuffer("file content")
            }
            fileBuffer?.label = "File Content Buffer"
        }
        
        // Use cached pattern buffer
        patternBuffer = try getCachedPatternBuffer(for: pattern)
        
        // Use persistent buffers (zero allocation overhead)
        matchCountBuffer = persistentMatchCountBuffer
        positionsBuffer = persistentPositionsBuffer
        
        guard let matchCountBuffer = matchCountBuffer else {
            throw SearchEngineError.failedToCreateBuffer("persistent buffers not available")
        }
        
        // Reset match count buffer for new search
        let countPtr = matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPtr.pointee = 0
    }
    
    // MARK: - Search Execution
    
    /// Perform a text search for the specified pattern
    /// - Parameter pattern: The text pattern to search for
    /// - Returns: SearchResult containing match information
    /// - Throws: SearchEngineError if search fails
    public func search(pattern: String) throws -> SearchResult {
        guard isFileMapped else {
            throw SearchEngineError.noFileMapped
        }
        
        // Validate pattern once at entry point
        guard !pattern.isEmpty else {
            throw SearchEngineError.invalidPattern("Pattern cannot be empty")
        }
        
        guard pattern.utf8.count <= mappedFileLength else {
            throw SearchEngineError.invalidPattern("Pattern is longer than the mapped file")
        }
        
        guard pattern.data(using: .utf8) != nil else {
            throw SearchEngineError.invalidPattern("Pattern failed to encode as UTF-8")
        }
        
        // Handle empty files
        if mappedFileLength == 0 {
            return SearchResult(
                matchCount: 0,
                positions: [],
                executionTime: 0,
                throughputMBps: 0,
                truncated: false
            )
        }
        
        guard let pipeline = searchPipeline else {
            throw SearchEngineError.pipelineNotAvailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Prepare Metal resources (includes pattern validation)
        try prepareMetalResources(for: pattern)
        
        let patternLength = UInt32(pattern.utf8.count)
        
        // Execute GPU search
        let gpuResult = try executeGPUSearch(
            pipeline: pipeline,
            patternLength: patternLength
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Calculate throughput
        let throughputMBps = (mappedFileLength > 0 && executionTime > 0)
            ? Double(mappedFileLength) / (executionTime * 1024 * 1024)
            : 0.0
        
        return SearchResult(
            matchCount: gpuResult.totalCount,
            positions: gpuResult.positions,
            executionTime: executionTime,
            throughputMBps: throughputMBps,
            truncated: gpuResult.truncated
        )
    }
    
    private func executeGPUSearch(
        pipeline: MTLComputePipelineState,
        patternLength: UInt32
    ) throws -> (totalCount: UInt32, positions: [UInt32], truncated: Bool) {
        
        guard let fileBuffer = self.fileBuffer,
              let patternBuffer = self.patternBuffer,
              let matchCountBuffer = self.matchCountBuffer,
              let positionsBuffer = self.positionsBuffer else {
            throw SearchEngineError.internalError("Required Metal buffers missing")
        }
        
        // Create command buffer and encoder
        guard let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw SearchEngineError.failedToCreateCommandBuffer
        }
        
        // Configure compute encoder
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(fileBuffer, offset: 0, index: 0)
        encoder.setBuffer(patternBuffer, offset: 0, index: 1)
        
        var pLen = patternLength
        encoder.setBytes(&pLen, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBuffer(matchCountBuffer, offset: 0, index: 3)
        
        var textLen = UInt32(mappedFileLength)
        encoder.setBytes(&textLen, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBuffer(positionsBuffer, offset: 0, index: 5)
        
        var maxPos = maxPositionsToStore
        encoder.setBytes(&maxPos, length: MemoryLayout<UInt32>.size, index: 6)
        
        // Calculate optimal dispatch configuration
        let dispatchConfig = calculateDispatchConfiguration(
            pipeline: pipeline,
            totalPositions: mappedFileLength - Int(patternLength) + 1
        )
        
        encoder.dispatchThreads(dispatchConfig.threadsPerGrid, 
                               threadsPerThreadgroup: dispatchConfig.threadsPerThreadgroup)
        encoder.endEncoding()
        
        // Execute synchronously
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        guard cmdBuffer.status == .completed else {
            let errorDesc = cmdBuffer.error?.localizedDescription ?? "Unknown GPU error"
            throw SearchEngineError.gpuExecutionFailed(errorDesc)
        }
        
        // Extract results
        return extractResults(from: matchCountBuffer, positionsBuffer: positionsBuffer)
    }
    
    private func calculateDispatchConfiguration(
        pipeline: MTLComputePipelineState,
        totalPositions: Int
    ) -> (threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) {
        
        guard totalPositions > 0 else {
            return (MTLSize(width: 1, height: 1, depth: 1), MTLSize(width: 1, height: 1, depth: 1))
        }
        
        let threadsPerGrid = MTLSize(width: totalPositions, height: 1, depth: 1)
        
        // Calculate optimal threadgroup size
        let threadWidth = pipeline.threadExecutionWidth
        let maxGroup = pipeline.maxTotalThreadsPerThreadgroup
        let desiredGroupWidth = (threadWidth > 0 && maxGroup >= threadWidth) 
            ? (maxGroup / threadWidth) * threadWidth 
            : 64
        let groupWidth = min(maxGroup, desiredGroupWidth, totalPositions)
        
        let threadsPerThreadgroup = MTLSize(width: max(1, groupWidth), height: 1, depth: 1)
        
        return (threadsPerGrid, threadsPerThreadgroup)
    }
    
    private func extractResults(
        from matchCountBuffer: MTLBuffer,
        positionsBuffer: MTLBuffer
    ) -> (totalCount: UInt32, positions: [UInt32], truncated: Bool) {
        
        let countPtr = matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        let totalMatchCount = countPtr.pointee
        let storedPositionCount = Int(min(totalMatchCount, maxPositionsToStore))
        
        var positions: [UInt32] = []
        if storedPositionCount > 0 {
            let positionsPtr = positionsBuffer.contents().bindMemory(to: UInt32.self, capacity: storedPositionCount)
            positions = Array(UnsafeBufferPointer(start: positionsPtr, count: storedPositionCount))
        }
        
        let truncated = totalMatchCount > maxPositionsToStore
        
        return (totalMatchCount, positions, truncated)
    }
    
    // MARK: - Binary Export
    
    /// Export match positions as binary data
    /// - Parameter url: Destination URL for the binary file
    /// - Throws: SearchEngineError if export fails
    public func exportPositionsBinary(to url: URL) throws {
        guard let positionsBuffer = self.positionsBuffer,
              let matchCountBuffer = self.matchCountBuffer else {
            throw SearchEngineError.internalError("Result buffers not available for export")
        }
        
        guard positionsBuffer.storageMode == .shared else {
            throw SearchEngineError.internalError("Positions buffer is not CPU accessible")
        }
        
        let countPtr = matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        let totalMatchCount = countPtr.pointee
        let positionsToSaveCount = Int(min(totalMatchCount, maxPositionsToStore))
        
        guard positionsToSaveCount > 0 else {
            throw SearchEngineError.internalError("No match positions available to save")
        }
        
        let bytesToWrite = positionsToSaveCount * MemoryLayout<UInt32>.size
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        // Create new file
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
            throw SearchEngineError.internalError("Failed to create export file at \(url.path)")
        }
        
        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }
        
        // Direct binary write from Metal buffer (zero-copy)
        let positionsDataPtr = positionsBuffer.contents()
        let dataToWrite = Data(
            bytesNoCopy: positionsDataPtr,
            count: bytesToWrite,
            deallocator: .none
        )
        
        try fileHandle.write(contentsOf: dataToWrite)
    }
    
    // MARK: - GPU Warmup
    
    /// Warm up the GPU to achieve peak performance on subsequent searches
    /// - Throws: SearchEngineError if warmup fails
    public func warmup() throws {
        guard isFileMapped else {
            throw SearchEngineError.noFileMapped
        }
        
        // With binary archives and persistent buffers, warmup is just buffer preparation
        // The GPU pipeline is already optimized, so minimal work needed
        try prepareMetalResources(for: "X")
    }
    
    // MARK: - Benchmarking
    
    /// Run a benchmark test with multiple iterations
    /// - Parameters:
    ///   - file: URL of the file to benchmark
    ///   - pattern: Search pattern to use
    ///   - iterations: Number of iterations to run (default: 100)
    ///   - warmup: Whether to perform GPU warmup before benchmarking (default: true)
    /// - Returns: BenchmarkResult containing performance statistics
    /// - Throws: SearchEngineError if benchmark fails
    public func benchmark(file: URL, pattern: String, iterations: Int = 100, warmup: Bool = true) throws -> BenchmarkResult {
        try mapFile(at: file)
        
        // Perform GPU warmup for consistent peak performance
        if warmup {
            try self.warmup()
        }
        
        var results: [SearchResult] = []
        results.reserveCapacity(iterations)
        
        for _ in 0..<iterations {
            let result = try search(pattern: pattern)
            results.append(result)
        }
        
        return BenchmarkResult(pattern: pattern, fileSize: mappedFileLength, results: results)
    }
    
    // MARK: - Cleanup
    
    deinit {
        try? unmapFile()
    }
}

// MARK: - Error Types

/// Errors that can occur during search engine operations
public enum SearchEngineError: Error, LocalizedError {
    case noMetalDevice
    case failedToCreateCommandQueue
    case failedToCreateLibrary
    case kernelFunctionNotFound(String)
    case failedToCreatePipeline(Error)
    case failedToOpenFile(String, String)
    case failedToGetFileStats(String)
    case invalidFileSize(Int)
    case memoryMappingFailed(String)
    case unmappingFailed(String)
    case noFileMapped
    case invalidPattern(String)
    case failedToCreateBuffer(String)
    case pipelineNotAvailable
    case failedToCreateCommandBuffer
    case gpuExecutionFailed(String)
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .noMetalDevice:
            return "No suitable Metal GPU found on this system"
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue"
        case .failedToCreateLibrary:
            return "Failed to create Metal library"
        case .kernelFunctionNotFound(let name):
            return "Failed to find Metal kernel function '\(name)'"
        case .failedToCreatePipeline(let error):
            return "Failed to create Metal compute pipeline: \(error.localizedDescription)"
        case .failedToOpenFile(let path, let error):
            return "Failed to open file '\(path)': \(error)"
        case .failedToGetFileStats(let error):
            return "Failed to get file statistics: \(error)"
        case .invalidFileSize(let size):
            return "Invalid file size: \(size)"
        case .memoryMappingFailed(let error):
            return "Memory mapping failed: \(error)"
        case .unmappingFailed(let error):
            return "Failed to unmap file: \(error)"
        case .noFileMapped:
            return "No file is currently mapped"
        case .invalidPattern(let message):
            return "Invalid search pattern: \(message)"
        case .failedToCreateBuffer(let type):
            return "Failed to create Metal buffer for \(type)"
        case .pipelineNotAvailable:
            return "Metal pipeline not available"
        case .failedToCreateCommandBuffer:
            return "Failed to create Metal command buffer"
        case .gpuExecutionFailed(let error):
            return "GPU execution failed: \(error)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}