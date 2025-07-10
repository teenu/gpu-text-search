import Foundation

/// Unified binary result exporter optimized for high-performance scenarios
public struct BinaryResultExporter {
    
    public init() {}
    
    public func exportPositions(_ storage: ResultStorage, to url: URL) throws {
        try removeExistingFile(at: url)
        try createExportFile(at: url)
        
        let fileHandle = try FileHandle(forWritingTo: url)
        defer {
            do {
                try fileHandle.close()
            } catch {
                print("Warning: Failed to close file handle for \(url.path): \(error)")
            }
        }
        
        let data = storage.getPositionData()
        try fileHandle.write(contentsOf: data)
    }
    
    private func removeExistingFile(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    private func createExportFile(at url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
            throw FileSystemError.exportFileCreationFailed(url.path)
        }
    }
}