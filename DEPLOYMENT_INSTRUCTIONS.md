# GPU Text Search - Gilded Edition
## Sister Machine Deployment Guide

> **Note**: This guide focuses on configuration specific to a secondary
> deployment machine. For basic setup and a full quick start guide, see
> `DEPLOYMENT_GUIDE.md` in the repository root.

### 📋 System Requirements

#### **Minimum Requirements**
- **OS**: macOS 13.0+ (Ventura or later)
- **Hardware**: Any Mac with Metal GPU support
- **RAM**: 4GB minimum, 8GB recommended for large files
- **Storage**: 50MB for installation

#### **Optimal Performance Requirements**
- **Hardware**: Apple Silicon (M1/M2/M3 series) for peak 30+ GB/s performance
- **OS**: macOS 14.0+ (Sonoma) for latest Metal optimizations
- **RAM**: 16GB+ for very large file processing (>10GB files)

### 🚀 Performance Expectations

#### **Apple Silicon (M1/M2/M3)**
- **Peak Throughput**: 30-35 GB/s
- **Cold Start**: ~0.1 seconds
- **Large Files (3GB)**: ~733k matches in 0.099 seconds
- **Memory Usage**: Efficient, leverages unified memory

#### **Intel Macs**
- **Peak Throughput**: 15-25 GB/s (depends on GPU)
- **Cold Start**: ~0.2 seconds  
- **Performance**: Still excellent, 50-100x faster than grep

### 📦 Package Contents

```
gpu-text-search-gilded/
├── search-cli              # Pre-built optimized binary
├── install.sh              # Automated installation script
├── test_file.txt           # Sample test file
├── unicode_test.txt        # Unicode validation file
├── quick_test.sh           # Validation test script
├── VERSION.txt             # Version and optimization details
├── CHANGELOG.md            # Complete optimization history
├── DEPLOYMENT_GUIDE.md     # Original deployment guide
└── README.md               # Comprehensive documentation
```

### 🔧 Installation Options

#### **Option 1: System-wide Installation (Recommended)**
```bash
./install.sh
# Choose option 1 when prompted
# Installs to /usr/local/bin (requires sudo)
# Accessible from anywhere as 'search-cli'
```

#### **Option 2: Local Installation**
```bash
./install.sh
# Choose option 2 when prompted  
# Installs to current directory
# Use with full path: ./search-cli
```

#### **Option 3: Custom Location**
```bash
./install.sh
# Choose option 3 when prompted
# Specify custom directory
```

### ⚡ Usage Examples

#### **Basic Text Search**
```bash
# Simple search
search-cli search document.txt "search term"

# Verbose output with performance metrics
search-cli search document.txt "pattern" --verbose

# Quiet output (just match count)
search-cli search document.txt "pattern" --quiet
```

#### **High-Performance Search**
```bash
# Warmup GPU for guaranteed peak performance (large files)
search-cli search large_file.txt "pattern" --warmup --verbose

# Export match positions for further analysis
search-cli search file.txt "pattern" --export-binary positions.bin
```

#### **Performance Benchmarking**
```bash
# Quick benchmark (10 iterations)
search-cli benchmark test_file.txt "Hello" --iterations 10

# Comprehensive benchmark with statistics
search-cli benchmark large_file.txt "pattern" --iterations 100 --verbose

# CSV output for analysis
search-cli benchmark file.txt "pattern" --csv > results.csv
```

#### **Pattern Profiling**
```bash
# Test multiple patterns
search-cli profile test_file.txt --verbose

# Custom patterns
search-cli profile file.txt --patterns "word1,word2,phrase3"
```

### 🧪 Validation & Testing

#### **Quick Validation**
```bash
# Run included test script
./quick_test.sh

# Expected output:
# ✅ Basic search: Found 3 matches (expected: 3)
# ✅ Unicode search: Found 2 matches (expected: 2)  
# ✅ No matches: Found 0 matches (expected: 0)
```

#### **Performance Validation**
```bash
# Test with included sample
search-cli benchmark test_file.txt "the" --iterations 10 --verbose

# Expected performance:
# Apple Silicon: >1000 MB/s on small files
# Intel Macs: >500 MB/s on small files
```

#### **Large File Testing** (if available)
```bash
# Test with your own large files
search-cli search large_file.txt "pattern" --warmup --verbose

# Expected for 1GB+ files:
# Apple Silicon: 25-35 GB/s
# Intel Macs: 10-25 GB/s
```

### 🔍 Troubleshooting

#### **Common Issues**

**Issue**: "No suitable Metal GPU found"
- **Solution**: Your Mac doesn't support Metal. Tool will not work.
- **Check**: Run `system_profiler SPDisplaysDataType | grep Metal`

**Issue**: "Failed to create Metal library"  
- **Solution**: Restart the application. Rare Metal driver issue.

**Issue**: Poor performance on first run
- **Solution**: Use `--warmup` flag for large files
- **Explanation**: First run may involve shader compilation

**Issue**: "Permission denied"
- **Solution**: Make sure binary is executable: `chmod +x search-cli`

#### **Performance Issues**

**Low throughput (<1 GB/s)**:
- Check available RAM (Activity Monitor)
- Close other GPU-intensive applications
- Try smaller test files first

**Inconsistent performance**:
- Use `--warmup` flag for consistent results
- Check thermal throttling (especially laptops)

### 🎯 Advanced Usage

#### **Integration with Other Tools**
```bash
# Count occurrences
MATCHES=$(search-cli search file.txt "pattern" --quiet)
echo "Found $MATCHES matches"

# Pipeline with other commands
search-cli search *.txt "error" --quiet | sort -n
```

#### **Scripting Examples**
```bash
#!/bin/bash
# Batch search across multiple files
for file in *.log; do
    count=$(search-cli search "$file" "ERROR" --quiet)
    echo "$file: $count errors"
done
```

#### **Performance Monitoring**
```bash
# Monitor performance over time
search-cli benchmark large_file.txt "pattern" --csv | \
  awk -F, '{print $2}' | \
  awk '{sum+=$1; count++} END {print "Average:", sum/count, "seconds"}'
```

### 📊 Expected Performance Benchmarks

#### **Small Files (<100MB)**
- **Apple Silicon**: 1-5 GB/s (limited by file size overhead)
- **Intel**: 0.5-2 GB/s
- **Latency**: <10ms

#### **Medium Files (100MB-1GB)**  
- **Apple Silicon**: 10-25 GB/s
- **Intel**: 5-15 GB/s
- **Latency**: 10-100ms

#### **Large Files (1GB+)**
- **Apple Silicon**: 25-35 GB/s
- **Intel**: 10-25 GB/s  
- **Latency**: 100ms-1s

### 🆘 Support

#### **Self-Help**
1. Check `search-cli --help` for complete documentation
2. Review `CHANGELOG.md` for optimization details
3. Run `./quick_test.sh` to verify installation

#### **Performance Verification**
```bash
# System information
search-cli search test_file.txt "Hello" --verbose
# Look for "GPU: [Your GPU Name]" in output

# Compare with grep
time grep -c "Hello" test_file.txt
time search-cli search test_file.txt "Hello" --quiet
```

### 🏆 Success Criteria

Your deployment is successful when:
- ✅ Installation completes without errors
- ✅ Quick test shows expected match counts
- ✅ Performance is significantly faster than grep
- ✅ Verbose output shows your GPU information
- ✅ Large file searches complete in reasonable time

---

**🚀 Enjoy the blazing-fast performance of GPU Text Search - Gilded Edition!**\n
