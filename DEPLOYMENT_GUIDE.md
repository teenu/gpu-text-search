# GPU Text Search - Deployment Guide

**Complete setup instructions for testing the CLI tool on any compatible machine**

## 🎯 Quick Start (5 minutes)

```bash
# 1. Extract the archive
tar -xzf gpu-text-search-mastercopy.tar.gz
cd gpu-text-search-mastercopy

# 2. Build and test
swift build -c release
.build/release/search-cli --help

# 3. Run validation test
echo "Hello World! This is a test." > test.txt
.build/release/search-cli search test.txt "test" --verbose
```

## 📋 System Requirements

### ✅ **Minimum Requirements**
- **macOS**: 13.0+ (Ventura or later)
- **iOS**: 16.0+ (for iOS builds)
- **macCatalyst**: 16.0+ (for Mac Catalyst builds)
- **Xcode**: 15.0+ (for development)
- **Swift**: 5.9+ (included with Xcode)

### 🔧 **Hardware Requirements**
- **Metal-capable GPU**: Any Apple Silicon (M1/M2/M3) or Intel Mac with discrete GPU
- **Memory**: 4GB+ RAM (8GB+ recommended for large files)
- **Storage**: 100MB for build artifacts (source is ~50MB)

### ⚡ **Optimal Performance**
- **Apple Silicon**: M1/M2/M3 for best performance (32+ GB/s throughput)
- **Intel Mac**: Metal-capable GPU required (reduced performance expected)
- **Memory**: 16GB+ for processing multi-GB files efficiently

## 🚀 **Installation Methods**

### Method 1: Command Line (Recommended)

```bash
# Navigate to extracted directory
cd gpu-text-search-mastercopy

# Build release version
swift build -c release

# Optional: Install system-wide
sudo cp .build/release/search-cli /usr/local/bin/
```

### Method 2: Xcode Development

```bash
# Open Package.swift in Xcode
open Package.swift

# Select search-cli scheme
# Product → Build For → Running (⌘B)
# Product → Run (⌘R)
```

### Method 3: Swift Package Manager Integration

```swift
// Add to your Package.swift
dependencies: [
    .package(path: "./gpu-text-search-mastercopy")
]

// Use in your code
import SearchEngine
let engine = try SearchEngine()
```

## 🧪 **Validation Tests**

### Basic Functionality Test

```bash
# Create test file
echo "Hello World! The quick brown fox jumps. Hello again!" > validation.txt

# Test basic search
.build/release/search-cli search validation.txt "Hello" --verbose

# Expected output: 2 matches at positions 0 and 47
```

### Performance Validation

```bash
# Generate larger test file (1MB)
head -c 1000000 /dev/urandom | base64 > large_test.txt
echo "PATTERN_TO_FIND" >> large_test.txt

# Benchmark test
.build/release/search-cli benchmark large_test.txt "PATTERN" --iterations 10 --verbose

# Expected: Sub-second execution with throughput metrics
```

### Binary Export Test

```bash
# Test binary export functionality
.build/release/search-cli search validation.txt "Hello" --export-binary positions.bin --verbose

# Validate export
ls -la positions.bin
# Expected: 8 bytes (2 matches × 4 bytes per UInt32)

# Verify positions (optional)
python3 -c "
import struct
with open('positions.bin', 'rb') as f:
    while True:
        data = f.read(4)
        if not data: break
        print(struct.unpack('<I', data)[0])
"
```

## 🔍 **Troubleshooting**

### Build Issues

**Error: No Metal device found**
```bash
# Check Metal support
system_profiler SPDisplaysDataType | grep Metal
# Solution: Ensure Metal-capable GPU is present
```

**Error: Swift version incompatible**
```bash
# Check Swift version
swift --version
# Solution: Update Xcode to 15.0+ or install Swift 5.9+
```

**Error: Package dependencies failed**
```bash
# Clean and rebuild
swift package clean
swift package update
swift build -c release
```

### Runtime Issues

**Error: Failed to open file**
```bash
# Check file permissions
ls -la your_file.txt
# Solution: Ensure read permissions (chmod +r your_file.txt)
```

**Error: Memory mapping failed**
```bash
# Check available memory
vm_stat
# Solution: Close other applications or use smaller test files
```

**Performance slower than expected**
```bash
# Check GPU utilization
sudo powermetrics -s gpu_power -n 1
# Expected: GPU active during search operations
```

## 📊 **Performance Benchmarking**

### Standard Benchmark Suite

```bash
# Create benchmark script
cat > benchmark_suite.sh << 'EOF'
#!/bin/bash
echo "=== GPU Text Search Benchmark Suite ==="

# Test 1: Small file performance
echo "Test 1: Small file (1KB)"
head -c 1000 /dev/urandom | base64 > small.txt
echo "TESTPATTERN" >> small.txt
.build/release/search-cli benchmark small.txt "TEST" --iterations 100 --csv > small_results.csv
echo "Results saved to small_results.csv"

# Test 2: Medium file performance  
echo "Test 2: Medium file (1MB)"
head -c 1000000 /dev/urandom | base64 > medium.txt
echo "TESTPATTERN" >> medium.txt
.build/release/search-cli benchmark medium.txt "TEST" --iterations 10 --verbose

# Test 3: Pattern profiling
echo "Test 3: Pattern profiling"
.build/release/search-cli profile medium.txt --patterns "a,THE,PATTERN,NOTFOUND" --verbose

# Cleanup
rm -f small.txt medium.txt small_results.csv
echo "Benchmark suite complete!"
EOF

chmod +x benchmark_suite.sh
./benchmark_suite.sh
```

### Expected Performance Ranges

| Hardware | File Size | Expected Throughput |
|----------|-----------|-------------------|
| **M3 Max** | 1GB+ | 25-35 GB/s |
| **M2 Pro** | 1GB+ | 20-32 GB/s |
| **M1** | 1GB+ | 15-25 GB/s |
| **Intel + dGPU** | 1GB+ | 5-15 GB/s |
| **Intel iGPU** | 1GB+ | 1-5 GB/s |

## 🔧 **Advanced Configuration**

### Custom Build Options

```bash
# Debug build with symbols
swift build -c debug

# Optimized build with specific target
swift build -c release --arch arm64

# Build with verbose output
swift build -c release -v
```

### Memory Tuning

```bash
# For very large files (>10GB), increase virtual memory
sudo sysctl -w vm.max_map_count=262144

# Monitor memory usage during search
.build/release/search-cli search large_file.txt "pattern" --verbose &
PID=$!
while kill -0 $PID 2>/dev/null; do
    ps -o pid,rss,vsz $PID
    sleep 0.1
done
```

### GPU Monitoring

```bash
# Monitor GPU utilization during search
sudo powermetrics -s gpu_power --samplers gpu_power -n 10 &
.build/release/search-cli search large_file.txt "pattern"
```

## 📁 **File Structure Validation**

Ensure your extracted archive contains:

```
gpu-text-search-mastercopy/
├── Package.swift                    ✅ SPM configuration
├── README.md                       ✅ Documentation
├── LICENSE                         ✅ MIT license
├── DEPLOYMENT_GUIDE.md             ✅ This file
├── MASTERCOPY_MANIFEST.md          ✅ Quality certification
├── Sources/
│   ├── SearchEngine/
│   │   ├── SearchEngine.swift      ✅ Core engine (667 lines)
│   │   └── SearchKernel.metal      ✅ GPU shader (59 lines)
│   └── SearchCLI/
│       └── main.swift              ✅ CLI interface (356 lines)
├── Tests/
│   └── SearchEngineTests/
│       └── SearchEngineTests.swift ✅ Test suite
└── Validation/
    ├── comprehensive_test.py       ✅ Validation scripts
    ├── validate_binary.py          ✅ Binary verification
    └── performance_report.md       ✅ Benchmark data
```

## 🎯 **Success Criteria**

Your deployment is successful when:

1. ✅ **Build completes** without errors in <30 seconds
2. ✅ **Help command** displays professional CLI interface
3. ✅ **Basic search** finds correct matches with position accuracy
4. ✅ **Performance test** shows reasonable throughput for your hardware
5. ✅ **Binary export** creates valid UInt32 position files

## 🆘 **Getting Help**

### Self-Diagnostics

```bash
# System information
system_profiler SPSoftwareDataType SPHardwareDataType | grep -E "(System Version|Chip|Memory)"

# Metal capability check
/System/Library/Frameworks/Metal.framework/Versions/Current/bin/metal-capability

# Build environment
swift --version
xcodebuild -version
```

### Common Solutions

1. **Build fails**: Update Xcode, check Swift version
2. **No Metal device**: Verify GPU Metal support
3. **Slow performance**: Check GPU utilization, close other apps
4. **Memory errors**: Reduce file size, increase available RAM
5. **Permission errors**: Check file read permissions

### Performance Optimization

```bash
# Disable GPU power management (advanced)
sudo pmset -a gpuswitch 0  # Force discrete GPU (Intel Macs)

# Increase file descriptor limits
ulimit -n 4096

# Set CPU performance mode
sudo pmset -a powernap 0
```

## ✅ **Deployment Checklist**

- [ ] Archive extracted successfully
- [ ] System meets minimum requirements
- [ ] Swift build completes without errors
- [ ] Basic functionality validated
- [ ] Performance within expected range
- [ ] Binary export working correctly
- [ ] Help documentation accessible

**Once all items are checked, your GPU Text Search CLI tool is ready for production use!**

---

**For additional support or performance optimization questions, refer to the comprehensive README.md and technical documentation included in this archive.**\n
