//
//  BatchImageDownloadManager.swift
//  Channer
//
//  Handles batch downloading of images from threads
//

import UIKit

/// Delegate protocol for batch download progress updates
protocol BatchImageDownloadDelegate: AnyObject {
    func batchDownloadDidStart(totalCount: Int)
    func batchDownloadDidProgress(completed: Int, total: Int, currentURL: URL)
    func batchDownloadDidComplete(successCount: Int, failureCount: Int, savedToPath: URL)
    func batchDownloadDidFail(error: Error)
}

/// Manager class for handling batch image downloads
class BatchImageDownloadManager {

    /// Shared singleton instance
    static let shared = BatchImageDownloadManager()

    /// Delegate for progress updates
    weak var delegate: BatchImageDownloadDelegate?

    /// Flag to track if download is in progress
    private(set) var isDownloading = false

    /// Current download task for cancellation
    private var currentTask: Task<Void, Never>?

    private init() {}

    // MARK: - Directory Management

    /// Gets the directory for saving batch downloaded images
    /// - Parameter threadID: The thread identifier
    /// - Returns: URL to the thread's image directory
    func getThreadImagesDirectory(threadID: String, boardAbv: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let batchDownloadsDir = documentsPath.appendingPathComponent("BatchDownloads", isDirectory: true)
        let threadDir = batchDownloadsDir.appendingPathComponent("\(boardAbv)_\(threadID)", isDirectory: true)

        // Create directories if they don't exist
        do {
            try FileManager.default.createDirectory(at: threadDir, withIntermediateDirectories: true)
        } catch {
            print("DEBUG: BatchImageDownloadManager - Failed to create directory: \(error)")
        }

        return threadDir
    }

    // MARK: - Batch Download

    /// Downloads all images from the provided URLs
    /// - Parameters:
    ///   - imageURLs: Array of image URLs to download
    ///   - threadID: The thread identifier for folder organization
    ///   - boardAbv: The board abbreviation
    ///   - referer: Optional referer header for the requests
    func downloadAllImages(
        imageURLs: [URL],
        threadID: String,
        boardAbv: String,
        referer: String? = nil
    ) {
        guard !isDownloading else {
            print("DEBUG: BatchImageDownloadManager - Download already in progress")
            return
        }

        guard !imageURLs.isEmpty else {
            print("DEBUG: BatchImageDownloadManager - No images to download")
            return
        }

        isDownloading = true
        let saveDirectory = getThreadImagesDirectory(threadID: threadID, boardAbv: boardAbv)

        currentTask = Task {
            await performBatchDownload(
                imageURLs: imageURLs,
                saveDirectory: saveDirectory,
                referer: referer
            )
        }
    }

    /// Cancels the current batch download
    func cancelDownload() {
        currentTask?.cancel()
        currentTask = nil
        isDownloading = false
    }

    // MARK: - Private Download Methods

    private func performBatchDownload(
        imageURLs: [URL],
        saveDirectory: URL,
        referer: String?
    ) async {
        let totalCount = imageURLs.count

        await MainActor.run {
            delegate?.batchDownloadDidStart(totalCount: totalCount)
        }

        var successCount = 0
        var failureCount = 0

        for (index, imageURL) in imageURLs.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                print("DEBUG: BatchImageDownloadManager - Download cancelled")
                break
            }

            await MainActor.run {
                delegate?.batchDownloadDidProgress(completed: index, total: totalCount, currentURL: imageURL)
            }

            let success = await downloadSingleImage(
                url: imageURL,
                saveDirectory: saveDirectory,
                referer: referer
            )

            if success {
                successCount += 1
            } else {
                failureCount += 1
            }

            // Small delay to avoid overwhelming the server
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
        }

        isDownloading = false

        await MainActor.run {
            delegate?.batchDownloadDidComplete(
                successCount: successCount,
                failureCount: failureCount,
                savedToPath: saveDirectory
            )
        }
    }

    private func downloadSingleImage(
        url: URL,
        saveDirectory: URL,
        referer: String?
    ) async -> Bool {
        let filename = url.lastPathComponent
        let destinationURL = saveDirectory.appendingPathComponent(filename)

        // Skip if file already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("DEBUG: BatchImageDownloadManager - File already exists: \(filename)")
            return true
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        // Add referer if provided
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        // Add 4chan-specific headers
        if let host = url.host, host == "i.4cdn.org" {
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                let board = pathComponents[1]
                request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
            }
        }

        do {
            let (tempURL, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("DEBUG: BatchImageDownloadManager - Bad response for \(filename)")
                return false
            }

            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            print("DEBUG: BatchImageDownloadManager - Downloaded: \(filename)")
            return true

        } catch {
            print("DEBUG: BatchImageDownloadManager - Error downloading \(filename): \(error)")
            return false
        }
    }

    // MARK: - Utility Methods

    /// Gets supported image extensions for filtering
    static let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "avif"]
    static let supportedVideoExtensions = ["webm", "mp4", "mov"]
    static let supportedMediaExtensions = supportedImageExtensions + supportedVideoExtensions

    /// Filters URLs to only include supported media types
    /// - Parameters:
    ///   - urls: Array of URLs to filter
    ///   - includeVideos: Whether to include video files
    /// - Returns: Filtered array of media URLs
    static func filterMediaURLs(_ urls: [URL], includeVideos: Bool = true) -> [URL] {
        let extensions = includeVideos ? supportedMediaExtensions : supportedImageExtensions
        return urls.filter { url in
            extensions.contains(url.pathExtension.lowercased())
        }
    }
}

// MARK: - Progress Alert Helper

extension BatchImageDownloadManager {

    /// Creates and returns a progress alert controller for batch downloads
    /// - Parameters:
    ///   - totalCount: Total number of images to download
    ///   - cancelHandler: Handler called when cancel is tapped
    /// - Returns: Configured UIAlertController
    func createProgressAlert(totalCount: Int, cancelHandler: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Downloading Images",
            message: "Preparing to download \(totalCount) images...",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            cancelHandler()
        }
        alert.addAction(cancelAction)

        // Add progress view
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0

        alert.view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -50)
        ])

        // Store progress view for later updates
        objc_setAssociatedObject(alert, &AssociatedKeys.progressView, progressView, .OBJC_ASSOCIATION_RETAIN)

        return alert
    }

    /// Updates the progress alert with current progress
    /// - Parameters:
    ///   - alert: The alert controller to update
    ///   - completed: Number of completed downloads
    ///   - total: Total number of downloads
    func updateProgressAlert(_ alert: UIAlertController, completed: Int, total: Int) {
        let progress = Float(completed) / Float(total)
        alert.message = "Downloaded \(completed) of \(total) images..."

        if let progressView = objc_getAssociatedObject(alert, &AssociatedKeys.progressView) as? UIProgressView {
            progressView.setProgress(progress, animated: true)
        }
    }

    private struct AssociatedKeys {
        static var progressView = "progressView"
    }
}
