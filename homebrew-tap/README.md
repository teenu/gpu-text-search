# GPU Text Search Homebrew Tap

Official Homebrew tap for GPU Text Search - ultra-high-performance GPU-accelerated text search using Metal compute shaders.

## 🚀 Quick Installation

```bash
# Add the tap
brew tap teenu/gpu-text-search

# Install GPU Text Search
brew install gpu-text-search
```

## Usage

```bash
# Basic search
gpu-text-search file.txt "pattern"

# DNA sequence analysis (bioinformatics)
gpu-text-search genome.fasta "GATTACA" --verbose

# Performance benchmark
gpu-text-search largefile.txt "pattern" --benchmark --iterations 50

# Export match positions for downstream analysis
gpu-text-search sequence.txt "ATCG" --export-binary positions.bin
```

## 🧬 Bioinformatics Examples

```bash
# Search for GATTACA sequences in genome data
gpu-text-search genome.fasta "GATTACA" --verbose

# Profile multiple DNA patterns
gpu-text-search dna_data.txt --profile --patterns "ATCG,GCTA,TAGA" --verbose

# Export positions for downstream analysis
gpu-text-search sequences.fasta "TATABOX" --export-binary tata_positions.bin
```

## 🏆 Performance

- **32+ GB/s throughput** on Apple Silicon
- **150x faster than grep** on large files
- **733,756 GATTACA sequences** found in 2.9GB file in 0.39 seconds
- **100% accuracy** validated against grep

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+** (for building from source)
- **Metal-capable GPU** (all modern Macs, optimized for Apple Silicon)

## Alternative Installation Methods

### Via GitHub Release
```bash
brew install https://raw.githubusercontent.com/teenu/gpu-text-search/main/homebrew/gpu-text-search.rb
```

### From Source
```bash
git clone https://github.com/teenu/gpu-text-search.git
cd gpu-text-search
swift build -c release
cp .build/release/search-cli /usr/local/bin/gpu-text-search
```

## Support

- **Documentation**: [GitHub Repository](https://github.com/teenu/gpu-text-search)
- **Issues**: [Report Issues](https://github.com/teenu/gpu-text-search/issues)
- **License**: MIT

---

**Built with ❤️ for high-performance text processing and bioinformatics workflows**