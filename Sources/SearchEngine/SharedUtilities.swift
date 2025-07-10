import Foundation

/// Shared utility functions used across the search engine modules
public enum SharedUtilities {
    
    public static func calculateStandardDeviation(_ values: [TimeInterval]) -> TimeInterval {
        guard values.count > 1 else { return 0 }
        var mean: Double = 0
        var m2: Double = 0
        var count: Double = 0
        
        for value in values {
            count += 1
            let delta = value - mean
            mean += delta / count
            let delta2 = value - mean
            m2 += delta * delta2
        }
        
        return sqrt(m2 / (count - 1))
    }
    
    public static func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        
        let index = (percentile / 100.0) * Double(sortedValues.count - 1)
        let lowerIndex = Int(index)
        let upperIndex = min(lowerIndex + 1, sortedValues.count - 1)
        
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        
        let weight = index - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
    }
    
    public static func formatFileSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.2f MB (%lld bytes)", mb, Int64(bytes))
    }
    
    public static func validateFileExists(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw FileSystemError.fileNotFound(path)
        }
        
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw FileSystemError.fileNotReadable(path)
        }
    }
}