import XCTest
@testable import SearchEngine

final class SearchEngineTests: XCTestCase {
    var engine: SearchEngine!
    
    override func setUp() {
        super.setUp()
        do {
            engine = try SearchEngine()
        } catch {
            XCTFail("Failed to initialize SearchEngine: \(error)")
        }
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    func testEngineInitialization() {
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isFileMapped)
        XCTAssertEqual(engine.fileSize, 0)
    }
    
    func testSearchEmptyPattern() {
        // Create a temporary test file
        let testString = "Hello, World!"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            XCTAssertThrowsError(try engine.search(pattern: "")) { error in
                XCTAssertTrue(error is SearchEngineError)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testBasicSearch() {
        performSearch(content: "Hello, World! Hello again!", pattern: "Hello", expectedCount: 2, expectedPositions: [0, 14])
    }
    
    func testSingleCharacterSearch() {
        performSearch(content: "abacadaba", pattern: "a", expectedCount: 5, expectedPositions: [0, 2, 4, 6, 8])
    }
    
    func testNoMatches() {
        performSearch(content: "Hello, World!", pattern: "xyz", expectedCount: 0, expectedPositions: [])
    }
    
    func testEmptyFile() {
        let tempFile = createTempFile(content: "")
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: "test")
            
            XCTAssertEqual(result.matchCount, 0)
            XCTAssertEqual(result.positions.count, 0)
            XCTAssertEqual(result.executionTime, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testBenchmark() {
        let testString = "Hello, World! Hello again! Hello once more!"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            let benchmark = try engine.benchmark(file: tempFile, pattern: "Hello", iterations: 5)
            
            XCTAssertEqual(benchmark.pattern, "Hello")
            XCTAssertEqual(benchmark.fileSize, testString.utf8.count)
            XCTAssertEqual(benchmark.results.count, 5)
            
            // All results should have the same match count
            for result in benchmark.results {
                XCTAssertEqual(result.matchCount, 3)
                XCTAssertEqual(result.positions.count, 3)
            }
            
            XCTAssertGreaterThan(benchmark.averageTime, 0)
            XCTAssertGreaterThan(benchmark.averageThroughput, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Enhanced Edge Case Tests
    
    func testVeryLongPattern() {
        let testString = "This is a test with a very long pattern that should still work correctly"
        let longPattern = "very long pattern that should still work"
        performSearch(content: testString, pattern: longPattern, expectedCount: 1, expectedPositions: [23])
    }
    
    func testUnicodePatterns() {
        performSearch(content: "Hello 世界! Hello again!", pattern: "世界", expectedCount: 1, expectedPositions: [6])
        performSearch(content: "🚀 Rocket test 🚀", pattern: "🚀", expectedCount: 2, expectedPositions: [0, 15])
        performSearch(content: "Café naïve résumé", pattern: "é", expectedCount: 3, expectedPositions: [3, 10, 16])
    }
    
    func testLargeFile() {
        // Create a larger test string (1MB)
        let pattern = "PATTERN"
        let largeContent = String(repeating: "A", count: 100000) + pattern + String(repeating: "B", count: 900000) + pattern
        performSearch(content: largeContent, pattern: pattern, expectedCount: 2)
    }
    
    func testMultiplePatternLengths() {
        let content = "abcdefghijklmnopqrstuvwxyz1234567890"
        
        // Test various pattern lengths
        performSearch(content: content, pattern: "a", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "ab", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abc", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcd", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcde", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcdef", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcdefg", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcdefgh", expectedCount: 1, expectedPositions: [0])
        performSearch(content: content, pattern: "abcdefghijklmnop", expectedCount: 1, expectedPositions: [0])
    }
    
    func testOverlappingMatches() {
        performSearch(content: "aaaa", pattern: "aa", expectedCount: 3, expectedPositions: [0, 1, 2])
        performSearch(content: "abababab", pattern: "aba", expectedCount: 3, expectedPositions: [0, 2, 4])
    }
    
    func testCaseSensitivity() {
        performSearch(content: "Hello hello HELLO", pattern: "hello", expectedCount: 1, expectedPositions: [6])
        performSearch(content: "Hello hello HELLO", pattern: "Hello", expectedCount: 1, expectedPositions: [0])
        performSearch(content: "Hello hello HELLO", pattern: "HELLO", expectedCount: 1, expectedPositions: [12])
    }
    
    func testSpecialCharacters() {
        performSearch(content: "test@example.com user@test.org", pattern: "@", expectedCount: 2, expectedPositions: [4, 21])
        performSearch(content: "Price: $50.99 Tax: $5.10", pattern: "$", expectedCount: 2, expectedPositions: [7, 19])
        performSearch(content: "Line1\nLine2\rLine3\r\nLine4", pattern: "\n", expectedCount: 2, expectedPositions: [5, 18])
    }
    
    func testBinaryData() {
        // Test with binary-like data
        let binaryString = String(bytes: [0x00, 0x01, 0x02, 0x03, 0x41, 0x42, 0x43, 0x00, 0x01], encoding: .ascii) ?? ""
        performSearch(content: binaryString, pattern: "ABC", expectedCount: 1, expectedPositions: [4])
    }
    
    func testWarmupFunctionality() {
        let testString = "Hello, World!"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            try engine.warmup()
            let result = try engine.search(pattern: "Hello")
            XCTAssertEqual(result.matchCount, 1)
        } catch {
            XCTFail("Warmup test failed: \(error)")
        }
    }
    
    func testBinaryExport() {
        let testString = "Hello, World! Hello again!"
        let tempFile = createTempFile(content: testString)
        let exportFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_export.bin")
        defer { 
            removeTempFile(tempFile)
            try? FileManager.default.removeItem(at: exportFile)
        }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: "Hello")
            XCTAssertEqual(result.matchCount, 2)
            
            try engine.exportPositionsBinary(to: exportFile)
            
            // Verify export file exists and has correct size
            XCTAssertTrue(FileManager.default.fileExists(atPath: exportFile.path))
            let fileData = try Data(contentsOf: exportFile)
            XCTAssertEqual(fileData.count, 2 * MemoryLayout<UInt32>.size) // 2 matches * 4 bytes each
            
        } catch {
            XCTFail("Binary export test failed: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidFileErrors() {
        let nonExistentFile = URL(fileURLWithPath: "/tmp/nonexistent_file_\(UUID().uuidString).txt")
        
        XCTAssertThrowsError(try engine.mapFile(at: nonExistentFile)) { error in
            XCTAssertTrue(error is SearchEngineError)
        }
    }
    
    func testPatternTooLong() {
        let testString = "Hello"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let veryLongPattern = String(repeating: "A", count: 70000) // Exceeds 64KB limit
            XCTAssertThrowsError(try engine.search(pattern: veryLongPattern)) { error in
                XCTAssertTrue(error is SearchEngineError)
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }
    
    func testPatternLongerThanFile() {
        let testString = "Hi"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            XCTAssertThrowsError(try engine.search(pattern: "This pattern is longer than the file")) { error in
                XCTAssertTrue(error is SearchEngineError)
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }
    
    func testNoFileMappedError() {
        XCTAssertThrowsError(try engine.search(pattern: "test")) { error in
            XCTAssertTrue(error is SearchEngineError)
        }
    }
    
    func testSearchConsistency() {
        let testString = "Pattern matching test with Pattern occurring multiple times. Pattern here too."
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            
            // Run the same search multiple times to ensure consistency
            let results = try (0..<10).map { _ in try engine.search(pattern: "Pattern") }
            
            // All results should be identical
            let firstResult = results[0]
            for result in results {
                XCTAssertEqual(result.matchCount, firstResult.matchCount)
                XCTAssertEqual(result.positions, firstResult.positions)
                XCTAssertFalse(result.truncated)
            }
            
            XCTAssertEqual(firstResult.matchCount, 3)
            XCTAssertEqual(firstResult.positions, [0, 28, 62])
            
        } catch {
            XCTFail("Consistency test failed: \(error)")
        }
    }
    
    // MARK: - Comprehensive Edge Case Tests
    
    func testUnicodeEdgeCases() {
        // Test various Unicode categories and combining characters
        performSearch(content: "Naïve café résumé", pattern: "ï", expectedCount: 1, expectedPositions: [2])
        performSearch(content: "🇺🇸🇫🇷🇩🇪", pattern: "🇫🇷", expectedCount: 1, expectedPositions: [4])
        performSearch(content: "e\u{0301}e\u{0301}e\u{0301}", pattern: "e\u{0301}", expectedCount: 3, expectedPositions: [0, 2, 4])
        performSearch(content: "𝓗𝓮𝓵𝓵𝓸 𝓦𝓸𝓻𝓵𝓭", pattern: "𝓗", expectedCount: 1, expectedPositions: [0])
    }
    
    func testLargeFileEdgeCases() {
        // Test file that's close to various buffer boundaries
        let pattern = "TEST"
        
        // Test around 1KB boundary
        let content1KB = String(repeating: "A", count: 1020) + pattern + String(repeating: "B", count: 3)
        performSearch(content: content1KB, pattern: pattern, expectedCount: 1, expectedPositions: [1020])
        
        // Test around 64KB boundary (common GPU buffer size)
        let content64KB = String(repeating: "X", count: 65532) + pattern + String(repeating: "Y", count: 3)
        performSearch(content: content64KB, pattern: pattern, expectedCount: 1, expectedPositions: [65532])
    }
    
    func testPatternAtFileBoundaries() {
        // Test patterns at the very start and end of files
        performSearch(content: "START middle END", pattern: "START", expectedCount: 1, expectedPositions: [0])
        performSearch(content: "START middle END", pattern: "END", expectedCount: 1, expectedPositions: [13])
        performSearch(content: "A", pattern: "A", expectedCount: 1, expectedPositions: [0])
    }
    
    func testRepeatingPatterns() {
        // Test patterns that repeat within themselves
        performSearch(content: "aaabaaabaaab", pattern: "aaab", expectedCount: 3, expectedPositions: [0, 4, 8])
        performSearch(content: "abcabcabcabc", pattern: "abcabc", expectedCount: 2, expectedPositions: [0, 6])
        performSearch(content: "123123123123", pattern: "123123", expectedCount: 2, expectedPositions: [0, 6])
    }
    
    func testControlCharacters() {
        // Test various control characters and whitespace
        performSearch(content: "line1\tline2\nline3\rline4", pattern: "\t", expectedCount: 1, expectedPositions: [5])
        performSearch(content: "word1 word2  word3", pattern: "  ", expectedCount: 1, expectedPositions: [11])
        performSearch(content: "test\0null\0test", pattern: "\0", expectedCount: 2, expectedPositions: [4, 9])
    }
    
    func testHighBitCharacters() {
        // Test characters with high bit values
        let content = String(bytes: [0x80, 0x90, 0xA0, 0xFF, 0x80, 0x90], encoding: .iso88591) ?? ""
        let pattern = String(bytes: [0x80, 0x90], encoding: .iso88591) ?? ""
        if !content.isEmpty && !pattern.isEmpty {
            performSearch(content: content, pattern: pattern, expectedCount: 2, expectedPositions: [0, 4])
        }
    }
    
    func testExtremelyLongSingleMatch() {
        // Test a very long pattern that matches only once
        let pattern = String(repeating: "UNIQUE_PATTERN_", count: 100) // 1500 chars
        let content = "start " + pattern + " end"
        performSearch(content: content, pattern: pattern, expectedCount: 1, expectedPositions: [6])
    }
    
    func testAlternatingPatterns() {
        // Test alternating patterns that could confuse the search
        performSearch(content: "ababababab", pattern: "aba", expectedCount: 4, expectedPositions: [0, 2, 4, 6])
        performSearch(content: "123121312131213", pattern: "1213", expectedCount: 3, expectedPositions: [5, 9, 11])
    }
    
    func testPatternAtExactFileEnd() {
        // Test pattern that ends exactly at file boundary
        let content = "Hello World"
        performSearch(content: content, pattern: "World", expectedCount: 1, expectedPositions: [6])
        performSearch(content: content, pattern: "d", expectedCount: 1, expectedPositions: [10])
    }
    
    func testMemoryIntensiveSearch() {
        // Test search that could stress memory allocation
        let pattern = "NEEDLE"
        let largeContent = String(repeating: "HAY", count: 100000) + pattern + String(repeating: "STACK", count: 100000)
        performSearch(content: largeContent, pattern: pattern, expectedCount: 1, expectedPositions: [300000])
    }
    
    func testConcurrentSearches() {
        // Test that multiple searches work correctly
        let content = "The quick brown fox jumps over the lazy dog"
        let tempFile = createTempFile(content: content)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            
            // Run multiple different searches to ensure no interference
            let result1 = try engine.search(pattern: "the")
            let result2 = try engine.search(pattern: "quick")
            let result3 = try engine.search(pattern: "fox")
            let result4 = try engine.search(pattern: "dog")
            
            XCTAssertEqual(result1.matchCount, 2) // "The" and "the"
            XCTAssertEqual(result2.matchCount, 1)
            XCTAssertEqual(result3.matchCount, 1)
            XCTAssertEqual(result4.matchCount, 1)
            
        } catch {
            XCTFail("Concurrent searches test failed: \(error)")
        }
    }
    
    func testErrorRecovery() {
        // Test that engine recovers properly from errors
        let content = "Hello World"
        let tempFile = createTempFile(content: content)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            
            // Cause an error with empty pattern
            XCTAssertThrowsError(try engine.search(pattern: ""))
            
            // Verify that normal searches still work after error
            let result = try engine.search(pattern: "Hello")
            XCTAssertEqual(result.matchCount, 1)
            
        } catch {
            XCTFail("Error recovery test failed: \(error)")
        }
    }
    
    func testPerformanceCharacteristics() {
        // Test various pattern lengths for performance consistency
        let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
        let content = String(repeating: alphabet, count: 1000) // ~36KB
        let tempFile = createTempFile(content: content)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            
            // Test different pattern lengths
            let patterns = ["a", "ab", "abc", "abcd", "abcde", "abcdef", "abcdefg", "abcdefgh"]
            var previousTime: TimeInterval = 0
            
            for pattern in patterns {
                let result = try engine.search(pattern: pattern)
                XCTAssertGreaterThan(result.matchCount, 0)
                XCTAssertGreaterThan(result.throughputMBps, 0)
                
                // Execution time should be reasonable (less than 1 second for this small file)
                XCTAssertLessThan(result.executionTime, 1.0)
                
                previousTime = result.executionTime
            }
            
        } catch {
            XCTFail("Performance characteristics test failed: \(error)")
        }
    }
    
    func testVectorizedPatternLengths() {
        // Test the specific pattern lengths that use vectorized operations in Metal shader
        let content = "abcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*()"
        
        // Test all the vectorized pattern lengths from the Metal shader
        performSearch(content: content, pattern: "a", expectedCount: 1, expectedPositions: [0])           // 1-byte
        performSearch(content: content, pattern: "ab", expectedCount: 1, expectedPositions: [0])          // 2-byte vectorized
        performSearch(content: content, pattern: "abc", expectedCount: 1, expectedPositions: [0])         // 3-byte unrolled
        performSearch(content: content, pattern: "abcd", expectedCount: 1, expectedPositions: [0])        // 4-byte vectorized
        performSearch(content: content, pattern: "abcde", expectedCount: 1, expectedPositions: [0])       // 5-byte unrolled
        performSearch(content: content, pattern: "abcdef", expectedCount: 1, expectedPositions: [0])      // 6-byte unrolled
        performSearch(content: content, pattern: "abcdefg", expectedCount: 1, expectedPositions: [0])     // 7-byte unrolled
        performSearch(content: content, pattern: "abcdefgh", expectedCount: 1, expectedPositions: [0])    // 8-byte vectorized
        performSearch(content: content, pattern: "abcdefghi", expectedCount: 1, expectedPositions: [0])   // 9+ byte chunked
    }
    
    func testLongPatternRejection() {
        // Test that overly long patterns are rejected
        let veryLongPattern = String(repeating: "A", count: 10000)
        let tempFile = createTempFile(content: "test")
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            XCTAssertThrowsError(try engine.search(pattern: veryLongPattern))
        } catch {
            XCTFail("Long pattern test setup failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(SearchEngineStrings.testFilePrefix)\(UUID().uuidString)\(SearchEngineStrings.testFileExtension)")
        
        do {
            let data = content.data(using: .utf8) ?? Data()
            FileManager.default.createFile(atPath: tempFile.path, contents: data, attributes: nil)
        } catch {
            XCTFail("Failed to create temp file: \(error)")
        }
        
        return tempFile
    }
    
    private func removeTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    private func performSearch(content: String, pattern: String, expectedCount: UInt32, expectedPositions: [UInt32]? = nil) {
        let tempFile = createTempFile(content: content)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: pattern)
            
            XCTAssertEqual(result.matchCount, expectedCount, "Match count mismatch for pattern '\(pattern)'")
            if let positions = expectedPositions {
                XCTAssertEqual(result.positions, positions, "Position mismatch for pattern '\(pattern)'")
            }
            XCTAssertFalse(result.truncated)
            if expectedCount > 0 {
                XCTAssertGreaterThan(result.throughputMBps, 0)
            }
        } catch {
            XCTFail("Unexpected error for pattern '\(pattern)': \(error)")
        }
    }
}
