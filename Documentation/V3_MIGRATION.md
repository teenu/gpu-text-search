# V3 Foundation Migration Guide

## Overview

This guide helps developers migrate from previous versions to the V3 Foundation. The V3 Foundation represents a complete architectural overhaul focused on ultra-lean design, improved error handling, and optimal performance.

## Migration Summary

| Aspect | V2.x | V3 Foundation | Impact |
|--------|------|---------------|---------|
| **Code Size** | 1,200+ lines | 453 lines | 62% reduction |
| **Performance** | 7.08 GB/s | 7.03 GB/s | Maintained |
| **Error Handling** | Mixed | Comprehensive | Improved |
| **API Surface** | Complex | Minimal | Simplified |
| **Dependencies** | Multiple | Single | Reduced |

## Breaking Changes

### 1. Removed Features

#### Benchmarking System
```swift
// V2.x - REMOVED
let benchmark = try engine.benchmark(
    file: fileURL, 
    pattern: pattern, 
    iterations: 100
)

// V3 Foundation - Manual implementation required
let results: [SearchResult] = []
for _ in 0..<iterations {
    let result = try engine.search(pattern: pattern)
    results.append(result)
}
```

#### Binary Export
```swift
// V2.x - REMOVED
try engine.exportPositionsBinary(to: exportURL)

// V3 Foundation - Manual implementation
let result = try engine.search(pattern: pattern)
let data = Data(bytes: result.positions, count: result.positions.count * 4)
try data.write(to: exportURL)
```

#### Warmup Functionality
```swift
// V2.x - REMOVED
try engine.warmup()

// V3 Foundation - Automatic optimization
// No warmup needed - pipeline is pre-optimized
```

#### Public Properties
```swift
// V2.x - REMOVED
engine.gpuName          // Use Metal device directly
engine.isFileMapped     // Track state manually
engine.fileSize         // Track file size manually
```

### 2. Error Handling Changes

#### Expanded Error Types
```swift
// V3 Foundation - New error cases
public enum SearchEngineError: Error, LocalizedError {
    case noMetalDevice
    case failedToCreateCommandQueue
    case failedToCreateLibrary        // NEW
    case failedToCreatePipeline(Error) // NEW
    case failedToCreateBuffer(String)  // NEW
    case failedToCreateCommandBuffer   // NEW
    case failedToOpenFile(String)
    case failedToGetFileStats
    case memoryMappingFailed
    case unmappingFailed
    case noFileMapped
    case invalidPattern
    case gpuExecutionFailed
    case internalError
}
```

#### Improved Error Messages
```swift
// V2.x
throw SearchEngineError.failedToCreateBuffer

// V3 Foundation
throw SearchEngineError.failedToCreateBuffer("pattern buffer")
```

### 3. CLI Interface Changes

#### Removed Commands
```bash
# V2.x - REMOVED
search-cli benchmark file.txt "pattern" --iterations 100
search-cli profile file.txt --patterns "A,T,C,G"

# V3 Foundation - Only search command
search-cli file.txt "pattern" [--verbose] [--quiet]
```

#### Simplified Output
```bash
# V2.x - Complex output
--- Search Results ---
Matches found: 733756
Execution time: 0.4099 seconds  
Throughput: 7326.10 MB/s
⚠️ Results truncated (buffer limit reached)
First 100 positions:
[52368, 42055, 16160, ...]

# V3 Foundation - Clean output
Matches: 733756
Time: 0.4099s
Throughput: 7326.10 MB/s
(truncated)
Positions: 52368, 42055, 16160, ...
```

## Migration Steps

### Step 1: Update Package Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/teenu/gpu-text-search.git", 
             from: "3.0.0") // Update to V3
]
```

### Step 2: Update Error Handling

```swift
// Before (V2.x)
do {
    let result = try engine.search(pattern: pattern)
} catch SearchEngineError.failedToCreateBuffer {
    print("Buffer creation failed")
}

// After (V3 Foundation)
do {
    let result = try engine.search(pattern: pattern)
} catch SearchEngineError.failedToCreateBuffer(let bufferType) {
    print("Failed to create \(bufferType) buffer")
} catch SearchEngineError.failedToCreatePipeline(let error) {
    print("Pipeline creation failed: \(error)")
}
```

### Step 3: Replace Removed Features

#### Benchmarking
```swift
// V2.x
let benchmark = try engine.benchmark(file: fileURL, pattern: pattern, iterations: 100)
print("Average: \(benchmark.averageTime)s")

// V3 Foundation
func benchmark(engine: SearchEngine, pattern: String, iterations: Int) throws -> (averageTime: TimeInterval, averageThroughput: Double) {
    var times: [TimeInterval] = []
    var throughputs: [Double] = []
    
    for _ in 0..<iterations {
        let result = try engine.search(pattern: pattern)
        times.append(result.executionTime)
        throughputs.append(result.throughputMBps)
    }
    
    let avgTime = times.reduce(0, +) / Double(times.count)
    let avgThroughput = throughputs.reduce(0, +) / Double(throughputs.count)
    
    return (avgTime, avgThroughput)
}
```

#### Multiple Pattern Search
```swift
// V2.x
let results = try engine.searchMultiple(patterns: ["A", "T", "C", "G"])

// V3 Foundation
func searchMultiple(engine: SearchEngine, patterns: [String]) throws -> [SearchResult] {
    return try patterns.map { pattern in
        try engine.search(pattern: pattern)
    }
}
```

### Step 4: Update CLI Usage

```bash
# V2.x
search-cli benchmark genome.fasta "GATTACA" --iterations 100 --csv

# V3 Foundation - Manual benchmarking
for i in {1..100}; do
    search-cli genome.fasta "GATTACA" --verbose
done > benchmark_results.txt
```

## Code Examples

### Basic Migration Example

```swift
// V2.x Code
import SearchEngine

let engine = try SearchEngine()
print("Using GPU: \(engine.gpuName)")

try engine.mapFile(at: fileURL)
print("File mapped: \(engine.fileSize) bytes")

// Warmup for peak performance
try engine.warmup()

// Benchmark performance
let benchmark = try engine.benchmark(
    file: fileURL, 
    pattern: "GATTACA", 
    iterations: 10
)
print("Average throughput: \(benchmark.averageThroughput) MB/s")

// Export results
try engine.exportPositionsBinary(to: exportURL)
```

```swift
// V3 Foundation Code
import SearchEngine

let engine = try SearchEngine()
// Note: GPU name not available - use Metal device directly if needed

try engine.mapFile(at: fileURL)
// Note: File size not available - track manually if needed

// No warmup needed - automatically optimized

// Manual benchmarking
var results: [SearchResult] = []
for _ in 0..<10 {
    let result = try engine.search(pattern: "GATTACA")
    results.append(result)
}

let avgThroughput = results.map(\.throughputMBps).reduce(0, +) / Double(results.count)
print("Average throughput: \(avgThroughput) MB/s")

// Manual export
if let firstResult = results.first {
    let data = Data(bytes: firstResult.positions, count: firstResult.positions.count * 4)
    try data.write(to: exportURL)
}
```

## Performance Considerations

### V3 Foundation Advantages

1. **Reduced Overhead**: 62% less code means faster compilation and smaller binary
2. **Improved Error Handling**: More robust error recovery
3. **Cleaner API**: Simpler to use and maintain
4. **Better Resource Management**: Automatic cleanup and optimization

### Performance Comparison

```swift
// V2.x Performance
- Average: 7.08 GB/s
- Code size: 1,200+ lines
- Memory overhead: Higher due to caching systems

// V3 Foundation Performance  
- Average: 7.03 GB/s (-0.7% - within margin of error)
- Code size: 453 lines
- Memory overhead: Minimal - only essential buffers
```

## Testing Your Migration

### 1. Accuracy Verification

```swift
// Verify identical results
let v2Result = try v2Engine.search(pattern: pattern)
let v3Result = try v3Engine.search(pattern: pattern)

assert(v2Result.matchCount == v3Result.matchCount)
assert(v2Result.positions.prefix(1000) == v3Result.positions.prefix(1000))
```

### 2. Performance Validation

```bash
# Test performance hasn't regressed
time ./v2_search file.txt "pattern" --quiet
time ./v3_search file.txt "pattern" --quiet

# Should be within 5% of each other
```

### 3. Error Handling Testing

```swift
// Test new error handling
do {
    let result = try engine.search(pattern: "")
    XCTFail("Should have thrown invalidPattern error")
} catch SearchEngineError.invalidPattern {
    // Expected
} catch {
    XCTFail("Unexpected error: \(error)")
}
```

## Common Migration Issues

### Issue: Missing GPU Name
```swift
// Problem: engine.gpuName removed
// Solution: Access Metal device directly
let device = MTLCreateSystemDefaultDevice()
print("GPU: \(device?.name ?? "Unknown")")
```

### Issue: No File Size Property
```swift
// Problem: engine.fileSize removed
// Solution: Track manually
let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64
```

### Issue: Missing Benchmarking
```swift
// Problem: benchmark() method removed
// Solution: Implement manually (see examples above)
```

## Best Practices for V3 Foundation

1. **Error Handling**: Always wrap API calls in try-catch blocks
2. **Resource Management**: Let SearchEngine handle cleanup automatically
3. **Performance**: Use release builds for production
4. **Testing**: Verify accuracy against known results
5. **Memory**: Monitor memory usage with large files

## Rollback Strategy

If you encounter issues with V3 Foundation:

1. **Temporary Rollback**: Pin to V2.x in Package.swift
2. **Gradual Migration**: Migrate incrementally, testing each step
3. **Performance Testing**: Verify performance meets requirements
4. **Feature Parity**: Implement missing features as needed

## Support and Resources

- **V3 Foundation Reference**: Complete API documentation
- **Developer Guide**: Implementation details and best practices
- **Performance Benchmarks**: Detailed performance comparisons
- **Test Suite**: Comprehensive test coverage

## Conclusion

The V3 Foundation provides a cleaner, more maintainable codebase while preserving the high performance of previous versions. The migration requires updating error handling and replacing some removed features, but the result is a more robust and efficient text search engine.

Key benefits of migration:
- ✅ 62% less code to maintain
- ✅ Improved error handling and safety
- ✅ Simplified API surface
- ✅ Maintained performance (7+ GB/s)
- ✅ Better resource management

The V3 Foundation is ready for production use and provides an excellent foundation for future development.