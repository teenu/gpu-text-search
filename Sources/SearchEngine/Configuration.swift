import Foundation

/// Configuration constants for the search engine
public enum Configuration {
    
    public static let maxPatternCacheSize = 32
    public static let maxFileSize: Int64 = 50 * 1024 * 1024 * 1024
    public static let defaultBenchmarkIterations = 100
    public static let maxBenchmarkIterations = 10000
    public static let defaultProfileIterations = 10
    public static let maxProfileIterations = 1000
    public static let defaultPositionDisplayLimit = 100
    
    public static let defaultMaxPositions: UInt32 = 50_000_000
    public static let minMaxPositions: UInt32 = 1_000_000
    public static let maxMaxPositions: UInt32 = 500_000_000
    
    public static let defaultThreadgroupSize = 64
    public static let kernelFunctionName = "searchOptimizedKernel"
    public static let binaryArchiveFileName = "SearchKernelArchive.metallib"
    public static let metalShaderResourceName = "SearchKernel"
    public static let metalShaderResourceExtension = "metal"
    
    public static func validateIterations(_ iterations: Int, max: Int) throws {
        let range = 1...max
        guard range.contains(iterations) else {
            throw ValidationError.invalidIterationCount(iterations, allowedRange: range)
        }
    }
    
    /// Get optimal maximum positions
    public static func getOptimalMaxPositions(for device: MTLDevice? = nil, requestedPositions: UInt32? = nil) -> UInt32 {
        // Use user-provided value if specified
        if let requested = requestedPositions {
            // Validate bounds for safety
            return max(minMaxPositions, min(requested, maxMaxPositions))
        }
        
        // Default: 50M positions
        return defaultMaxPositions
    }
    
}

import Metal