import Foundation

// MARK: - Search Engine Constants

/// Centralized constants for the GPU Text Search engine
/// All magic numbers and hardcoded values are defined here for maintainability
public enum SearchEngineConstants {
    
    // MARK: - Buffer Size Configuration
    
    /// Minimum number of positions to store in GPU memory
    public static let minPositionsToStore: UInt64 = 1024
    
    /// Maximum positions buffer size for Apple Silicon (unified memory)
    public static let maxPositionsAppleSilicon: UInt64 = 50_000_000
    
    /// Maximum positions buffer size for discrete GPUs
    public static let maxPositionsDiscreteGPU: UInt64 = 25_000_000
    
    /// Default position buffer size for fallback scenarios
    public static let defaultPositionBufferSize: UInt32 = 1_000_000
    
    /// Maximum number of patterns to cache in LRU cache
    public static let maxPatternCacheSize = 32
    
    // MARK: - Performance Tuning
    
    /// Default threadgroup width for Metal compute kernels
    public static let defaultThreadgroupWidth = 256
    
    /// Bytes per megabyte for throughput calculations
    public static let bytesPerMB: Double = 1_048_576.0
    
    /// Bytes per gigabyte for file size calculations
    public static let bytesPerGB: Double = 1_073_741_824.0
    
    
    // MARK: - Pattern Validation
    
    /// Maximum pattern length in bytes
    public static let maxPatternLengthBytes = 4096
    
    
    // MARK: - Development and Testing
    
    /// Default benchmark iterations for testing
    public static let defaultBenchmarkIterations = 100
    
    /// Default warmup pattern for GPU initialization
    public static let defaultWarmupPattern = "X"
    
    /// Test pattern cache size limit for development
    public static let testPatternCacheLimit = 16
    
}

// MARK: - Search Engine String Constants

/// Essential string constants for the GPU Text Search engine
public enum SearchEngineStrings {
    
    // MARK: - Metal Resource Names
    
    /// Name of the Metal compute kernel function
    public static let metalKernelFunctionName = "searchOptimizedKernel"
    
    /// Label for the search kernel pipeline
    public static let searchKernelPipelineLabel = "GPU Text Search Pipeline"
    
    // MARK: - Buffer Labels
    
    /// Label for file content buffer
    public static let fileContentBufferLabel = "File Content Buffer"
    
    /// Label for persistent match count buffer
    public static let persistentMatchCountLabel = "Persistent Match Count Buffer"
    
    /// Label for persistent positions buffer
    public static let persistentPositionsLabel = "Persistent Positions Buffer"
    
    // MARK: - File Names and Extensions
    
    /// Metal shader file name
    public static let metalShaderFileName = "SearchKernel"
    
    /// Metal shader file extension
    public static let metalShaderFileExtension = "metal"
    
    /// Metal binary archive file name
    public static let metalBinaryArchiveName = "SearchKernelArchive"
    
    /// Metal binary archive file extension
    public static let metalBinaryArchiveExtension = "metallib"
    
    /// Bundle resource name for search engine
    public static let bundleResourceName = "GPUTextSearch_SearchEngine.bundle"
    
    // MARK: - Build Paths
    
    /// Release build directory path for ARM64
    public static let releaseBuildPathARM64 = ".build/arm64-apple-macosx/release"
    
    /// Homebrew library installation path
    public static let homebrewLibPath = "../lib"
    
    // MARK: - Test File Configuration
    
    /// Prefix for test file names
    public static let testFilePrefix = "gpu_test_"
    
    /// Extension for test files
    public static let testFileExtension = ".txt"
}

