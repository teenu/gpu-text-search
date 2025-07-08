# V3 Foundation Developer Guide

## Development Environment Setup

### Requirements

- **macOS 13+** (Ventura or later)
- **Xcode 15.0+** with Command Line Tools
- **Swift 5.9+**
- **Metal-capable GPU** (Apple Silicon recommended)

### Project Structure

```
gpu-text-search/
├── Package.swift                   # Swift Package Manager configuration
├── Sources/
│   ├── SearchEngine/
│   │   ├── SearchEngine.swift      # Core GPU search engine (256 lines)
│   │   └── SearchKernel.metal      # Metal compute shader (81 lines)
│   └── SearchCLI/
│       └── main.swift              # Command-line interface (46 lines)
├── Tests/
│   └── SearchEngineTests/
│       └── SearchEngineTests.swift # Unit tests (67 lines)
└── Documentation/
    ├── V3_FOUNDATION_REFERENCE.md  # API reference
    ├── V3_DEVELOPER_GUIDE.md       # This file
    └── V3_MIGRATION.md             # Migration guide
```

## Building and Testing

### Debug Build

```bash
swift build
```

Output: `.build/debug/search-cli`

### Release Build (Recommended for Performance)

```bash
swift build -c release
```

Output: `.build/release/search-cli`

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter testBasicSearch
```

### Performance Testing

```bash
# Basic performance test
.build/release/search-cli /path/to/large/file.txt "pattern" --verbose

# Regression test against reference implementation
time .build/release/search-cli /Users/sach/Downloads/T2TP.txt "GATTACA" --quiet
```

## Code Architecture

### SearchEngine.swift

The core engine follows a simple lifecycle:

1. **Initialization**: Setup Metal device, command queue, and compute pipeline
2. **File Mapping**: Map file into memory using zero-copy mmap
3. **Search Execution**: Execute GPU compute shader with optimal threadgroup configuration
4. **Result Extraction**: Collect match count and positions from GPU memory
5. **Cleanup**: Automatic resource management via RAII

### Key Design Patterns

#### Error Handling
```swift
// Proper error propagation (no forced unwrapping)
guard let buffer = device.makeBuffer(...) else {
    throw SearchEngineError.failedToCreateBuffer("buffer type")
}
```

#### Resource Management
```swift
// RAII pattern for automatic cleanup
deinit {
    try? unmapFile()
}
```

#### Performance Optimization
```swift
// Hardware-aligned threadgroup sizing
let threadWidth = pipeline.threadExecutionWidth
let desiredGroupWidth = (threadWidth > 0 && maxGroup >= threadWidth) 
    ? (maxGroup / threadWidth) * threadWidth 
    : 64
```

## Performance Optimization

### Critical Performance Paths

1. **Memory Mapping**: Zero-copy file access via `mmap()`
2. **GPU Buffer Creation**: Optimal storage mode selection
3. **Threadgroup Configuration**: Hardware-aligned dispatch
4. **Result Extraction**: Efficient array creation from GPU memory

### Benchmarking

```swift
// Performance measurement template
let startTime = CFAbsoluteTimeGetCurrent()
let result = try engine.search(pattern: pattern)
let endTime = CFAbsoluteTimeGetCurrent()

let executionTime = endTime - startTime
let throughputMBps = Double(fileSize) / (executionTime * 1024 * 1024)
```

### Performance Targets

- **Throughput**: 7+ GB/s on Apple M2 Pro
- **Latency**: <5ms initialization, <1ms file mapping
- **Memory**: <1% overhead vs file size
- **Accuracy**: 100% match agreement with reference implementations

## Testing Strategy

### Unit Tests

The test suite covers:

1. **Basic Search**: Standard pattern matching
2. **Single Character**: Optimized fast path
3. **Overlapping Matches**: Correct handling of overlapping patterns
4. **Edge Cases**: Empty files, empty patterns, error conditions

### Test Data Generation

```swift
private func createTempFile(content: String) -> URL {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try! content.write(to: tempFile, atomically: true, encoding: .utf8)
    return tempFile
}
```

### Performance Regression Tests

```bash
# Run with 3.1 GB DNA file
echo "Expected: 7+ GB/s throughput"
.build/release/search-cli /Users/sach/Downloads/T2TP.txt "GATTACA" --verbose

# Cross-validate accuracy
V3_COUNT=$(.build/release/search-cli /Users/sach/Downloads/T2TP.txt "GATTACA" --quiet)
REFERENCE_COUNT=$(reference_tool /Users/sach/Downloads/T2TP.txt "GATTACA")
[ "$V3_COUNT" -eq "$REFERENCE_COUNT" ] && echo "✅ Accuracy verified"
```

## Debugging

### Common Issues

#### Metal Device Not Found
```swift
// Check Metal availability
guard let device = MTLCreateSystemDefaultDevice() else {
    print("Metal device not available")
    return
}
print("Using GPU: \(device.name)")
```

#### Memory Mapping Failures
```swift
// Debug file access
let fileManager = FileManager.default
print("File exists: \(fileManager.fileExists(atPath: path))")
print("File readable: \(fileManager.isReadableFile(atPath: path))")
```

#### GPU Execution Issues
```swift
// Check command buffer status
cmdBuffer.waitUntilCompleted()
if cmdBuffer.status != .completed {
    print("GPU execution failed: \(cmdBuffer.error?.localizedDescription ?? "Unknown")")
}
```

### Profiling

#### Metal Performance
```bash
# Profile GPU usage
xcrun xctrace record --template "Metal System Profiler" --launch -- .build/release/search-cli file.txt "pattern"
```

#### Memory Usage
```bash
# Monitor memory consumption
sudo memory_pressure -p .build/release/search-cli -a file.txt "pattern"
```

## Extension Points

### Adding New Features

#### Custom Pattern Types
```swift
// Extend SearchEngine with new pattern types
extension SearchEngine {
    public func searchRegex(pattern: String) throws -> SearchResult {
        // Implementation using modified Metal shader
    }
}
```

#### Performance Metrics
```swift
// Add detailed performance tracking
public struct DetailedSearchResult {
    public let result: SearchResult
    public let gpuTime: TimeInterval
    public let memoryUsage: Int64
    public let threadgroupSize: Int
}
```

### Metal Shader Modifications

#### Adding New Optimizations
```metal
// Example: Case-insensitive search
kernel void searchCaseInsensitiveKernel(
    device const uchar* text        [[ buffer(0) ]],
    device const uchar* pattern     [[ buffer(1) ]],
    // ... other parameters
) {
    // Convert to lowercase for comparison
    uchar textChar = text[gid + i];
    uchar patternChar = pattern[i];
    
    // Simple ASCII case conversion
    if (textChar >= 'A' && textChar <= 'Z') {
        textChar += 32;
    }
    if (patternChar >= 'A' && patternChar <= 'Z') {
        patternChar += 32;
    }
    
    if (textChar != patternChar) {
        // No match
    }
}
```

## Contributing Guidelines

### Code Style

1. **Swift Style**: Follow Swift API Design Guidelines
2. **Error Handling**: No forced unwrapping (`!`)
3. **Memory Management**: Use RAII patterns
4. **Performance**: Measure before optimizing
5. **Comments**: Document complex algorithms only

### Testing Requirements

1. **Unit Tests**: All public APIs must have tests
2. **Performance Tests**: No regression in throughput
3. **Accuracy Tests**: 100% match agreement required
4. **Edge Cases**: Handle empty files, invalid patterns

### Review Process

1. **Code Review**: All changes require review
2. **Performance Review**: Benchmark critical paths
3. **Documentation**: Update guides for API changes
4. **Testing**: Verify all tests pass

## Deployment

### Distribution

```bash
# Create universal binary
swift build -c release --arch arm64 --arch x86_64

# Package for distribution
tar -czf gpu-text-search-v3.tar.gz .build/release/search-cli
```

### Installation

```bash
# Install locally
cp .build/release/search-cli /usr/local/bin/

# Or via Swift Package Manager
.package(url: "https://github.com/teenu/gpu-text-search.git", from: "3.0.0")
```

## Troubleshooting

### Build Issues

**"No such module 'Metal'"**
- Ensure building on macOS with Metal support
- Check Xcode Command Line Tools installed

**"Missing SearchKernel.metal"**
- Verify Metal file is in Sources/SearchEngine/
- Check Package.swift includes `.process("SearchKernel.metal")`

### Runtime Issues

**"No Metal GPU found"**
- Check hardware compatibility
- Verify macOS version (13+ required)

**"Memory mapping failed"**
- Check file permissions
- Verify sufficient memory available

### Performance Issues

**"Slow search performance"**
- Use release build (`-c release`)
- Check GPU is being utilized (Activity Monitor)
- Profile with Instruments

## Advanced Topics

### Custom Buffer Management

```swift
// Pre-allocate persistent buffers for multiple searches
class PersistentSearchEngine: SearchEngine {
    private var persistentPositionsBuffer: MTLBuffer?
    
    override func prepareBuffers() throws {
        // Reuse buffers across searches
    }
}
```

### Async/Await Support

```swift
// Future enhancement: async search
extension SearchEngine {
    public func searchAsync(pattern: String) async throws -> SearchResult {
        return try await withCheckedThrowingContinuation { continuation in
            // Implement async GPU execution
        }
    }
}
```

### Multi-Pattern Search

```swift
// Search multiple patterns simultaneously
public func searchMultiple(patterns: [String]) throws -> [SearchResult] {
    // Batch GPU execution for efficiency
}
```

## Resources

- **Metal Programming Guide**: Apple's official Metal documentation
- **Swift Performance**: Swift.org performance guidelines
- **GPU Computing**: Understanding parallel processing concepts
- **Memory Management**: Advanced memory optimization techniques

## Support

For development questions and issues:
1. Check existing documentation
2. Review test cases for examples
3. Profile performance issues
4. Create minimal reproduction cases

Remember: The V3 Foundation prioritizes performance and simplicity. Keep changes minimal and well-tested.