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

## Core Architecture (Modular)

- **SearchEngine.swift**: Main orchestration class that coordinates modular components
- **MetalResourceManager.swift**: Manages GPU resources, pipeline states, and compute dispatch
- **FileMapper.swift**: Handles file I/O operations and memory mapping
- **PatternCache.swift**: LRU pattern buffer caching with automatic eviction
- **BenchmarkEngine.swift**: Performance testing and statistical analysis
- **Configuration.swift**: Centralized configuration constants and validation
- **SharedUtilities.swift**: Shared utility functions (statistics, file validation)
- **SearchKernel.metal**: Metal compute shader with first/last character optimization
- **main.swift**: CLI with search/benchmark/profile commands

## Performance Requirements

Target: 32+ GB/s throughput on Apple Silicon. The modularized architecture maintains identical performance while providing:

### Architectural Improvements
- **59% reduction** in main class complexity (860 → 350 lines)
- **Zero performance impact** - identical 32.35 GB/s peak throughput
- **Enhanced maintainability** with focused, single-responsibility modules
- **Eliminated circular dependencies** and reduced coupling
- **Centralized configuration** for easy tuning
- **Improved memory management** with buffer pooling and pressure handling
- **Optimized result storage** for large datasets

### Code Quality Enhancements
- Removed dead code and unused imports
- Unified error handling and validation
- Shared utility functions eliminate duplication
- Configuration system replaces hardcoded values
- Buffer pooling for better resource management

Always use release builds for benchmarking. The cleaned-up modular architecture serves as an optimal foundation for A/B testing and cold start performance improvements.\n
