#!/bin/bash

# GPU Text Search - Gilded Edition
# Automated Installation Script
# Compatible with macOS 13.0+ (Apple Silicon & Intel)

set -e

echo "🚀 GPU Text Search - Gilded Edition Installer"
echo "=============================================="
echo

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check system requirements
info "Checking system requirements..."

# Check macOS version
if [[ "$(uname)" != "Darwin" ]]; then
    error "This tool requires macOS. Current system: $(uname)"
fi

# Check macOS version (13.0+)
macos_version=$(sw_vers -productVersion | cut -d. -f1-2)
if [[ "$(echo "$macos_version >= 13.0" | bc)" != "1" ]]; then
    warning "macOS 13.0+ recommended. Current version: $macos_version"
    echo "The tool may still work, but optimal performance requires macOS 13.0+."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check architecture
arch=$(uname -m)
info "Detected architecture: $arch"

# Check for Metal GPU support
if ! system_profiler SPDisplaysDataType | grep -q "Metal"; then
    warning "No Metal GPU detected. Performance will be limited."
fi

success "System requirements check completed"
echo

# Installation options
echo "Installation Options:"
echo "1. Install binary to /usr/local/bin (requires sudo)"
echo "2. Install to current directory"
echo "3. Install to custom location"
echo

read -p "Choose installation option (1-3): " -n 1 -r install_option
echo
echo

case $install_option in
    1)
        INSTALL_DIR="/usr/local/bin"
        NEEDS_SUDO=true
        ;;
    2)
        INSTALL_DIR="$(pwd)"
        NEEDS_SUDO=false
        ;;
    3)
        read -p "Enter installation directory: " INSTALL_DIR
        if [[ ! -d "$INSTALL_DIR" ]]; then
            error "Directory does not exist: $INSTALL_DIR"
        fi
        if [[ ! -w "$INSTALL_DIR" ]]; then
            NEEDS_SUDO=true
        else
            NEEDS_SUDO=false
        fi
        ;;
    *)
        error "Invalid option selected"
        ;;
esac

# Check if binary exists
if [[ ! -f "search-cli" ]]; then
    error "Binary 'search-cli' not found in current directory"
fi

# Install binary
info "Installing GPU Text Search to $INSTALL_DIR..."

if [[ "$NEEDS_SUDO" == "true" ]]; then
    info "Administrator privileges required for installation to $INSTALL_DIR"
    sudo cp search-cli "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/search-cli"
else
    cp search-cli "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/search-cli"
fi

success "Binary installed successfully"

# Verify installation
if [[ "$INSTALL_DIR" == "/usr/local/bin" ]]; then
    BINARY_PATH="search-cli"
else
    BINARY_PATH="$INSTALL_DIR/search-cli"
fi

info "Verifying installation..."
if command -v "$BINARY_PATH" >/dev/null 2>&1; then
    VERSION_OUTPUT=$("$BINARY_PATH" --help | head -1)
    success "Installation verified: $VERSION_OUTPUT"
else
    warning "Binary installed but not in PATH. Use full path: $INSTALL_DIR/search-cli"
fi

echo

# Quick test with sample file
if [[ -f "test_file.txt" ]]; then
    info "Running quick validation test..."
    if "$BINARY_PATH" search test_file.txt "Hello" --quiet >/dev/null 2>&1; then
        success "Quick test passed"
    else
        warning "Quick test failed - but installation was successful"
    fi
fi

echo
echo "🎉 Installation Complete!"
echo
echo "Getting Started:"
echo "  $BINARY_PATH search <file> <pattern>           # Basic search"
echo "  $BINARY_PATH search <file> <pattern> --verbose # Detailed output"
echo "  $BINARY_PATH benchmark <file> <pattern>        # Performance test"
echo "  $BINARY_PATH --help                            # Full documentation"
echo
echo "For large files (>1GB), consider using --warmup for peak performance:"
echo "  $BINARY_PATH search large_file.txt \"pattern\" --warmup"
echo
echo "Example Performance Test:"
echo "  $BINARY_PATH benchmark test_file.txt \"Hello\" --iterations 10"
echo

if [[ "$arch" == "arm64" ]]; then
    info "Apple Silicon detected - optimal performance available!"
else
    info "Intel processor detected - good performance available"
fi

echo
success "GPU Text Search - Gilded Edition ready for use! 🚀"\n
