# Contributing to GPU Text Search

Thank you for your interest in contributing to GPU Text Search! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites
- **macOS 13.0+** with Metal GPU support
- **Xcode 15.0+** 
- **Swift 6.1+**
- **Apple Silicon or Intel Mac** (Apple Silicon recommended for optimal performance)

### Setting Up Development Environment

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/gpu-text-search.git
   cd gpu-text-search
   ```

2. **Build the project:**
   ```bash
   swift build -c release
   ```

3. **Run tests:**
   ```bash
   swift test
   ```

4. **Verify installation:**
   ```bash
   ./.build/release/search-cli --help
   ```

## 🛠️ Development Guidelines

### Code Style
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and concise

### Performance Standards
GPU Text Search is a high-performance library. All contributions must maintain or improve performance:

- **Benchmark your changes** against the baseline
- **Target 30+ GB/s throughput** on Apple Silicon
- **Optimize for GPU memory access patterns**
- **Minimize CPU overhead** in the critical path

### Testing Requirements
All contributions must include appropriate tests:

```bash
# Run the full test suite
swift test

# Run performance benchmarks
./.build/release/search-cli benchmark test_file.txt "pattern" --iterations 100

# Validate against reference implementations
python3 Tests/validate_results.py
```

## 📝 Contribution Types

### 🐛 Bug Fixes
1. **Create an issue** describing the bug with reproduction steps
2. **Write a failing test** that demonstrates the bug
3. **Implement the fix** while maintaining performance
4. **Verify the test passes** and performance is maintained

### ✨ New Features
1. **Open a feature request issue** to discuss the proposal
2. **Design the API** following Swift conventions
3. **Implement with comprehensive tests**
4. **Update documentation** and examples
5. **Benchmark performance impact**

### 🔧 Performance Improvements
1. **Establish baseline benchmarks** before changes
2. **Profile the current implementation** to identify bottlenecks
3. **Implement optimizations** with measurable improvements
4. **Provide before/after benchmark results**
5. **Ensure correctness** with comprehensive testing

### 📚 Documentation Improvements
- Update README.md for user-facing changes
- Add inline documentation for new APIs
- Include usage examples
- Update CLI help text if applicable

## 🧪 Testing Strategy

### Unit Tests
Located in `Tests/SearchEngineTests/`:
- Test core functionality
- Validate edge cases
- Ensure error handling
- Verify API contracts

### Performance Tests
```bash
# Benchmark against known datasets
./.build/release/search-cli benchmark large_file.txt "pattern" --iterations 50

# Profile memory usage
instruments -t "Metal System Trace" ./.build/release/search-cli search file.txt "pattern"

# Validate throughput targets
python3 Tests/performance_regression.py
```

### Integration Tests
- Test CLI interface
- Validate binary export/import
- Cross-platform compatibility
- Real-world use case scenarios

## 🚀 Performance Optimization Guide

### Metal GPU Programming
- **Optimize memory access patterns** for GPU coalescing
- **Minimize divergent branches** in compute kernels
- **Use appropriate atomic operations** for thread safety
- **Consider threadgroup synchronization** costs

### Memory Management
- **Prefer zero-copy operations** via memory mapping
- **Optimize buffer allocations** for Metal resource sharing
- **Minimize CPU-GPU data transfers**
- **Use appropriate storage modes** (.shared, .private, .memoryless)

### Algorithm Considerations
- **Parallel-friendly algorithms** that scale with GPU cores
- **Avoid sequential dependencies** in critical loops
- **Balance computation vs memory bandwidth**
- **Consider early termination strategies**

## 🔍 Code Review Process

### Pull Request Requirements
- [ ] **Clear description** of changes and motivation
- [ ] **Performance benchmarks** for performance-related changes  
- [ ] **Comprehensive tests** with good coverage
- [ ] **Documentation updates** for user-facing changes
- [ ] **No breaking changes** without major version bump

### Review Criteria
1. **Correctness**: Does the code work as intended?
2. **Performance**: Does it meet throughput requirements?
3. **Maintainability**: Is the code clear and well-structured?
4. **Testing**: Are edge cases and error conditions covered?
5. **Documentation**: Are changes properly documented?

## 📊 Benchmarking Standards

### Required Benchmarks
For performance-related changes, provide:

```bash
# Baseline measurement
gpu-text-search benchmark baseline_file.txt "pattern" --iterations 100

# Your changes measurement  
gpu-text-search benchmark baseline_file.txt "pattern" --iterations 100

# Report format:
# Baseline: XX.X GB/s (±X.X GB/s std dev)
# Modified: XX.X GB/s (±X.X GB/s std dev)  
# Change: +/-X.X% improvement/regression
```

### Test Datasets
Use these standard datasets for consistent benchmarking:
- **Small**: 10MB text file (quick validation)
- **Medium**: 100MB document corpus (typical use case)
- **Large**: 1GB+ dataset (stress testing)
- **Genomics**: FASTA files for bioinformatics validation

## 🐛 Bug Report Guidelines

When reporting bugs, please include:

1. **Exact command used** and expected vs actual output
2. **System information**: macOS version, hardware, GPU Text Search version
3. **Test file characteristics**: size, type, pattern density
4. **Performance data** if relevant (throughput, timing)
5. **Minimal reproduction case** if possible

## 💡 Feature Request Guidelines

For feature requests, consider:

1. **Use case justification**: What problem does this solve?
2. **Performance impact**: How might this affect throughput?
3. **API design**: How should this integrate with existing interfaces?
4. **Implementation complexity**: Is this feasible within the architecture?

## 🏗️ Architecture Overview

Understanding the codebase structure:

```
Sources/
├── SearchEngine/           # Core library
│   ├── SearchEngine.swift     # Main API interface
│   ├── MetalResourceManager.swift  # GPU resource management
│   ├── FileMapper.swift       # Memory-mapped file access
│   ├── PatternCache.swift     # Pattern buffer caching
│   ├── BenchmarkEngine.swift  # Performance measurement
│   └── SearchKernel.metal    # GPU compute shader
└── SearchCLI/              # Command-line interface
    └── main.swift             # CLI implementation
```

### Key Components
- **SearchEngine**: High-level API for text search operations
- **MetalResourceManager**: Manages GPU devices, buffers, and compute pipelines
- **FileMapper**: Zero-copy file access via memory mapping
- **PatternCache**: Optimizes repeated pattern searches
- **SearchKernel.metal**: GPU compute shader for parallel pattern matching

## 📞 Getting Help

- **GitHub Discussions**: Ask questions and share ideas
- **Issues**: Report bugs or request features
- **Code Review**: Get feedback on your contributions

## 📄 License

By contributing to GPU Text Search, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for helping make GPU Text Search faster and better! 🚀**