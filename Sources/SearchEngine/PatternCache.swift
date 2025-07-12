import Foundation
import Metal

/// Manages pattern buffer caching with LRU eviction
final class PatternCache {
    
    private let metalResourceManager: MetalResourceManager
    private var patternCache: [String: MTLBuffer] = [:]
    private var accessOrder: [String] = []
    private static let maxCacheSize = Configuration.maxPatternCacheSize
    
    init(metalResourceManager: MetalResourceManager) {
        self.metalResourceManager = metalResourceManager
    }
    
    private func compactCacheUnderMemoryPressure() {
        let targetSize = max(1, Configuration.maxPatternCacheSize / 4)
        
        while patternCache.count > targetSize && !accessOrder.isEmpty {
            let lruKey = accessOrder.removeFirst()
            patternCache.removeValue(forKey: lruKey)
        }
    }
    
    func getCachedPatternBuffer(for pattern: String) throws -> MTLBuffer {
        if let cachedBuffer = patternCache[pattern] {
            if let index = accessOrder.firstIndex(of: pattern) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(pattern)
            return cachedBuffer
        }
        
        guard let patternData = pattern.data(using: .utf8) else {
            throw ValidationError.patternEncodingFailed(pattern)
        }
        
        let device = try metalResourceManager.getDevice()
        let buffer = device.makeBuffer(
            bytes: [UInt8](patternData),
            length: patternData.count,
            options: metalResourceManager.optimalStorageMode()
        )
        
        guard let buffer = buffer else {
            throw MetalError.bufferCreationFailed("pattern", size: patternData.count)
        }
        
        buffer.label = "Pattern Buffer: \(pattern)"
        
        if patternCache.count >= Configuration.maxPatternCacheSize {
            let lruKey = accessOrder.removeFirst()
            patternCache.removeValue(forKey: lruKey)
        }
        
        patternCache[pattern] = buffer
        accessOrder.append(pattern)
        return buffer
    }
    
    func getCacheStatistics() -> [String: Any] {
        return [
            "cacheSize": patternCache.count,
            "maxCacheSize": Configuration.maxPatternCacheSize,
            "cachedPatterns": Array(patternCache.keys),
            "accessOrder": accessOrder,
            "cacheUtilization": Double(patternCache.count) / Double(Configuration.maxPatternCacheSize)
        ]
    }
    
    func isPatternCached(_ pattern: String) -> Bool {
        return patternCache[pattern] != nil
    }
    
    func clearCache() {
        patternCache.removeAll()
        accessOrder.removeAll()
    }
    
    var cacheSize: Int {
        return patternCache.count
    }
    
    var maxCacheSize: Int {
        return Configuration.maxPatternCacheSize
    }
    
    func warmupCache(with patterns: [String]) throws {
        for pattern in patterns {
            _ = try getCachedPatternBuffer(for: pattern)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}