import Foundation
import Metal

/// Manages Metal GPU resources, pipeline states, and compute dispatch configuration
final class MetalResourceManager {
    
    private static let kernelFunctionName = Configuration.kernelFunctionName
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var searchPipeline: MTLComputePipelineState?
    private var binaryArchive: MTLBinaryArchive?
    
    var gpuName: String { 
        guard let device = device else { return "Not Initialized" }
        return device.name 
    }
    let maxPositionsToStore: UInt32
    
    /// Get the Metal device, initializing if needed
    func getDevice() throws -> MTLDevice {
        try ensureMetalInitialized()
        guard let device = device else {
            throw MetalError.noDeviceAvailable
        }
        return device
    }
    
    private var persistentMatchCountBuffer: MTLBuffer?
    private var persistentPositionsBuffer: MTLBuffer?
    
    init(maxPositions: UInt32? = nil, eagerInit: Bool = true) throws {
        self.maxPositionsToStore = Configuration.getOptimalMaxPositions(for: nil, requestedPositions: maxPositions)
        
        if eagerInit {
            // Eager initialization - setup all GPU resources immediately for consistent cold start performance
            guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
                throw MetalError.noDeviceAvailable
            }
            
            guard defaultDevice.supportsFamily(.common1) else {
                throw MetalError.deviceNotSupported(defaultDevice.name)
            }
            
            self.device = defaultDevice
            
            guard let queue = defaultDevice.makeCommandQueue() else {
                throw MetalError.commandQueueCreationFailed
            }
            self.commandQueue = queue
            
            // Setup all resources upfront for consistent performance
            try setupPersistentBuffers()
            try setupBinaryArchive()
            try setupSearchPipeline()
        } else {
            // Lazy initialization - defer all Metal operations until first search
            self.device = nil
            self.commandQueue = nil
            self.persistentMatchCountBuffer = nil
            self.persistentPositionsBuffer = nil
        }
    }
    
    /// Ensure Metal device and command queue are initialized (lazy initialization)
    private func ensureMetalInitialized() throws {
        if device == nil {
            guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
                throw MetalError.noDeviceAvailable
            }
            
            guard defaultDevice.supportsFamily(.common1) else {
                throw MetalError.deviceNotSupported(defaultDevice.name)
            }
            
            self.device = defaultDevice
            
            guard let queue = defaultDevice.makeCommandQueue() else {
                throw MetalError.commandQueueCreationFailed
            }
            self.commandQueue = queue
            
            // Setup basic buffers
            try setupPersistentBuffers()
        }
    }
    
    private func setupBinaryArchive() throws {
        guard let device = device else {
            throw MetalError.noDeviceAvailable
        }
        
        let archiveDescriptor = MTLBinaryArchiveDescriptor()
        
        if let archiveURL = getBinaryArchiveURL() {
            archiveDescriptor.url = archiveURL
        }
        
        do {
            binaryArchive = try device.makeBinaryArchive(descriptor: archiveDescriptor)
        } catch {
            let newDescriptor = MTLBinaryArchiveDescriptor()
            binaryArchive = try device.makeBinaryArchive(descriptor: newDescriptor)
        }
    }
    
    private func getBinaryArchiveURL() -> URL? {
        if let bundleURL = Bundle.main.url(forResource: "SearchKernelArchive", withExtension: "metallib") {
            return bundleURL
        }
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cacheDir?.appendingPathComponent(Configuration.binaryArchiveFileName)
    }
    
    private func setupPersistentBuffers() throws {
        guard let device = device else {
            throw MetalError.noDeviceAvailable
        }
        
        let resourceOptions = optimalStorageMode()
        
        // Pre-allocate persistent match count buffer (4 bytes)
        var initialCount: UInt32 = 0
        persistentMatchCountBuffer = device.makeBuffer(
            bytes: &initialCount,
            length: MemoryLayout<UInt32>.size,
            options: resourceOptions
        )
        persistentMatchCountBuffer?.label = "Persistent Match Count Buffer"
        
        // Pre-allocate positions buffer at maximum size for consistent cold start performance
        let positionsBufferSize = Int(maxPositionsToStore) * MemoryLayout<UInt32>.size
        persistentPositionsBuffer = device.makeBuffer(
            length: positionsBufferSize,
            options: resourceOptions
        )
        persistentPositionsBuffer?.label = "Persistent Positions Buffer"
        
        guard persistentMatchCountBuffer != nil && persistentPositionsBuffer != nil else {
            throw MetalError.bufferCreationFailed("persistent buffers", size: positionsBufferSize)
        }
    }
    
    func optimalStorageMode() -> MTLResourceOptions {
        return .storageModeShared
    }
    
    private func setupSearchPipeline() throws {
        guard let device = device else {
            throw MetalError.noDeviceAvailable
        }
        
        let library: MTLLibrary
        if let bundleLibrary = device.makeDefaultLibrary() {
            library = bundleLibrary
        } else {
            library = try compileKernelFromSource()
        }
        
        guard let kernelFunction = library.makeFunction(name: Self.kernelFunctionName) else {
            throw MetalError.kernelFunctionNotFound(Self.kernelFunctionName)
        }
        
        do {
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.computeFunction = kernelFunction
            pipelineDescriptor.label = "Search Kernel Pipeline"
            
            if let archive = binaryArchive {
                pipelineDescriptor.binaryArchives = [archive]
            }
            
            searchPipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
        } catch {
            throw MetalError.pipelineCreationFailed(error.localizedDescription)
        }
    }
    
    private func compileKernelFromSource() throws -> MTLLibrary {
        guard let device = device else {
            throw MetalError.noDeviceAvailable
        }
        
        let metalURL = try findMetalResource()
        let kernelSource = try String(contentsOf: metalURL)
        
        do {
            return try device.makeLibrary(source: kernelSource, options: nil)
        } catch {
            throw MetalError.libraryCreationFailed
        }
    }
    
    private func findMetalResource() throws -> URL {
        let searchPaths: [URL] = [
            Bundle.module.bundleURL,
            
            (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
                .deletingLastPathComponent()
                .appendingPathComponent("../lib/GPUTextSearch_SearchEngine.bundle")
                .standardizedFileURL,
            
            (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
                .deletingLastPathComponent()
                .appendingPathComponent("GPUTextSearch_SearchEngine.bundle"),
            
            URL(fileURLWithPath: ".build/arm64-apple-macosx/release/GPUTextSearch_SearchEngine.bundle"),
            
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/arm64-apple-macosx/release/GPUTextSearch_SearchEngine.bundle")
        ]
        
        for bundlePath in searchPaths {
            if let bundle = Bundle(url: bundlePath),
               let metalURL = bundle.url(forResource: Configuration.metalShaderResourceName, withExtension: Configuration.metalShaderResourceExtension) {
                return metalURL
            }
        }
        
        if let moduleURL = Bundle.module.url(forResource: Configuration.metalShaderResourceName, withExtension: Configuration.metalShaderResourceExtension) {
            return moduleURL
        }
        
        throw MetalError.libraryCreationFailed
    }
    
    func getPersistentMatchCountBuffer() throws -> MTLBuffer {
        guard let buffer = persistentMatchCountBuffer else {
            throw MetalError.bufferCreationFailed("persistent match count buffer", size: 0)
        }
        
        guard buffer.length >= MemoryLayout<UInt32>.size else {
            throw MetalError.bufferCreationFailed("match count buffer", size: buffer.length)
        }
        let countPtr = buffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        countPtr.pointee = 0
        
        return buffer
    }
    
    func createBuffer(size: Int) -> MTLBuffer? {
        guard let device = device else { return nil }
        return device.makeBuffer(length: size, options: optimalStorageMode())
    }
    
    func getPersistentPositionsBuffer() throws -> MTLBuffer {
        try ensureMetalInitialized()
        
        // For eager initialization, buffer is already allocated
        // For lazy initialization, create buffer on first access
        if persistentPositionsBuffer == nil {
            guard let device = device else {
                throw MetalError.noDeviceAvailable
            }
            
            let positionsBufferSize = Int(maxPositionsToStore) * MemoryLayout<UInt32>.size
            persistentPositionsBuffer = device.makeBuffer(
                length: positionsBufferSize,
                options: optimalStorageMode()
            )
            persistentPositionsBuffer?.label = "Persistent Positions Buffer"
        }
        
        guard let buffer = persistentPositionsBuffer else {
            throw MetalError.bufferCreationFailed("persistent positions buffer", size: Int(maxPositionsToStore) * MemoryLayout<UInt32>.size)
        }
        return buffer
    }
    
    func executeGPUSearch(
        fileBuffer: MTLBuffer,
        patternBuffer: MTLBuffer,
        patternLength: UInt32,
        textLength: UInt32,
        matchCountBuffer: MTLBuffer,
        positionsBuffer: MTLBuffer
    ) throws -> (totalCount: UInt32, positions: [UInt32], truncated: Bool) {
        
        // Ensure Metal is initialized before any GPU operations
        try ensureMetalInitialized()
        
        // Lazy setup of binary archive and pipeline on first search
        if searchPipeline == nil {
            try setupBinaryArchive()
            try setupSearchPipeline()
        }
        
        guard let pipeline = searchPipeline else {
            throw MetalError.pipelineCreationFailed("Pipeline not available")
        }
        
        guard let commandQueue = commandQueue,
              let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw MetalError.commandBufferCreationFailed
        }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(fileBuffer, offset: 0, index: 0)
        encoder.setBuffer(patternBuffer, offset: 0, index: 1)
        
        var pLen = patternLength
        encoder.setBytes(&pLen, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBuffer(matchCountBuffer, offset: 0, index: 3)
        
        var tLen = textLength
        encoder.setBytes(&tLen, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBuffer(positionsBuffer, offset: 0, index: 5)
        
        var maxPos = maxPositionsToStore
        encoder.setBytes(&maxPos, length: MemoryLayout<UInt32>.size, index: 6)
        
        let dispatchConfig = calculateDispatchConfiguration(
            pipeline: pipeline,
            totalPositions: Int(textLength) - Int(patternLength) + 1
        )
        
        encoder.dispatchThreads(dispatchConfig.threadsPerGrid, 
                               threadsPerThreadgroup: dispatchConfig.threadsPerThreadgroup)
        encoder.endEncoding()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        guard cmdBuffer.status == .completed else {
            let errorDesc = cmdBuffer.error?.localizedDescription ?? "Unknown GPU error"
            throw MetalError.gpuExecutionFailed(errorDesc)
        }
        
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
        
        let threadWidth = pipeline.threadExecutionWidth
        let maxGroup = pipeline.maxTotalThreadsPerThreadgroup
        let desiredGroupWidth = (threadWidth > 0 && maxGroup >= threadWidth) 
            ? (maxGroup / threadWidth) * threadWidth 
            : Configuration.defaultThreadgroupSize
        let groupWidth = min(maxGroup, desiredGroupWidth, totalPositions)
        
        let threadsPerThreadgroup = MTLSize(width: max(1, groupWidth), height: 1, depth: 1)
        
        return (threadsPerGrid, threadsPerThreadgroup)
    }
    
    private func extractResults(
        from matchCountBuffer: MTLBuffer,
        positionsBuffer: MTLBuffer
    ) -> (totalCount: UInt32, positions: [UInt32], truncated: Bool) {
        
        guard matchCountBuffer.length >= MemoryLayout<UInt32>.size else {
            return (0, [], false)
        }
        
        let countPtr = matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        let totalMatchCount = countPtr.pointee
        let storedPositionCount = Int(min(totalMatchCount, maxPositionsToStore))
        
        var positions: [UInt32] = []
        if storedPositionCount > 0 {
            let requiredBufferSize = storedPositionCount * MemoryLayout<UInt32>.size
            guard positionsBuffer.length >= requiredBufferSize else {
                return (totalMatchCount, [], true) // Truncated due to buffer size issue
            }
            let positionsPtr = positionsBuffer.contents().bindMemory(to: UInt32.self, capacity: storedPositionCount)
            positions = Array(UnsafeBufferPointer(start: positionsPtr, count: storedPositionCount))
        }
        
        let truncated = totalMatchCount > maxPositionsToStore
        
        return (totalMatchCount, positions, truncated)
    }
    
    func getCommandQueue() throws -> MTLCommandQueue {
        try ensureMetalInitialized()
        guard let commandQueue = commandQueue else {
            throw MetalError.commandQueueCreationFailed
        }
        return commandQueue
    }
    
}