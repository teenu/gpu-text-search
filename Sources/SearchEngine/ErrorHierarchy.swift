import Foundation
import Metal

/// Base protocol for all search engine errors
public protocol SearchEngineErrorProtocol: Error, LocalizedError {
    var errorCode: String { get }
}

/// Errors related to Metal GPU operations and resources
public enum MetalError: SearchEngineErrorProtocol {
    case noDeviceAvailable
    case deviceNotSupported(String)
    case commandQueueCreationFailed
    case libraryCreationFailed
    case kernelFunctionNotFound(String)
    case pipelineCreationFailed(String)
    case bufferCreationFailed(String, size: Int)
    case commandBufferCreationFailed
    case gpuExecutionFailed(String)
    case binaryArchiveError(String)
    
    
    public var errorCode: String {
        switch self {
        case .noDeviceAvailable: return "METAL_001"
        case .deviceNotSupported: return "METAL_002"
        case .commandQueueCreationFailed: return "METAL_003"
        case .libraryCreationFailed: return "METAL_004"
        case .kernelFunctionNotFound: return "METAL_005"
        case .pipelineCreationFailed: return "METAL_006"
        case .bufferCreationFailed: return "METAL_007"
        case .commandBufferCreationFailed: return "METAL_008"
        case .gpuExecutionFailed: return "METAL_009"
        case .binaryArchiveError: return "METAL_010"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .noDeviceAvailable:
            return "No Metal GPU device available on this system"
        case .deviceNotSupported(let device):
            return "Metal device '\(device)' does not support required features"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .libraryCreationFailed:
            return "Failed to create Metal library"
        case .kernelFunctionNotFound(let name):
            return "Metal kernel function '\(name)' not found"
        case .pipelineCreationFailed(let details):
            return "Failed to create Metal compute pipeline: \(details)"
        case .bufferCreationFailed(let type, let size):
            return "Failed to create Metal buffer for \(type) (size: \(size) bytes)"
        case .commandBufferCreationFailed:
            return "Failed to create Metal command buffer"
        case .gpuExecutionFailed(let details):
            return "GPU execution failed: \(details)"
        case .binaryArchiveError(let details):
            return "Binary archive operation failed: \(details)"
        }
    }
    
}

/// Errors related to file system operations
public enum FileSystemError: SearchEngineErrorProtocol {
    case fileNotFound(String)
    case fileNotReadable(String)
    case invalidFileSize(Int64)
    case fileTooLarge(Int64, maxSize: Int64)
    case memoryMappingFailed(String, systemError: String)
    case unmappingFailed(String)
    case fileStatsError(String)
    case exportFileCreationFailed(String)
    case writeOperationFailed(String)
    
    
    public var errorCode: String {
        switch self {
        case .fileNotFound: return "FS_001"
        case .fileNotReadable: return "FS_002"
        case .invalidFileSize: return "FS_003"
        case .fileTooLarge: return "FS_004"
        case .memoryMappingFailed: return "FS_005"
        case .unmappingFailed: return "FS_006"
        case .fileStatsError: return "FS_007"
        case .exportFileCreationFailed: return "FS_008"
        case .writeOperationFailed: return "FS_009"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileNotReadable(let path):
            return "File is not readable: \(path)"
        case .invalidFileSize(let size):
            return "Invalid file size: \(size) bytes"
        case .fileTooLarge(let size, let maxSize):
            return "File too large: \(size) bytes (maximum: \(maxSize) bytes)"
        case .memoryMappingFailed(let path, let systemError):
            return "Memory mapping failed for '\(path)': \(systemError)"
        case .unmappingFailed(let error):
            return "Failed to unmap file: \(error)"
        case .fileStatsError(let error):
            return "Failed to get file statistics: \(error)"
        case .exportFileCreationFailed(let path):
            return "Failed to create export file: \(path)"
        case .writeOperationFailed(let error):
            return "Write operation failed: \(error)"
        }
    }
    
}

/// Errors related to input validation
public enum ValidationError: SearchEngineErrorProtocol {
    case emptyPattern
    case patternTooLong(Int, maxLength: Int)
    case patternEncodingFailed(String)
    case invalidIterationCount(Int, allowedRange: ClosedRange<Int>)
    case invalidConfiguration(String)
    case noFileMapped
    case noSearchPerformed
    case unsupportedFormat(String, supportedFormats: [String])
    
    
    public var errorCode: String {
        switch self {
        case .emptyPattern: return "VAL_001"
        case .patternTooLong: return "VAL_002"
        case .patternEncodingFailed: return "VAL_003"
        case .invalidIterationCount: return "VAL_004"
        case .invalidConfiguration: return "VAL_005"
        case .noFileMapped: return "VAL_006"
        case .noSearchPerformed: return "VAL_007"
        case .unsupportedFormat: return "VAL_008"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .emptyPattern:
            return "Search pattern cannot be empty"
        case .patternTooLong(let length, let maxLength):
            return "Pattern too long: \(length) characters (maximum: \(maxLength))"
        case .patternEncodingFailed(let pattern):
            return "Pattern '\(pattern)' failed to encode as UTF-8"
        case .invalidIterationCount(let count, let range):
            return "Invalid iteration count: \(count) (allowed: \(range))"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        case .noFileMapped:
            return "No file is currently mapped for searching"
        case .noSearchPerformed:
            return "No search has been performed yet"
        case .unsupportedFormat(let format, let supportedFormats):
            return "Unsupported format '\(format)' (supported: \(supportedFormats.joined(separator: ", ")))"
        }
    }
    
}

