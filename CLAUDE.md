# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GPU Text Search is a high-performance text search engine that leverages Apple's Metal GPU compute shaders to achieve 32.3 GB/s throughput (~150x faster than grep). This is a production-ready Swift project targeting macOS 13+, iOS 16+, and macCatalyst 16+.

## Essential Commands

### Build & Test
```bash
# Debug build
swift build

# Release build (recommended for performance testing)
swift build -c release

# Run tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Quick validation test
./quick_test.sh

# Comprehensive validation against grep
python3 Validation/comprehensive_test.py
```

### Install CLI Globally
```bash
swift build -c release
cp .build/release/search-cli /usr/local/bin/
```

### Usage Examples
```bash
# Basic search
search-cli search file.txt "pattern"

# Verbose with performance metrics
search-cli search file.txt "pattern" --verbose

# Benchmark performance
search-cli benchmark file.txt "pattern" --iterations 100

# Profile multiple patterns
search-cli profile file.txt --verbose

# Export match positions to binary
search-cli search file.txt "pattern" --export-binary positions.bin
```

## Core Architecture

### Key Components
- **`Sources/SearchEngine/SearchEngine.swift`** (667 lines): Main GPU-accelerated search engine
  - File memory mapping with `mmap` for zero-copy access
  - Metal device and pipeline management
  - Binary archive caching for Pipeline State Objects (eliminates 16x cold start penalty)
  - Persistent buffer pools with LRU pattern caching (32 patterns)

- **`Sources/SearchEngine/SearchKernel.metal`** (59 lines): Metal compute shader
  - First/last character pre-check optimization (90% reduction in comparisons)
  - Single-character fast path
  - Atomic operations for thread-safe result collection

- **`Sources/SearchCLI/main.swift`** (356 lines): CLI interface with subcommands
  - `search`: Basic pattern searching with options
  - `benchmark`: Statistical performance analysis
  - `profile`: Multi-pattern performance profiling

### Performance Optimizations
- **Zero-copy memory**: Files are mapped with `mmap`, Metal buffers reference mapped memory directly
- **GPU parallelization**: Every byte position processed in parallel using Metal compute shaders
- **Hardware optimization**: Threadgroup sizing based on GPU capabilities (`threadExecutionWidth`, `maxTotalThreadsPerThreadgroup`)
- **Memory coalescing**: Optimized GPU memory access patterns
- **Pipeline caching**: Metal Binary Archives prevent shader recompilation

## Development Workflow

### Code Style
- Uses Swift 6.1.2 with strict concurrency enabled
- Advanced Swift features enabled: `BareSlashRegexLiterals`, `ConciseMagicFile`, `ForwardTrailingClosures`, `StrictConcurrency`
- Metal shader code in `SearchKernel.metal`

### Testing Strategy
- **Unit tests**: `Tests/SearchEngineTests.swift` covers core functionality and edge cases
- **Validation scripts**: Python scripts in `Validation/` for cross-validation against grep
- **Quick test**: `./quick_test.sh` runs basic functionality tests
- **Comprehensive test**: `python3 Validation/comprehensive_test.py` validates accuracy against grep

### Performance Requirements
- Target: 32+ GB/s throughput on Apple Silicon
- Benchmark against established tools (ripgrep, GNU grep)
- Statistical analysis with variance reporting
- Cold start optimization critical (16x improvement achieved)

## Technical Constraints

### Platform Requirements
- **macOS 13+** / **iOS 16+** / **macCatalyst 16+**
- **Metal-capable GPU** (Apple Silicon recommended for peak performance)
- **Swift 5.9+** (currently using Swift 6.1.2)

### Memory Considerations
- Large files handled via memory mapping (no size limits beyond available virtual memory)
- GPU memory usage optimized through buffer reuse and pattern caching
- Atomic operations use relaxed memory ordering for performance

### Dependencies
- **swift-argument-parser**: CLI framework (minimal dependency footprint)
- **Metal framework**: GPU compute operations
- **Foundation & System**: Core Swift functionality

## Key Files to Understand

1. **`SearchEngine.swift`**: Core engine with GPU optimization techniques
2. **`SearchKernel.metal`**: Metal compute shader with algorithmic optimizations
3. **`main.swift`**: CLI interface and subcommand handling
4. **`Package.swift`**: Project configuration with Swift 6 features enabled
5. **`Validation/`**: Python scripts for accuracy and performance validation

## Performance Benchmarking

Always validate performance changes:
- Use release builds for accurate measurements
- Run statistical benchmarks with multiple iterations
- Compare against baseline performance (32.3 GB/s on M2 Pro)
- Validate accuracy against grep using validation scripts

## Binary Export Format

Match positions exported as little-endian UInt32 arrays for downstream processing. Use `Validation/validate_binary.py` to verify exported data.\n
