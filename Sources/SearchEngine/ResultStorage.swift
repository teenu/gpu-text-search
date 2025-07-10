import Foundation

/// Unified result storage using Data-based approach optimized for all scenarios
public struct ResultStorage {
    private let positionData: Data
    public let count: UInt32
    public let truncated: Bool
    
    public init(positions: [UInt32], totalCount: UInt32, truncated: Bool) {
        self.positionData = Data(bytes: positions, count: positions.count * MemoryLayout<UInt32>.size)
        self.count = totalCount
        self.truncated = truncated
    }
    
    public init(positionData: Data, totalCount: UInt32, truncated: Bool) {
        self.positionData = positionData
        self.count = totalCount
        self.truncated = truncated
    }
    
    public func getPositions(limit: Int = Int.max) -> [UInt32] {
        let maxCount = min(limit, positionData.count / MemoryLayout<UInt32>.size)
        return positionData.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt32.self)
            return Array(buffer.prefix(maxCount))
        }
    }
    
    public func getAllPositions() -> [UInt32] {
        return positionData.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt32.self)
            return Array(buffer)
        }
    }
    
    public func contains(position: UInt32) -> Bool {
        return positionData.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt32.self)
            return buffer.contains(position)
        }
    }
    
    public func memoryUsage() -> Int {
        return positionData.count
    }
    
    /// Get direct access to position data for efficient binary export
    internal func getPositionData() -> Data {
        return positionData
    }
}