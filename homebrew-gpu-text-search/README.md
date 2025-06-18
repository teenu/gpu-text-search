# GPU Text Search Homebrew Tap

A Homebrew tap for [gpu-text-search](https://github.com/teenu/gpu-text-search) - an ultra-high-performance GPU-accelerated text search engine using Apple's Metal compute shaders.

## Features

- **32+ GB/s throughput** on Apple Silicon (150x faster than grep)
- **Zero-copy memory mapping** for large files
- **GPU parallelization** - every byte processed in parallel
- **Production-ready** with comprehensive test suite

## Installation

```bash
# Add the tap
brew tap teenu/gpu-text-search

# Install gpu-text-search
brew install gpu-text-search
```

Or install directly:

```bash
brew install teenu/gpu-text-search/gpu-text-search
```

## Usage

```bash
# Basic search
gpu-text-search file.txt "pattern"

# Verbose output with performance metrics
gpu-text-search file.txt "pattern" --verbose

# Benchmark performance
gpu-text-search benchmark file.txt "pattern" --iterations 100
```

## Requirements

- **macOS 13+** (Ventura) for Metal compute shader support
- **Apple Silicon recommended** for peak performance
- **Xcode 15.0+** for building from source

## Use Cases

- **Bioinformatics**: DNA/RNA sequence analysis in genomic datasets
- **Log analysis**: High-speed searching in massive log files  
- **Data mining**: Pattern detection in large text corpora
- **DevOps**: Fast code searching across large codebases

## Performance

Achieves 32+ GB/s throughput on Apple Silicon M-series processors, providing ~150x performance improvement over traditional grep for large file searches.

## Documentation

For detailed documentation, examples, and technical details, visit the main project repository:
https://github.com/teenu/gpu-text-search