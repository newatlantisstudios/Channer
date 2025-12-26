//
//  DownloadManagerService.swift
//  Channer
//
//  Manages all downloads with persistence, queuing, and background support
//

import Foundation
import UIKit

/// Manages all downloads with persistence, queuing, and background support
class DownloadManagerService: NSObject {

    // MARK: - Singleton
    static let shared = DownloadManagerService()

    // MARK: - Notification Names
    static let downloadProgressNotification = Notification.Name("DownloadProgressChanged")
    static let downloadStatusNotification = Notification.Name("DownloadStatusChanged")
    static let downloadCompletedNotification = Notification.Name("DownloadCompleted")
    static let downloadFailedNotification = Notification.Name("DownloadFailed")
    static let allDownloadsCompletedNotification = Notification.Name("AllDownloadsCompleted")
    static let downloadQueueUpdatedNotification = Notification.Name("DownloadQueueUpdated")

    // MARK: - Properties
    private let persistenceQueue = DispatchQueue(label: "com.channer.downloadmanager.persistence", attributes: .concurrent)
    private var urlSession: URLSession!
    private var backgroundCompletionHandler: (() -> Void)?

    /// All download items (in-memory cache)
    private var _downloadItems: [DownloadItem] = []
    private let itemsLock = NSLock()

    var downloadItems: [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems
    }

    /// Active download tasks mapped by download ID
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private let tasksLock = NSLock()

    /// Maximum concurrent downloads
    var maxConcurrentDownloads: Int = 3

    /// Storage path for persistence
    private var persistenceURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("DownloadState.json")
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        setupURLSession()
        loadPersistedDownloads()
        setupAppLifecycleObservers()
        // Resume interrupted downloads after a short delay to let app fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.resumeInterruptedDownloads()
        }
    }

    private func setupURLSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.channer.backgroundDownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600 // 1 hour max

        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    // MARK: - Public Queue Management Methods

    /// Adds a single download to the queue
    @discardableResult
    func queueDownload(url: URL, boardAbv: String, threadNumber: String) -> DownloadItem? {
        let destinationPath = "BatchDownloads/\(boardAbv)_\(threadNumber)/\(url.lastPathComponent)"
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let mediaType: DownloadMediaType = BatchImageDownloadManager.supportedVideoExtensions.contains(ext) ? .video : .image

        let item = DownloadItem(
            sourceURL: url,
            destinationPath: destinationPath,
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            filename: filename,
            mediaType: mediaType
        )

        itemsLock.lock()
        // Check for duplicates (same URL and not completed)
        if _downloadItems.contains(where: { $0.sourceURL == url && $0.status != .completed && $0.status != .cancelled }) {
            itemsLock.unlock()
            print("DEBUG: DownloadManagerService - Duplicate URL skipped: \(url)")
            return nil
        }
        _downloadItems.append(item)
        itemsLock.unlock()

        savePersistedDownloads()
        notifyQueueUpdated()
        processQueue()

        return item
    }

    /// Adds multiple downloads (batch) to the queue
    @discardableResult
    func queueBatchDownload(urls: [URL], boardAbv: String, threadNumber: String) -> [DownloadItem] {
        var addedItems: [DownloadItem] = []

        itemsLock.lock()
        for url in urls {
            let destinationPath = "BatchDownloads/\(boardAbv)_\(threadNumber)/\(url.lastPathComponent)"
            let filename = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            let mediaType: DownloadMediaType = BatchImageDownloadManager.supportedVideoExtensions.contains(ext) ? .video : .image

            // Skip duplicates
            if _downloadItems.contains(where: { $0.sourceURL == url && $0.status != .completed && $0.status != .cancelled }) {
                continue
            }

            let item = DownloadItem(
                sourceURL: url,
                destinationPath: destinationPath,
                boardAbv: boardAbv,
                threadNumber: threadNumber,
                filename: filename,
                mediaType: mediaType
            )

            _downloadItems.append(item)
            addedItems.append(item)
        }
        itemsLock.unlock()

        if !addedItems.isEmpty {
            savePersistedDownloads()
            notifyQueueUpdated()
            processQueue()
        }

        print("DEBUG: DownloadManagerService - Queued \(addedItems.count) downloads for /\(boardAbv)/\(threadNumber)")
        return addedItems
    }

    /// Pauses a specific download
    func pauseDownload(id: String) {
        tasksLock.lock()
        let task = activeTasks[id]
        tasksLock.unlock()

        guard task != nil else { return }

        task?.cancel(byProducingResumeData: { [weak self] data in
            guard let self = self else { return }

            self.itemsLock.lock()
            if let index = self._downloadItems.firstIndex(where: { $0.id == id }) {
                self._downloadItems[index].resumeData = data
                self._downloadItems[index].status = .paused
                self._downloadItems[index].pausedAt = Date()
                let item = self._downloadItems[index]
                self.itemsLock.unlock()

                self.savePersistedDownloads()
                self.notifyStatusChange(for: item)
            } else {
                self.itemsLock.unlock()
            }

            self.tasksLock.lock()
            self.activeTasks.removeValue(forKey: id)
            self.tasksLock.unlock()

            self.processQueue()
        })
    }

    /// Resumes a paused download
    func resumeDownload(id: String) {
        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == id }),
              _downloadItems[index].status == .paused || _downloadItems[index].status == .failed else {
            itemsLock.unlock()
            return
        }

        _downloadItems[index].status = .pending
        _downloadItems[index].errorMessage = nil
        itemsLock.unlock()

        savePersistedDownloads()
        processQueue()
    }

    /// Cancels a download
    func cancelDownload(id: String) {
        tasksLock.lock()
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
        }
        tasksLock.unlock()

        itemsLock.lock()
        if let index = _downloadItems.firstIndex(where: { $0.id == id }) {
            _downloadItems[index].status = .cancelled
            let item = _downloadItems[index]
            itemsLock.unlock()

            savePersistedDownloads()
            notifyStatusChange(for: item)
        } else {
            itemsLock.unlock()
        }

        processQueue()
    }

    /// Retries a failed download
    func retryDownload(id: String) {
        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == id }),
              _downloadItems[index].status == .failed || _downloadItems[index].status == .cancelled else {
            itemsLock.unlock()
            return
        }

        _downloadItems[index].status = .pending
        _downloadItems[index].errorMessage = nil
        _downloadItems[index].retryCount += 1
        _downloadItems[index].resumeData = nil  // Clear stale resume data
        _downloadItems[index].bytesDownloaded = 0
        itemsLock.unlock()

        savePersistedDownloads()
        processQueue()
    }

    /// Removes a download from the list (cleanup)
    func removeDownload(id: String) {
        cancelDownload(id: id)

        itemsLock.lock()
        _downloadItems.removeAll { $0.id == id }
        itemsLock.unlock()

        savePersistedDownloads()
        notifyQueueUpdated()
    }

    /// Clears completed downloads from the list
    func clearCompletedDownloads() {
        itemsLock.lock()
        _downloadItems.removeAll { $0.status == .completed }
        itemsLock.unlock()

        savePersistedDownloads()
        notifyQueueUpdated()
    }

    /// Clears all downloads (cancelled and failed too)
    func clearAllDownloads() {
        // Cancel all active tasks
        tasksLock.lock()
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        tasksLock.unlock()

        itemsLock.lock()
        _downloadItems.removeAll()
        itemsLock.unlock()

        savePersistedDownloads()
        notifyQueueUpdated()
    }

    /// Retries all failed downloads
    func retryAllFailed() {
        itemsLock.lock()
        for index in _downloadItems.indices where _downloadItems[index].status == .failed {
            _downloadItems[index].status = .pending
            _downloadItems[index].errorMessage = nil
            _downloadItems[index].retryCount += 1
            _downloadItems[index].resumeData = nil
            _downloadItems[index].bytesDownloaded = 0
        }
        itemsLock.unlock()

        savePersistedDownloads()
        processQueue()
    }

    /// Pauses all active downloads
    func pauseAllDownloads() {
        itemsLock.lock()
        let downloadingIds = _downloadItems.filter { $0.status == .downloading }.map { $0.id }
        itemsLock.unlock()

        for id in downloadingIds {
            pauseDownload(id: id)
        }
    }

    /// Resumes all paused downloads
    func resumeAllDownloads() {
        itemsLock.lock()
        for index in _downloadItems.indices where _downloadItems[index].status == .paused {
            _downloadItems[index].status = .pending
        }
        itemsLock.unlock()

        savePersistedDownloads()
        processQueue()
    }

    // MARK: - Download Processing

    private func processQueue() {
        tasksLock.lock()
        let activeCount = activeTasks.count
        tasksLock.unlock()

        let availableSlots = maxConcurrentDownloads - activeCount

        guard availableSlots > 0 else { return }

        itemsLock.lock()
        let pendingItems = _downloadItems.filter { $0.status == .pending }
        itemsLock.unlock()

        let itemsToStart = Array(pendingItems.prefix(availableSlots))

        for item in itemsToStart {
            startDownload(item)
        }
    }

    private func startDownload(_ item: DownloadItem) {
        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == item.id }) else {
            itemsLock.unlock()
            return
        }

        _downloadItems[index].status = .downloading
        _downloadItems[index].startedAt = Date()
        let currentItem = _downloadItems[index]
        itemsLock.unlock()

        savePersistedDownloads()
        notifyStatusChange(for: currentItem)

        var request = URLRequest(url: item.sourceURL)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        // 4chan specific headers
        if let host = item.sourceURL.host, host == "i.4cdn.org" {
            request.setValue("https://boards.4chan.org/\(item.boardAbv)/", forHTTPHeaderField: "Referer")
            request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
        }

        var task: URLSessionDownloadTask

        // Resume support using resume data or Range header
        if let resumeData = item.resumeData, !resumeData.isEmpty {
            task = urlSession.downloadTask(withResumeData: resumeData)
        } else if item.bytesDownloaded > 0 {
            request.setValue("bytes=\(item.bytesDownloaded)-", forHTTPHeaderField: "Range")
            task = urlSession.downloadTask(with: request)
        } else {
            task = urlSession.downloadTask(with: request)
        }

        task.taskDescription = item.id

        tasksLock.lock()
        activeTasks[item.id] = task
        tasksLock.unlock()

        task.resume()
    }

    private func resumeInterruptedDownloads() {
        // Resume downloads that were "downloading" when app terminated
        itemsLock.lock()
        var changed = false
        for index in _downloadItems.indices {
            if _downloadItems[index].status == .downloading {
                _downloadItems[index].status = .pending
                changed = true
            }
        }
        itemsLock.unlock()

        if changed {
            savePersistedDownloads()
            processQueue()
        }
    }

    // MARK: - Persistence

    private func loadPersistedDownloads() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }

        do {
            let data = try Data(contentsOf: persistenceURL)
            let items = try JSONDecoder().decode([DownloadItem].self, from: data)

            itemsLock.lock()
            _downloadItems = items
            itemsLock.unlock()

            print("DEBUG: DownloadManagerService - Loaded \(items.count) persisted downloads")
        } catch {
            print("DEBUG: DownloadManagerService - Failed to load persisted downloads: \(error)")
        }
    }

    private func savePersistedDownloads() {
        persistenceQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.itemsLock.lock()
            let items = self._downloadItems
            self.itemsLock.unlock()

            do {
                let data = try JSONEncoder().encode(items)
                try data.write(to: self.persistenceURL, options: .atomic)
            } catch {
                print("DEBUG: DownloadManagerService - Failed to save downloads: \(error)")
            }
        }
    }

    @objc private func appWillTerminate() {
        // Mark downloading items as interrupted for resume
        itemsLock.lock()
        for index in _downloadItems.indices where _downloadItems[index].status == .downloading {
            _downloadItems[index].status = .pending
        }
        itemsLock.unlock()

        // Synchronous save on termination
        itemsLock.lock()
        let items = _downloadItems
        itemsLock.unlock()

        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("DEBUG: DownloadManagerService - Failed to save on terminate: \(error)")
        }
    }

    @objc private func appDidEnterBackground() {
        savePersistedDownloads()
    }

    // MARK: - Background Session Handler

    func handleBackgroundSessionCompletion(handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }

    // MARK: - Query Methods

    func getDownloadsByThread(boardAbv: String, threadNumber: String) -> [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.boardAbv == boardAbv && $0.threadNumber == threadNumber }
    }

    func getActiveDownloads() -> [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.status == .downloading }
    }

    func getPendingDownloads() -> [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.status == .pending }
    }

    func getFailedDownloads() -> [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.status == .failed }
    }

    func getCompletedDownloads() -> [DownloadItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.status == .completed }
    }

    func getGroupedDownloads() -> [DownloadGroup] {
        itemsLock.lock()
        let items = _downloadItems
        itemsLock.unlock()

        let grouped = Dictionary(grouping: items) { "\($0.boardAbv)_\($0.threadNumber)" }
        return grouped.map { key, groupItems in
            let parts = key.split(separator: "_", maxSplits: 1)
            return DownloadGroup(
                id: key,
                boardAbv: String(parts.first ?? ""),
                threadNumber: String(parts.dropFirst().joined(separator: "_")),
                items: groupItems.sorted { $0.createdAt < $1.createdAt }
            )
        }.sorted { ($0.items.first?.createdAt ?? Date.distantPast) > ($1.items.first?.createdAt ?? Date.distantPast) }
    }

    func getActiveDownloadCount() -> Int {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.filter { $0.status == .downloading || $0.status == .pending }.count
    }

    func getTotalDownloadCount() -> Int {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _downloadItems.count
    }

    // MARK: - Notification Helpers

    private func notifyStatusChange(for item: DownloadItem) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.downloadStatusNotification,
                object: nil,
                userInfo: ["downloadId": item.id, "status": item.status.rawValue]
            )
        }
    }

    private func notifyProgress(for item: DownloadItem) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.downloadProgressNotification,
                object: nil,
                userInfo: ["downloadId": item.id, "progress": item.progress, "bytesDownloaded": item.bytesDownloaded, "totalBytes": item.totalBytes]
            )
        }
    }

    private func notifyQueueUpdated() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.downloadQueueUpdatedNotification, object: nil)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManagerService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadId = downloadTask.taskDescription else { return }

        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == downloadId }) else {
            itemsLock.unlock()
            return
        }
        let item = _downloadItems[index]
        itemsLock.unlock()

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(item.destinationPath)

        // Create directory if needed
        let directory = destinationURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("DEBUG: DownloadManagerService - Failed to create directory: \(error)")
        }

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: location, to: destinationURL)

            itemsLock.lock()
            if let idx = _downloadItems.firstIndex(where: { $0.id == downloadId }) {
                _downloadItems[idx].status = .completed
                _downloadItems[idx].completedAt = Date()
                if _downloadItems[idx].totalBytes > 0 {
                    _downloadItems[idx].bytesDownloaded = _downloadItems[idx].totalBytes
                }
                let completedItem = _downloadItems[idx]
                itemsLock.unlock()

                savePersistedDownloads()
                notifyStatusChange(for: completedItem)

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Self.downloadCompletedNotification,
                        object: nil,
                        userInfo: ["downloadId": downloadId, "path": destinationURL.path]
                    )
                }
            } else {
                itemsLock.unlock()
            }

            print("DEBUG: DownloadManagerService - Downloaded: \(item.filename)")

        } catch {
            print("DEBUG: DownloadManagerService - Failed to move file: \(error)")

            itemsLock.lock()
            if let idx = _downloadItems.firstIndex(where: { $0.id == downloadId }) {
                _downloadItems[idx].status = .failed
                _downloadItems[idx].errorMessage = error.localizedDescription
                let failedItem = _downloadItems[idx]
                itemsLock.unlock()

                savePersistedDownloads()
                notifyStatusChange(for: failedItem)
            } else {
                itemsLock.unlock()
            }
        }

        tasksLock.lock()
        activeTasks.removeValue(forKey: downloadId)
        tasksLock.unlock()

        processQueue()
        checkAllDownloadsCompleted()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let downloadId = downloadTask.taskDescription else { return }

        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == downloadId }) else {
            itemsLock.unlock()
            return
        }

        _downloadItems[index].bytesDownloaded = totalBytesWritten
        if totalBytesExpectedToWrite > 0 {
            _downloadItems[index].totalBytes = totalBytesExpectedToWrite
        }
        let item = _downloadItems[index]
        itemsLock.unlock()

        notifyProgress(for: item)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let downloadTask = task as? URLSessionDownloadTask,
              let downloadId = downloadTask.taskDescription else { return }

        let nsError = error as NSError

        itemsLock.lock()
        guard let index = _downloadItems.firstIndex(where: { $0.id == downloadId }) else {
            itemsLock.unlock()
            return
        }

        // Check if cancelled with resume data
        if nsError.code == NSURLErrorCancelled,
           let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            _downloadItems[index].resumeData = resumeData
            // Don't mark as failed if paused
            if _downloadItems[index].status != .paused {
                _downloadItems[index].status = .failed
                _downloadItems[index].errorMessage = "Cancelled"
            }
        } else {
            _downloadItems[index].status = .failed
            _downloadItems[index].errorMessage = error.localizedDescription
        }

        let item = _downloadItems[index]
        itemsLock.unlock()

        savePersistedDownloads()
        notifyStatusChange(for: item)

        tasksLock.lock()
        activeTasks.removeValue(forKey: downloadId)
        tasksLock.unlock()

        processQueue()
        checkAllDownloadsCompleted()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    private func checkAllDownloadsCompleted() {
        itemsLock.lock()
        let hasActiveOrPending = _downloadItems.contains { $0.status == .downloading || $0.status == .pending }
        itemsLock.unlock()

        if !hasActiveOrPending {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.allDownloadsCompletedNotification, object: nil)
            }
        }
    }
}
