import Foundation
import Metal

/// Manages file mapping and Metal buffer creation
final class FileMapper {
    
    private var mappedFilePtr: UnsafeMutableRawPointer?
    private var mappedFileLength: Int = -1
    private var fileBuffer: MTLBuffer?
    private let metalResourceManager: MetalResourceManager
    
    var isFileMapped: Bool { mappedFileLength >= 0 }
    var fileSize: Int { max(0, mappedFileLength) }
    
    init(metalResourceManager: MetalResourceManager) {
        self.metalResourceManager = metalResourceManager
    }
    
    func mapFile(at url: URL) throws {
        try unmapFile()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound(url.path)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileSystemError.fileNotReadable(url.path)
        }
        
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw FileSystemError.fileNotReadable(url.path)
        }
        defer { close(fd) }
        
        var stats = stat()
        guard fstat(fd, &stats) == 0 else {
            throw FileSystemError.fileStatsError(String(cString: strerror(errno)))
        }
        
        let fileSize = Int(stats.st_size)
        guard fileSize >= 0 else {
            throw FileSystemError.invalidFileSize(Int64(fileSize))
        }
        
        guard stats.st_size <= Configuration.maxFileSize else {
            throw FileSystemError.fileTooLarge(stats.st_size, maxSize: Configuration.maxFileSize)
        }
        
        if fileSize == 0 {
            mappedFilePtr = nil
            mappedFileLength = 0
            fileBuffer = nil
            return
        }
        
        let ptr = mmap(nil, fileSize, PROT_READ, MAP_PRIVATE, fd, 0)
        guard ptr != MAP_FAILED else {
            throw FileSystemError.memoryMappingFailed(url.path, systemError: String(cString: strerror(errno)))
        }
        
        mappedFilePtr = ptr
        mappedFileLength = fileSize
        fileBuffer = nil // Will be created on demand
    }
    
    func unmapFile() throws {
        defer {
            mappedFilePtr = nil
            mappedFileLength = -1
            clearMetalBuffers()
        }
        
        guard let ptr = mappedFilePtr, mappedFileLength > 0 else {
            return
        }
        
        if munmap(ptr, mappedFileLength) != 0 {
            throw FileSystemError.unmappingFailed(String(cString: strerror(errno)))
        }
    }
    
    private func clearMetalBuffers() {
        fileBuffer = nil
    }
    
    func getFileBuffer() throws -> MTLBuffer {
        guard isFileMapped else {
            throw ValidationError.noFileMapped
        }
        
        guard mappedFileLength > 0 else {
            throw ValidationError.invalidConfiguration("Cannot create buffer for empty file")
        }
        
        guard let mappedPtr = mappedFilePtr else {
            throw ValidationError.invalidConfiguration("File mapped but pointer is nil")
        }
        
        if fileBuffer == nil || fileBuffer?.length != mappedFileLength {
            let device = try metalResourceManager.getDevice()
            fileBuffer = device.makeBuffer(
                bytesNoCopy: mappedPtr,
                length: mappedFileLength,
                options: metalResourceManager.optimalStorageMode(),
                deallocator: nil
            )
            guard fileBuffer != nil else {
                throw MetalError.bufferCreationFailed("file content", size: mappedFileLength)
            }
            fileBuffer?.label = "File Content Buffer"
        }
        
        return fileBuffer!
    }
    
    func validatePattern(_ pattern: String) throws {
        guard !pattern.isEmpty else {
            throw ValidationError.emptyPattern
        }
        
        guard isFileMapped else {
            throw ValidationError.noFileMapped
        }
        
        guard pattern.utf8.count <= mappedFileLength else {
            throw ValidationError.patternTooLong(pattern.utf8.count, maxLength: mappedFileLength)
        }
        
        guard pattern.data(using: .utf8) != nil else {
            throw ValidationError.patternEncodingFailed(pattern)
        }
    }
    
    deinit {
        try? unmapFile()
    }
}