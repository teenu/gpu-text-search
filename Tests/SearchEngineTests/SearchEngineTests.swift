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
        let testString = "Hello, World! Hello again!"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: "Hello")
            
            XCTAssertEqual(result.matchCount, 2)
            XCTAssertEqual(result.positions.count, 2)
            XCTAssertEqual(result.positions[0], 0)  // First "Hello" at position 0
            XCTAssertEqual(result.positions[1], 14) // Second "Hello" at position 14
            XCTAssertFalse(result.truncated)
            XCTAssertGreaterThan(result.throughputMBps, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSingleCharacterSearch() {
        let testString = "abacadaba"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: "a")
            
            XCTAssertEqual(result.matchCount, 5) // 'a' appears 5 times
            XCTAssertEqual(result.positions.count, 5)
            XCTAssertEqual(result.positions, [0, 2, 4, 6, 8])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNoMatches() {
        let testString = "Hello, World!"
        let tempFile = createTempFile(content: testString)
        defer { removeTempFile(tempFile) }
        
        do {
            try engine.mapFile(at: tempFile)
            let result = try engine.search(pattern: "xyz")
            
            XCTAssertEqual(result.matchCount, 0)
            XCTAssertEqual(result.positions.count, 0)
            XCTAssertFalse(result.truncated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
}