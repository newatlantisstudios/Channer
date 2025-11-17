//
//  MockFileManager.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation

/// Mock implementation of FileManager for testing file operations
/// Uses in-memory storage instead of actual file system
class MockFileManager {

    // MARK: - In-Memory Storage

    private var fileSystem: [String: Data] = [:]
    private var directories: Set<String> = []

    // MARK: - Mock Control Properties

    /// Simulate file operation failures
    var shouldFailOperations: Bool = false

    /// Error to throw when operations fail
    var failureError: Error = NSError(domain: "MockFileManager", code: -1, userInfo: nil)

    /// Track method calls for verification
    var createDirectoryCallCount: Int = 0
    var writeDataCallCount: Int = 0
    var removeItemCallCount: Int = 0
    var copyItemCallCount: Int = 0

    // MARK: - Initialization

    init() {
        // Create common directories
        directories.insert("/tmp")
        directories.insert(NSHomeDirectory())
        directories.insert(documentsDirectory())
        directories.insert(cachesDirectory())
    }

    // MARK: - Directory Methods

    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]? = nil) throws {
        createDirectoryCallCount += 1

        if shouldFailOperations {
            throw failureError
        }

        let path = url.path
        directories.insert(path)

        // Create parent directories if requested
        if withIntermediateDirectories {
            var parentPath = url.deletingLastPathComponent().path
            while !directories.contains(parentPath) && parentPath != "/" {
                directories.insert(parentPath)
                parentPath = URL(fileURLWithPath: parentPath).deletingLastPathComponent().path
            }
        }
    }

    func fileExists(atPath path: String) -> Bool {
        return fileSystem[path] != nil || directories.contains(path)
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if directories.contains(path) {
            isDirectory?.pointee = true
            return true
        }
        if fileSystem[path] != nil {
            isDirectory?.pointee = false
            return true
        }
        return false
    }

    // MARK: - File Operations

    func contents(atPath path: String) -> Data? {
        return fileSystem[path]
    }

    func createFile(atPath path: String, contents data: Data?, attributes: [FileAttributeKey: Any]? = nil) -> Bool {
        if shouldFailOperations {
            return false
        }

        fileSystem[path] = data ?? Data()
        return true
    }

    func removeItem(at url: URL) throws {
        removeItemCallCount += 1

        if shouldFailOperations {
            throw failureError
        }

        let path = url.path

        // Remove file
        if fileSystem[path] != nil {
            fileSystem.removeValue(forKey: path)
            return
        }

        // Remove directory and all contents
        if directories.contains(path) {
            directories.remove(path)

            // Remove all files in directory
            let filesToRemove = fileSystem.keys.filter { $0.hasPrefix(path + "/") }
            for file in filesToRemove {
                fileSystem.removeValue(forKey: file)
            }

            // Remove subdirectories
            let dirsToRemove = directories.filter { $0.hasPrefix(path + "/") }
            directories.subtract(dirsToRemove)
            return
        }

        throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
    }

    func removeItem(atPath path: String) throws {
        try removeItem(at: URL(fileURLWithPath: path))
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyItemCallCount += 1

        if shouldFailOperations {
            throw failureError
        }

        let srcPath = srcURL.path
        let dstPath = dstURL.path

        guard let data = fileSystem[srcPath] else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
        }

        fileSystem[dstPath] = data
    }

    func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        try copyItem(at: URL(fileURLWithPath: srcPath), to: URL(fileURLWithPath: dstPath))
    }

    func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if shouldFailOperations {
            throw failureError
        }

        try copyItem(at: srcURL, to: dstURL)
        try removeItem(at: srcURL)
    }

    func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        try moveItem(at: URL(fileURLWithPath: srcPath), to: URL(fileURLWithPath: dstPath))
    }

    // MARK: - Data Writing

    func writeData(_ data: Data, to url: URL) throws {
        writeDataCallCount += 1

        if shouldFailOperations {
            throw failureError
        }

        fileSystem[url.path] = data
    }

    // MARK: - Directory Enumeration

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        if shouldFailOperations {
            throw failureError
        }

        guard directories.contains(path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
        }

        let prefix = path + "/"
        var contents: [String] = []

        // Add files
        for filePath in fileSystem.keys where filePath.hasPrefix(prefix) {
            let relativePath = String(filePath.dropFirst(prefix.count))
            if !relativePath.contains("/") {
                contents.append(relativePath)
            }
        }

        // Add subdirectories
        for dirPath in directories where dirPath.hasPrefix(prefix) && dirPath != path {
            let relativePath = String(dirPath.dropFirst(prefix.count))
            if !relativePath.contains("/") {
                contents.append(relativePath)
            }
        }

        return contents
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        let paths = try contentsOfDirectory(atPath: url.path)
        return paths.map { url.appendingPathComponent($0) }
    }

    // MARK: - Attributes

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if shouldFailOperations {
            throw failureError
        }

        guard fileExists(atPath: path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
        }

        var attributes: [FileAttributeKey: Any] = [:]

        if let data = fileSystem[path] {
            attributes[.size] = data.count
            attributes[.type] = FileAttributeType.typeRegular
        } else if directories.contains(path) {
            attributes[.type] = FileAttributeType.typeDirectory
        }

        attributes[.modificationDate] = Date()
        return attributes
    }

    // MARK: - URLs

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        switch directory {
        case .documentDirectory:
            return [URL(fileURLWithPath: documentsDirectory())]
        case .cachesDirectory:
            return [URL(fileURLWithPath: cachesDirectory())]
        case .applicationSupportDirectory:
            return [URL(fileURLWithPath: applicationSupportDirectory())]
        default:
            return []
        }
    }

    private func documentsDirectory() -> String {
        return NSHomeDirectory() + "/Documents"
    }

    private func cachesDirectory() -> String {
        return NSHomeDirectory() + "/Library/Caches"
    }

    private func applicationSupportDirectory() -> String {
        return NSHomeDirectory() + "/Library/Application Support"
    }

    // MARK: - Test Helpers

    /// Reset all storage and counters
    func reset() {
        fileSystem.removeAll()
        directories.removeAll()

        // Recreate common directories
        directories.insert("/tmp")
        directories.insert(NSHomeDirectory())
        directories.insert(documentsDirectory())
        directories.insert(cachesDirectory())

        createDirectoryCallCount = 0
        writeDataCallCount = 0
        removeItemCallCount = 0
        copyItemCallCount = 0
        shouldFailOperations = false
    }

    /// Get all file paths for verification
    func allFilePaths() -> [String] {
        return Array(fileSystem.keys)
    }

    /// Get all directory paths
    func allDirectoryPaths() -> [String] {
        return Array(directories)
    }

    /// Add mock file directly (for test setup)
    func addMockFile(atPath path: String, contents: Data) {
        fileSystem[path] = contents
    }

    /// Get file size
    func fileSize(atPath path: String) -> Int? {
        return fileSystem[path]?.count
    }

    /// Check if path is directory
    func isDirectory(atPath path: String) -> Bool {
        return directories.contains(path)
    }
}
