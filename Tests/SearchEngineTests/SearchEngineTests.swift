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
    
    // MARK: - Helper Methods
    
    private func createTempFile(content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)
        
        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
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
