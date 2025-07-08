import XCTest
@testable import SearchEngine

final class SearchEngineTests: XCTestCase {
    var engine: SearchEngine!
    
    override func setUp() {
        super.setUp()
        engine = try! SearchEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    func testBasicSearch() {
        let tempFile = createTempFile(content: "Hello, World! Hello again!")
        defer { try! FileManager.default.removeItem(at: tempFile) }
        
        try! engine.mapFile(at: tempFile)
        let result = try! engine.search(pattern: "Hello")
        
        XCTAssertEqual(result.matchCount, 2)
        XCTAssertEqual(result.positions.prefix(2), [0, 14])
        XCTAssertGreaterThan(result.executionTime, 0)
    }
    
    func testSingleCharacterSearch() {
        let tempFile = createTempFile(content: "aaaa")
        defer { try! FileManager.default.removeItem(at: tempFile) }
        
        try! engine.mapFile(at: tempFile)
        let result = try! engine.search(pattern: "a")
        
        XCTAssertEqual(result.matchCount, 4)
        XCTAssertEqual(result.positions.prefix(4), [0, 1, 2, 3])
    }
    
    func testOverlappingMatches() {
        let tempFile = createTempFile(content: "aaaa")
        defer { try! FileManager.default.removeItem(at: tempFile) }
        
        try! engine.mapFile(at: tempFile)
        let result = try! engine.search(pattern: "aa")
        
        XCTAssertEqual(result.matchCount, 3)
        XCTAssertEqual(result.positions.prefix(3), [0, 1, 2])
    }
    
    func testEmptyFile() {
        let tempFile = createTempFile(content: "")
        defer { try! FileManager.default.removeItem(at: tempFile) }
        
        try! engine.mapFile(at: tempFile)
        let result = try! engine.search(pattern: "test")
        
        XCTAssertEqual(result.matchCount, 0)
        XCTAssertEqual(result.positions.count, 0)
    }
    
    private func createTempFile(content: String) -> URL {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
}