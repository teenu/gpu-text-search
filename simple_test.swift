import Foundation
import SearchEngine

// Simple test without XCTest
func testBasicFunctionality() {
    print("Testing V3 Foundation basic functionality...")
    
    do {
        let engine = try SearchEngine()
        
        // Create a simple test file
        let testContent = "Hello, World! Hello again!"
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try testContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        // Test file mapping
        try engine.mapFile(at: tempFile)
        
        // Test search
        let result = try engine.search(pattern: "Hello")
        
        print("✅ Basic functionality test passed!")
        print("   Matches: \(result.matchCount)")
        print("   Positions: \(result.positions.prefix(5))")
        print("   Execution time: \(result.executionTime)s")
        print("   Throughput: \(result.throughputMBps) MB/s")
        
        // Cleanup
        try FileManager.default.removeItem(at: tempFile)
        
    } catch {
        print("❌ Test failed: \(error)")
        exit(1)
    }
}

testBasicFunctionality()