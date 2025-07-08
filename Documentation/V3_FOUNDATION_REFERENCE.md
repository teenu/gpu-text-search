# V3 Foundation Reference Documentation

## Overview

The V3 Foundation is an ultra-lean, high-performance GPU-accelerated text search engine built with Metal compute shaders. It provides 7+ GB/s throughput on Apple Silicon while maintaining a minimal 453-line codebase.

## Architecture

### Core Components

```
V3 Foundation (453 lines total)
├── SearchEngine.swift (256 lines) - Core GPU engine
├── main.swift (46 lines) - CLI interface
├── Package.swift (19 lines) - Package definition
├── SearchEngineTests.swift (67 lines) - Test suite
└── SearchKernel.metal (81 lines) - GPU compute shader
```

### Design Principles

1. **Ultra-Lean**: Minimal code with maximum performance
2. **Single Responsibility**: Each component has one clear purpose
3. **Error Safety**: Comprehensive error handling without forced unwrapping
4. **GPU-First**: Optimized for Metal compute shader execution
5. **Memory Efficient**: Zero-copy file mapping and optimized buffers

## API Reference

### SearchEngine Class

#### Initialization

```swift
public init() throws
```

Creates a new SearchEngine instance with Metal GPU support.

**Throws:**
- `SearchEngineError.noMetalDevice` - No Metal-capable GPU found
- `SearchEngineError.failedToCreateCommandQueue` - Command queue creation failed
- `SearchEngineError.failedToCreateLibrary` - Metal library creation failed
- `SearchEngineError.failedToCreatePipeline` - Compute pipeline creation failed

#### File Management

```swift
public func mapFile(at url: URL) throws
```

Maps a file into memory using zero-copy mmap for optimal performance.

**Parameters:**
- `url`: File URL to map into memory

**Throws:**
- `SearchEngineError.failedToOpenFile` - File cannot be opened
- `SearchEngineError.failedToGetFileStats` - File statistics unavailable
- `SearchEngineError.memoryMappingFailed` - Memory mapping failed

```swift
public func unmapFile() throws
```

Unmaps the currently mapped file and releases memory.

**Throws:**
- `SearchEngineError.unmappingFailed` - Memory unmapping failed

#### Search Operations

```swift
public func search(pattern: String) throws -> SearchResult
```

Performs GPU-accelerated pattern search on the mapped file.

**Parameters:**
- `pattern`: UTF-8 text pattern to search for

**Returns:** `SearchResult` containing match information

**Throws:**
- `SearchEngineError.noFileMapped` - No file currently mapped
- `SearchEngineError.invalidPattern` - Pattern is empty or invalid
- `SearchEngineError.failedToCreateBuffer` - GPU buffer creation failed
- `SearchEngineError.failedToCreateCommandBuffer` - Command buffer creation failed
- `SearchEngineError.gpuExecutionFailed` - GPU execution failed

### SearchResult Structure

```swift
public struct SearchResult {
    public let matchCount: UInt32       // Total matches found
    public let positions: [UInt32]      // Match positions (up to 10M)
    public let executionTime: TimeInterval  // Search duration
    public let throughputMBps: Double   // Performance in MB/s
    public let truncated: Bool          // Whether results were truncated
}
```

### Error Handling

```swift
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
}
```

## Performance Characteristics

### Throughput
- **Peak Performance**: 7.4+ GB/s on Apple M2 Pro
- **Average Performance**: 7.0+ GB/s sustained
- **File Size**: Optimized for multi-gigabyte files
- **Pattern Length**: All lengths supported (1-byte to file size)

### Memory Usage
- **File Mapping**: Zero-copy mmap (no memory duplication)
- **GPU Buffers**: ~40 MB for 10M match positions
- **Pattern Buffer**: Minimal (pattern length in bytes)
- **Overhead**: <1% of file size

### Latency
- **Cold Start**: <5ms initialization
- **Search Time**: 0.4s for 3.1 GB file (GATTACA pattern)
- **Memory Mapping**: <1ms for any file size

## Usage Examples

### Basic Search

```swift
import SearchEngine

let engine = try SearchEngine()
try engine.mapFile(at: URL(fileURLWithPath: "/path/to/file.txt"))
let result = try engine.search(pattern: "GATTACA")

print("Found \(result.matchCount) matches")
print("Throughput: \(result.throughputMBps) MB/s")
```

### Error Handling

```swift
do {
    let engine = try SearchEngine()
    try engine.mapFile(at: fileURL)
    let result = try engine.search(pattern: "pattern")
    // Process result
} catch SearchEngineError.noMetalDevice {
    print("Metal GPU not available")
} catch SearchEngineError.failedToOpenFile(let path) {
    print("Cannot open file: \(path)")
} catch {
    print("Search failed: \(error)")
}
```

### Performance Monitoring

```swift
let startTime = CFAbsoluteTimeGetCurrent()
let result = try engine.search(pattern: "DNA")
let endTime = CFAbsoluteTimeGetCurrent()

let totalTime = endTime - startTime
let throughputGBps = result.throughputMBps / 1024

print("Search completed in \(totalTime)s")
print("Throughput: \(throughputGBps) GB/s")
print("Found \(result.matchCount) matches")
```

## CLI Interface

### Basic Usage

```bash
search-cli file.txt "pattern"
```

### Options

- `--verbose, -v`: Show detailed output with timing and throughput
- `--quiet, -q`: Show only match count (script-friendly)

### Examples

```bash
# Basic search
search-cli genome.fasta "GATTACA"

# Verbose output
search-cli genome.fasta "GATTACA" --verbose

# Quiet output (count only)
search-cli genome.fasta "GATTACA" --quiet
```

## GPU Compute Shader

### SearchKernel.metal

The Metal compute shader implements optimized pattern matching with:

1. **Boundary Checking**: Ensures pattern fits within text
2. **Single-Character Fast Path**: Optimized for 1-byte patterns
3. **First/Last Character Pre-check**: Reduces full comparisons by ~90%
4. **Loop Unrolling**: Specialized paths for 2-8 character patterns
5. **Atomic Operations**: Thread-safe result collection
6. **Position Storage**: Efficient match position recording

### Threadgroup Configuration

```swift
private func calculateDispatchConfiguration(
    pipeline: MTLComputePipelineState,
    totalPositions: Int
) -> (threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize)
```

Calculates optimal threadgroup size based on:
- GPU thread execution width
- Maximum threads per threadgroup
- Hardware-specific alignment requirements

## Technical Details

### Memory Management

1. **File Mapping**: Uses `mmap()` for zero-copy file access
2. **GPU Buffers**: Allocated on-demand with optimal storage mode
3. **Pattern Buffer**: UTF-8 encoded pattern data
4. **Results Buffer**: Pre-allocated for 10M match positions
5. **Automatic Cleanup**: RAII-style resource management

### Storage Mode Selection

```swift
private let storageMode: MTLResourceOptions = 
    device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
```

Automatically selects optimal storage mode based on GPU architecture.

### Threading Model

- **Main Thread**: File I/O and API calls
- **GPU Threads**: Parallel pattern matching (one thread per text position)
- **Synchronization**: Command buffer completion ensures GPU work finished

## Limitations

1. **Platform**: macOS 13+ only (Metal requirement)
2. **GPU**: Metal-capable GPU required
3. **Pattern Size**: Limited to file size
4. **Match Positions**: Truncated at 10M matches (count remains accurate)
5. **Encoding**: UTF-8 patterns only

## Building

### Debug Build
```bash
swift build
```

### Release Build (Recommended)
```bash
swift build -c release
```

### Testing
```bash
swift test
```

## Thread Safety

The SearchEngine is **NOT thread-safe**. Use separate instances for concurrent searches or implement external synchronization.

## Best Practices

1. **File Mapping**: Map files once, search multiple patterns
2. **Error Handling**: Always wrap API calls in try-catch blocks
3. **Memory Management**: Let SearchEngine handle cleanup automatically
4. **Performance**: Use release builds for production workloads
5. **Patterns**: Pre-validate patterns before searching

## Troubleshooting

### Common Issues

**"No Metal GPU found"**
- Ensure running on Metal-capable hardware
- Check macOS version (13+ required)

**"Memory mapping failed"**
- Verify file exists and is readable
- Check available memory for large files

**"GPU execution failed"**
- Pattern may be too long for available GPU memory
- Try smaller patterns or files

### Performance Issues

**Slow search performance**
- Ensure using release build (`-c release`)
- Verify Metal GPU is being used
- Check file is properly mapped

**High memory usage**
- Large files use proportional memory
- Consider processing in chunks for very large files

## Version Information

- **V3 Foundation**: Ultra-lean 453-line implementation
- **Performance**: 7+ GB/s on Apple Silicon
- **Compatibility**: macOS 13+, Metal-capable GPUs
- **Last Updated**: July 2025