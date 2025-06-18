# Homebrew Formula for GPU Text Search

This directory contains the Homebrew formula for installing GPU Text Search v1.0.0.

## 🚀 Quick Installation

### Option 1: Direct Formula Install (Recommended)
```bash
brew install https://raw.githubusercontent.com/teenu/gpu-text-search/main/homebrew/gpu-text-search.rb
```

### Option 2: Via Homebrew Tap (Coming Soon)
```bash
# Add this repository as a tap
brew tap teenu/gpu-text-search

# Install the formula
brew install gpu-text-search
```

### Option 3: From Homebrew Core (Future)
```bash
# Will be available once submitted to Homebrew Core
brew install gpu-text-search
```

## Usage After Installation

```bash
# Basic usage - the binary is installed as 'gpu-text-search'
gpu-text-search file.txt "pattern"

# Search for GATTACA sequences (bioinformatics)
gpu-text-search genome.fasta "GATTACA" --verbose

# High-performance benchmark (32+ GB/s throughput on large files)
gpu-text-search largefile.txt "pattern" --benchmark --iterations 50

# Export match positions for downstream analysis
gpu-text-search dna_sequence.txt "ATCG" --export-binary positions.bin

# Get help and see all options
gpu-text-search --help

# Run validation test with included test file
gpu-text-search "$(brew --prefix)/share/gpu-text-search/test_file.txt" "Hello" --verbose
```

## 🧬 Bioinformatics Examples

```bash
# DNA sequence analysis (what GPU Text Search excels at)
gpu-text-search genome.fasta "GATTACA" --verbose
gpu-text-search sequence.txt "TATA" --export-binary tata_positions.bin

# Performance comparison with traditional tools
time gpu-text-search large_genome.fasta "ATCG" --quiet
time grep -c "ATCG" large_genome.fasta  # Compare speed

# Profile multiple DNA patterns
gpu-text-search genome.fasta --profile --patterns "GATTACA,ATCG,GCTA" --verbose
```

## 🏆 Performance Highlights

**Validated on 2.9GB DNA Sequence File:**
- **733,756 GATTACA sequences** found in **0.3969 seconds**
- **Peak throughput: 32,564.52 MB/s** (32+ GB/s)
- **150x faster** than traditional grep on large files
- **100% accuracy** validated against grep

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+** (for building from source)
- **Metal-capable GPU** (all modern Macs, optimized for Apple Silicon)

## Updating

```bash
# Update to latest version
brew upgrade gpu-text-search

# Or update from tap
brew upgrade teenu/gpu-text-search/gpu-text-search
```

## Uninstalling

```bash
brew uninstall gpu-text-search

# If installed from tap, also remove the tap
brew untap teenu/gpu-text-search
```

## Formula Maintenance

The formula automatically:
- Downloads the latest source code
- Builds the optimized release binary
- Installs documentation and examples
- Runs comprehensive tests during installation
- Handles dependencies (Xcode, macOS version)

## Troubleshooting

### Build Issues
```bash
# Check Xcode installation
xcode-select --print-path

# Check macOS version
sw_vers -productVersion

# Reinstall with verbose output
brew install --verbose gpu-text-search
```

### Performance Issues
```bash
# Check Metal GPU support
system_profiler SPDisplaysDataType | grep Metal

# Run benchmark test
gpu-text-search "$(brew --prefix)/share/gpu-text-search/test_file.txt" "test" --benchmark --iterations 10
```\n
