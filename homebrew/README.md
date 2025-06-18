# Homebrew Formula for GPU Text Search

This directory contains the Homebrew formula for installing GPU Text Search.
**Note:** the formula is still being finalized and is not yet available from Homebrew Core.

## Installation

### Option 1: From Homebrew Core (Recommended - coming soon)
```bash
brew install gpu-text-search
```

### Option 2: From This Repository
```bash
# Add this repository as a tap
brew tap teenu/gpu-text-search https://github.com/teenu/gpu-text-search

# Install the formula
brew install gpu-text-search
```

### Option 3: Install directly from formula
```bash
brew install https://raw.githubusercontent.com/teenu/gpu-text-search/main/homebrew/gpu-text-search.rb
```

## Usage After Installation

```bash
# The binary is installed as 'gpu-text-search'
gpu-text-search file.txt "pattern"

# Get help
gpu-text-search --help

# Run validation test
gpu-text-search "$(brew --prefix)/share/gpu-text-search/test_file.txt" "Hello" --verbose
```

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+** (for building from source)
- **Metal-capable GPU** (all modern Macs)

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
