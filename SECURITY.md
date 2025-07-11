# Security Policy

## Supported Versions

GPU Text Search follows semantic versioning. Security updates are provided for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.3.x   | ✅ Fully supported |
| 2.2.x   | ✅ Security fixes only |
| 2.1.x   | ❌ End of life |
| < 2.1   | ❌ End of life |

## Security Considerations

### Memory Safety
GPU Text Search is built with Swift, which provides memory safety by default. However, we use some unsafe operations for performance:

- **Memory-mapped file access**: Direct pointer manipulation for zero-copy operations
- **Metal GPU buffers**: Shared memory between CPU and GPU
- **Atomic operations**: Thread-safe result collection

### Data Privacy
- **No data persistence**: GPU Text Search does not store, cache, or transmit your data
- **Local processing only**: All operations occur locally on your machine
- **No network access**: The tool does not make any network connections
- **Memory cleanup**: File mappings are properly unmapped after processing

### Input Validation
- **File size limits**: Maximum 50GB file size to prevent resource exhaustion
- **Pattern validation**: Input patterns are validated for safety
- **Buffer bounds checking**: All buffer access is bounds-checked
- **Error handling**: Comprehensive error handling prevents crashes

## Reporting Security Vulnerabilities

**Please do not report security vulnerabilities through public GitHub issues.**

### Preferred Reporting Method
Send security reports privately to: **security@[maintainer-domain]**

### What to Include
Please include as much information as possible:

1. **Vulnerability description**: Clear explanation of the security issue
2. **Impact assessment**: Potential security implications
3. **Reproduction steps**: How to reproduce the vulnerability
4. **System information**: macOS version, hardware, GPU Text Search version
5. **Proof of concept**: If available, demonstration code (optional)

### Response Timeline
- **Initial response**: Within 48 hours
- **Preliminary assessment**: Within 1 week
- **Resolution timeline**: Depends on severity and complexity

## Security Best Practices for Users

### File Handling
- **Validate file sources**: Only process files from trusted sources
- **Check file permissions**: Ensure appropriate read permissions
- **Monitor resource usage**: Large files may consume significant memory

### CLI Usage
- **Validate input patterns**: Be cautious with patterns from untrusted sources
- **Use appropriate limits**: Set reasonable position limits for large result sets
- **Secure output files**: Protect exported binary files containing search results

### Library Integration
```swift
// Safe initialization
do {
    let engine = try SearchEngine()
    try engine.mapFile(at: trustedFileURL)
    let result = try engine.search(pattern: validatedPattern)
} catch {
    // Handle errors appropriately
    print("Search error: \(error)")
}
```

### Environment Security
- **Keep system updated**: Use latest macOS and Xcode versions
- **Monitor GPU resources**: GPU Text Search requires Metal GPU access
- **Validate permissions**: Ensure appropriate file system permissions

## Known Security Considerations

### Memory Usage
- **Large file handling**: Files are memory-mapped, requiring available virtual memory
- **GPU memory**: Search operations allocate GPU buffers proportional to file size
- **Result storage**: Match positions are stored in memory during processing

### Performance Security
- **Resource exhaustion**: Very large files or patterns may consume significant resources
- **GPU availability**: Requires Metal-capable GPU for operation
- **Concurrent usage**: Multiple instances may compete for GPU resources

## Security Updates

Security updates are delivered through:
- **GitHub Releases**: Tagged versions with security fixes
- **Homebrew**: Updated formulae for package manager users
- **Swift Package Manager**: Version updates for library integration

## Vulnerability Disclosure Policy

We follow responsible disclosure practices:

1. **Private notification**: Security researchers contact us privately
2. **Investigation period**: We investigate and develop fixes
3. **Coordinated disclosure**: Public disclosure after fix is available
4. **Credit attribution**: Security researchers are credited (if desired)

## Security Contact

For security-related questions or concerns:
- **Email**: security@[maintainer-domain]
- **Response time**: 48 hours maximum
- **Language**: English preferred

## Acknowledgments

We thank the security research community for helping keep GPU Text Search secure. If you discover a security vulnerability, we appreciate your responsible disclosure.

---

**Security is a shared responsibility. Thank you for helping keep GPU Text Search secure! 🔒**