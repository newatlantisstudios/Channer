//
//  DownloadItem.swift
//  Channer
//
//  Data model for download state tracking
//

import Foundation

/// Status of a download item
enum DownloadStatus: String, Codable {
    case pending      // Queued but not started
    case downloading  // Currently in progress
    case paused       // Manually paused by user
    case completed    // Successfully finished
    case failed       // Failed with error
    case cancelled    // Cancelled by user
}

/// Type of media being downloaded
enum DownloadMediaType: String, Codable {
    case image
    case video

    var iconName: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        }
    }
}

/// Represents a single download task with all metadata needed for persistence and resumption
struct DownloadItem: Codable, Identifiable {
    // MARK: - Identity
    let id: String
    let sourceURL: URL
    let destinationPath: String  // Relative path from Documents directory

    // MARK: - Context Metadata
    let boardAbv: String
    let threadNumber: String
    let filename: String
    let mediaType: DownloadMediaType

    // MARK: - Progress Tracking
    var status: DownloadStatus
    var bytesDownloaded: Int64
    var totalBytes: Int64

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    // MARK: - Error Handling
    var errorMessage: String?
    var retryCount: Int

    // MARK: - Timestamps
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var pausedAt: Date?

    // MARK: - Resume Support
    var resumeData: Data?
    var eTag: String?
    var lastModified: String?

    // MARK: - Initialization
    init(sourceURL: URL, destinationPath: String, boardAbv: String, threadNumber: String, filename: String, mediaType: DownloadMediaType) {
        self.id = UUID().uuidString
        self.sourceURL = sourceURL
        self.destinationPath = destinationPath
        self.boardAbv = boardAbv
        self.threadNumber = threadNumber
        self.filename = filename
        self.mediaType = mediaType
        self.status = .pending
        self.bytesDownloaded = 0
        self.totalBytes = -1
        self.retryCount = 0
        self.createdAt = Date()
    }
}

/// Grouping structure for display in Download Manager
struct DownloadGroup: Identifiable {
    let id: String  // "{boardAbv}_{threadNumber}"
    let boardAbv: String
    let threadNumber: String
    var items: [DownloadItem]

    var displayTitle: String {
        return "/\(boardAbv)/ - Thread \(threadNumber)"
    }

    var totalProgress: Double {
        guard !items.isEmpty else { return 0 }
        let completed = items.reduce(0.0) { $0 + $1.progress }
        return completed / Double(items.count)
    }

    var activeCount: Int {
        items.filter { $0.status == .downloading }.count
    }

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var failedCount: Int {
        items.filter { $0.status == .failed }.count
    }

    var totalCount: Int {
        items.count
    }
}
