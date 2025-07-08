import Foundation
import Metal
import System

public struct SearchResult {
    public let matchCount: UInt32
    public let positions: [UInt32]
    public let executionTime: TimeInterval
    public let throughputMBps: Double
    public let truncated: Bool
    
    public init(matchCount: UInt32, positions: [UInt32], executionTime: TimeInterval, throughputMBps: Double, truncated: Bool) {
        self.matchCount = matchCount
        self.positions = positions
        self.executionTime = executionTime
        self.throughputMBps = throughputMBps
        self.truncated = truncated
    }
}

public final class SearchEngine {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let searchPipeline: MTLComputePipelineState
    private let storageMode: MTLResourceOptions
    private let maxPositionsToStore: UInt32 = 10_000_000
    
    private var mappedFilePtr: UnsafeMutableRawPointer?
    private var mappedFileLength: Int = -1
    
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SearchEngineError.noMetalDevice
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            throw SearchEngineError.failedToCreateCommandQueue
        }
        self.commandQueue = queue
        
        self.storageMode = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        
        let library: MTLLibrary
        if let bundleLibrary = device.makeDefaultLibrary() {
            library = bundleLibrary
        } else {
            guard let metalURL = Bundle.module.url(forResource: "SearchKernel", withExtension: "metal") else {
                throw SearchEngineError.failedToCreateLibrary
            }
            let source = try String(contentsOf: metalURL)
            library = try device.makeLibrary(source: source, options: nil)
        }
        
        guard let kernelFunction = library.makeFunction(name: "searchOptimizedKernel") else {
            throw SearchEngineError.failedToCreateLibrary
        }
        
        do {
            self.searchPipeline = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            throw SearchEngineError.failedToCreatePipeline(error)
        }
    }
    
    public func mapFile(at url: URL) throws {
        try unmapFile()
        
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw SearchEngineError.failedToOpenFile(url.path)
        }
        defer { close(fd) }
        
        var stats = stat()
        guard fstat(fd, &stats) == 0 else {
            throw SearchEngineError.failedToGetFileStats
        }
        
        let fileSize = Int(stats.st_size)
        if fileSize == 0 {
            mappedFilePtr = nil
            mappedFileLength = 0
            return
        }
        
        let ptr = mmap(nil, fileSize, PROT_READ, MAP_PRIVATE, fd, 0)
        guard ptr != MAP_FAILED else {
            throw SearchEngineError.memoryMappingFailed
        }
        
        mappedFilePtr = ptr
        mappedFileLength = fileSize
    }
    
    public func unmapFile() throws {
        defer {
            mappedFilePtr = nil
            mappedFileLength = -1
        }
        
        guard let ptr = mappedFilePtr, mappedFileLength > 0 else {
            return
        }
        
        if munmap(ptr, mappedFileLength) != 0 {
            throw SearchEngineError.unmappingFailed
        }
    }
    
    public func search(pattern: String) throws -> SearchResult {
        guard mappedFileLength >= 0 else {
            throw SearchEngineError.noFileMapped
        }
        
        guard !pattern.isEmpty else {
            throw SearchEngineError.invalidPattern
        }
        
        if mappedFileLength == 0 {
            return SearchResult(matchCount: 0, positions: [], executionTime: 0, throughputMBps: 0, truncated: false)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let mappedPtr = mappedFilePtr else {
            throw SearchEngineError.internalError
        }
        
        guard let fileBuffer = device.makeBuffer(bytesNoCopy: mappedPtr, length: mappedFileLength, options: storageMode, deallocator: nil) else {
            throw SearchEngineError.failedToCreateBuffer("file content")
        }
        
        guard let patternData = pattern.data(using: .utf8) else {
            throw SearchEngineError.invalidPattern
        }
        
        let patternBuffer = try patternData.withUnsafeBytes { bytes in
            guard let buffer = device.makeBuffer(bytes: bytes.baseAddress!, length: patternData.count, options: storageMode) else {
                throw SearchEngineError.failedToCreateBuffer("pattern")
            }
            return buffer
        }
        
        var initialCount: UInt32 = 0
        guard let matchCountBuffer = device.makeBuffer(bytes: &initialCount, length: MemoryLayout<UInt32>.size, options: storageMode) else {
            throw SearchEngineError.failedToCreateBuffer("match count")
        }
        
        let positionsBufferSize = Int(maxPositionsToStore) * MemoryLayout<UInt32>.size
        guard let positionsBuffer = device.makeBuffer(length: positionsBufferSize, options: storageMode) else {
            throw SearchEngineError.failedToCreateBuffer("positions")
        }
        
        guard let cmdBuffer = commandQueue.makeCommandBuffer() else {
            throw SearchEngineError.failedToCreateCommandBuffer
        }
        
        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw SearchEngineError.failedToCreateCommandBuffer
        }
        
        encoder.setComputePipelineState(searchPipeline)
        encoder.setBuffer(fileBuffer, offset: 0, index: 0)
        encoder.setBuffer(patternBuffer, offset: 0, index: 1)
        
        var pLen = UInt32(pattern.utf8.count)
        encoder.setBytes(&pLen, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBuffer(matchCountBuffer, offset: 0, index: 3)
        
        var textLen = UInt32(mappedFileLength)
        encoder.setBytes(&textLen, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBuffer(positionsBuffer, offset: 0, index: 5)
        
        var maxPos = maxPositionsToStore
        encoder.setBytes(&maxPos, length: MemoryLayout<UInt32>.size, index: 6)
        
        let dispatchConfig = calculateDispatchConfiguration(
            pipeline: searchPipeline,
            totalPositions: mappedFileLength - Int(pLen) + 1
        )
        
        encoder.dispatchThreads(dispatchConfig.threadsPerGrid, 
                               threadsPerThreadgroup: dispatchConfig.threadsPerThreadgroup)
        encoder.endEncoding()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        guard cmdBuffer.status == .completed else {
            throw SearchEngineError.gpuExecutionFailed
        }
        
        let countPtr = matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        let totalMatchCount = countPtr.pointee
        let storedPositionCount = Int(min(totalMatchCount, maxPositionsToStore))
        
        var positions: [UInt32] = []
        if storedPositionCount > 0 {
            let positionsPtr = positionsBuffer.contents().bindMemory(to: UInt32.self, capacity: storedPositionCount)
            positions = Array(UnsafeBufferPointer(start: positionsPtr, count: storedPositionCount))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        let throughputMBps = (mappedFileLength > 0 && executionTime > 0)
            ? Double(mappedFileLength) / (executionTime * 1024 * 1024)
            : 0.0
        
        return SearchResult(
            matchCount: totalMatchCount,
            positions: positions,
            executionTime: executionTime,
            throughputMBps: throughputMBps,
            truncated: totalMatchCount > maxPositionsToStore
        )
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
    
    deinit {
        try? unmapFile()
    }
}

public enum SearchEngineError: Error, LocalizedError {
    case noMetalDevice
    case failedToCreateCommandQueue
    case failedToCreateLibrary
    case failedToCreatePipeline(Error)
    case failedToCreateBuffer(String)
    case failedToCreateCommandBuffer
    case failedToOpenFile(String)
    case failedToGetFileStats
    case memoryMappingFailed
    case unmappingFailed
    case noFileMapped
    case invalidPattern
    case gpuExecutionFailed
    case internalError
    
    public var errorDescription: String? {
        switch self {
        case .noMetalDevice: return "No Metal GPU found"
        case .failedToCreateCommandQueue: return "Failed to create command queue"
        case .failedToCreateLibrary: return "Failed to create Metal library"
        case .failedToCreatePipeline(let error): return "Failed to create Metal pipeline: \(error.localizedDescription)"
        case .failedToCreateBuffer(let type): return "Failed to create Metal buffer for \(type)"
        case .failedToCreateCommandBuffer: return "Failed to create command buffer"
        case .failedToOpenFile(let path): return "Failed to open file '\(path)'"
        case .failedToGetFileStats: return "Failed to get file stats"
        case .memoryMappingFailed: return "Memory mapping failed"
        case .unmappingFailed: return "Failed to unmap file"
        case .noFileMapped: return "No file mapped"
        case .invalidPattern: return "Invalid pattern"
        case .gpuExecutionFailed: return "GPU execution failed"
        case .internalError: return "Internal error"
        }
    }
}