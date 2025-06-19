# CLAUDE.md

High-performance GPU-accelerated text search engine using Metal compute shaders. Production-ready Swift project targeting macOS 13+, iOS 16+, and macCatalyst 16+.

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

- **SearchEngine.swift**: Main GPU engine with Metal pipeline management and binary archive caching
- **SearchKernel.metal**: Metal compute shader with first/last character optimization
- **main.swift**: CLI with search/benchmark/profile commands

## Performance Requirements

Target: 32+ GB/s throughput on Apple Silicon. Always use release builds for benchmarking and cross-validate accuracy against grep using validation scripts.\n
