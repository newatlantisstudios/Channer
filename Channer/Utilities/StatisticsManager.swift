import Foundation
import UIKit

// MARK: - Statistics Data Models

/// Represents a single board visit event
struct BoardVisit: Codable {
    let boardAbv: String
    let timestamp: Date
    let duration: TimeInterval // in seconds
}

/// Represents a thread view event
struct ThreadView: Codable {
    let threadNumber: String
    let boardAbv: String
    let timestamp: Date
    let duration: TimeInterval // in seconds
}

/// Aggregated statistics for a board
struct BoardStatistics: Codable {
    let boardAbv: String
    var visitCount: Int
    var totalTimeSpent: TimeInterval // in seconds
    var lastVisited: Date
}

/// Activity data for a specific hour of the day
struct HourlyActivity: Codable {
    let hour: Int // 0-23
    var visitCount: Int
}

/// Daily activity summary
struct DailyActivity: Codable {
    let date: Date
    var threadViews: Int
    var boardVisits: Int
    var totalTimeSpent: TimeInterval
}

/// Storage usage breakdown
struct StorageUsage: Codable {
    var cachedThreadsSize: Int64 // in bytes
    var cachedImagesSize: Int64
    var downloadedMediaSize: Int64
    var totalSize: Int64
    var lastCalculated: Date
}

/// Complete user statistics
struct UserStatistics: Codable {
    var boardVisits: [BoardVisit]
    var threadViews: [ThreadView]
    var boardStats: [String: BoardStatistics] // keyed by boardAbv
    var hourlyActivity: [Int: HourlyActivity] // keyed by hour (0-23)
    var dailyActivity: [DailyActivity]
    var storageUsage: StorageUsage?
    var totalThreadsViewed: Int
    var totalBoardsVisited: Int
    var totalTimeSpent: TimeInterval
    var firstRecordedDate: Date?
    var lastUpdated: Date

    init() {
        self.boardVisits = []
        self.threadViews = []
        self.boardStats = [:]
        self.hourlyActivity = [:]
        self.dailyActivity = []
        self.storageUsage = nil
        self.totalThreadsViewed = 0
        self.totalBoardsVisited = 0
        self.totalTimeSpent = 0
        self.firstRecordedDate = nil
        self.lastUpdated = Date()
    }
}

// MARK: - Statistics Manager

/// Singleton manager for tracking and storing user browsing statistics
class StatisticsManager {

    // MARK: - Singleton Instance
    static let shared = StatisticsManager()

    // MARK: - Properties
    private let statisticsKey = "channer_user_statistics"
    private let syncQueue = DispatchQueue(label: "com.channer.statistics.sync", attributes: .concurrent)

    private var statistics: UserStatistics
    private var currentSessionStart: Date?
    private var currentBoardAbv: String?
    private var currentThreadNumber: String?
    private var threadViewStartTime: Date?

    // MARK: - Notification Names
    static let statisticsUpdatedNotification = Notification.Name("StatisticsUpdatedNotification")

    // MARK: - Initialization
    private init() {
        statistics = UserStatistics()
        loadStatistics()
        setupObservers()
    }

    // MARK: - Setup
    private func setupObservers() {
        // Track app lifecycle for session management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        // Save current session when app goes to background
        endCurrentThreadView()
        saveStatistics()
    }

    @objc private func appDidBecomeActive() {
        currentSessionStart = Date()
    }

    // MARK: - Persistence
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: statisticsKey),
           let loadedStats = try? JSONDecoder().decode(UserStatistics.self, from: data) {
            statistics = loadedStats
            print("Loaded statistics: \(statistics.totalThreadsViewed) threads viewed, \(statistics.totalBoardsVisited) boards visited")
        } else {
            statistics = UserStatistics()
            statistics.firstRecordedDate = Date()
        }
    }

    private func saveStatistics() {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.statistics.lastUpdated = Date()
            if let data = try? JSONEncoder().encode(self.statistics) {
                UserDefaults.standard.set(data, forKey: self.statisticsKey)
            }
        }
    }

    // MARK: - Board Tracking

    /// Record a board visit
    func recordBoardVisit(boardAbv: String) {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let visit = BoardVisit(
                boardAbv: boardAbv,
                timestamp: Date(),
                duration: 0 // Will be updated when leaving the board
            )

            self.statistics.boardVisits.append(visit)

            // Update board statistics
            if var boardStat = self.statistics.boardStats[boardAbv] {
                boardStat.visitCount += 1
                boardStat.lastVisited = Date()
                self.statistics.boardStats[boardAbv] = boardStat
            } else {
                self.statistics.boardStats[boardAbv] = BoardStatistics(
                    boardAbv: boardAbv,
                    visitCount: 1,
                    totalTimeSpent: 0,
                    lastVisited: Date()
                )
                self.statistics.totalBoardsVisited += 1
            }

            // Update hourly activity
            let hour = Calendar.current.component(.hour, from: Date())
            if var hourlyActivity = self.statistics.hourlyActivity[hour] {
                hourlyActivity.visitCount += 1
                self.statistics.hourlyActivity[hour] = hourlyActivity
            } else {
                self.statistics.hourlyActivity[hour] = HourlyActivity(hour: hour, visitCount: 1)
            }

            self.currentBoardAbv = boardAbv
            self.saveStatistics()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: StatisticsManager.statisticsUpdatedNotification, object: nil)
            }
        }
    }

    // MARK: - Thread Tracking

    /// Start tracking a thread view
    func startThreadView(threadNumber: String, boardAbv: String) {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // End previous thread view if any
            self.endCurrentThreadViewInternal()

            self.currentThreadNumber = threadNumber
            self.currentBoardAbv = boardAbv
            self.threadViewStartTime = Date()
        }
    }

    /// End tracking the current thread view
    func endCurrentThreadView() {
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.endCurrentThreadViewInternal()
        }
    }

    private func endCurrentThreadViewInternal() {
        guard let threadNumber = currentThreadNumber,
              let boardAbv = currentBoardAbv,
              let startTime = threadViewStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)

        let threadView = ThreadView(
            threadNumber: threadNumber,
            boardAbv: boardAbv,
            timestamp: startTime,
            duration: duration
        )

        statistics.threadViews.append(threadView)
        statistics.totalThreadsViewed += 1
        statistics.totalTimeSpent += duration

        // Update board time spent
        if var boardStat = statistics.boardStats[boardAbv] {
            boardStat.totalTimeSpent += duration
            statistics.boardStats[boardAbv] = boardStat
        }

        // Update daily activity
        updateDailyActivity(threadView: true, duration: duration)

        // Clear current tracking
        currentThreadNumber = nil
        threadViewStartTime = nil

        saveStatistics()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: StatisticsManager.statisticsUpdatedNotification, object: nil)
        }
    }

    private func updateDailyActivity(threadView: Bool, duration: TimeInterval) {
        let today = Calendar.current.startOfDay(for: Date())

        if let index = statistics.dailyActivity.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            var activity = statistics.dailyActivity[index]
            if threadView {
                activity.threadViews += 1
            } else {
                activity.boardVisits += 1
            }
            activity.totalTimeSpent += duration
            statistics.dailyActivity[index] = activity
        } else {
            let newActivity = DailyActivity(
                date: today,
                threadViews: threadView ? 1 : 0,
                boardVisits: threadView ? 0 : 1,
                totalTimeSpent: duration
            )
            statistics.dailyActivity.append(newActivity)
        }

        // Keep only last 30 days of daily activity
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        statistics.dailyActivity = statistics.dailyActivity.filter { $0.date >= thirtyDaysAgo }
    }

    // MARK: - Storage Usage

    /// Calculate and update storage usage
    func calculateStorageUsage(completion: @escaping (StorageUsage) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var cachedThreadsSize: Int64 = 0
            var cachedImagesSize: Int64 = 0
            var downloadedMediaSize: Int64 = 0

            let fileManager = FileManager.default

            // Calculate cached threads size
            if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                cachedThreadsSize = self.sizeOfDirectory(at: cacheDirectory.appendingPathComponent("ThreadCache"))
                cachedImagesSize = self.sizeOfDirectory(at: cacheDirectory.appendingPathComponent("com.onevcat.Kingfisher.ImageCache.default"))
            }

            // Calculate downloaded media size
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                downloadedMediaSize = self.sizeOfDirectory(at: documentsDirectory.appendingPathComponent("Downloads"))
            }

            let totalSize = cachedThreadsSize + cachedImagesSize + downloadedMediaSize

            let storageUsage = StorageUsage(
                cachedThreadsSize: cachedThreadsSize,
                cachedImagesSize: cachedImagesSize,
                downloadedMediaSize: downloadedMediaSize,
                totalSize: totalSize,
                lastCalculated: Date()
            )

            self.syncQueue.async(flags: .barrier) {
                self.statistics.storageUsage = storageUsage
                self.saveStatistics()
            }

            DispatchQueue.main.async {
                completion(storageUsage)
            }
        }
    }

    private func sizeOfDirectory(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    // MARK: - Getters

    /// Get all statistics
    func getStatistics() -> UserStatistics {
        var result: UserStatistics!
        syncQueue.sync {
            result = statistics
        }
        return result
    }

    /// Get top visited boards
    func getTopBoards(limit: Int = 10) -> [BoardStatistics] {
        var result: [BoardStatistics] = []
        syncQueue.sync {
            result = Array(statistics.boardStats.values.sorted { $0.visitCount > $1.visitCount }.prefix(limit))
        }
        return result
    }

    /// Get hourly activity for visualization
    func getHourlyActivity() -> [HourlyActivity] {
        var result: [HourlyActivity] = []
        syncQueue.sync {
            // Fill in missing hours with zero counts
            for hour in 0..<24 {
                if let activity = statistics.hourlyActivity[hour] {
                    result.append(activity)
                } else {
                    result.append(HourlyActivity(hour: hour, visitCount: 0))
                }
            }
        }
        return result.sorted { $0.hour < $1.hour }
    }

    /// Get daily activity for the last N days
    func getDailyActivity(days: Int = 7) -> [DailyActivity] {
        var result: [DailyActivity] = []
        syncQueue.sync {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            result = statistics.dailyActivity
                .filter { $0.date >= cutoffDate }
                .sorted { $0.date < $1.date }
        }
        return result
    }

    /// Get total time spent formatted as string
    func getFormattedTotalTime() -> String {
        var totalTime: TimeInterval = 0
        syncQueue.sync {
            totalTime = statistics.totalTimeSpent
        }
        return formatTimeInterval(totalTime)
    }

    /// Get storage usage
    func getStorageUsage() -> StorageUsage? {
        var result: StorageUsage?
        syncQueue.sync {
            result = statistics.storageUsage
        }
        return result
    }

    // MARK: - Formatting Helpers

    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Data Management

    /// Clear all statistics
    func clearAllStatistics() {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.statistics = UserStatistics()
            self.statistics.firstRecordedDate = Date()
            self.saveStatistics()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: StatisticsManager.statisticsUpdatedNotification, object: nil)
            }
        }
    }

    /// Export statistics as JSON string
    func exportStatistics() -> String? {
        var result: String?
        syncQueue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(statistics) {
                result = String(data: data, encoding: .utf8)
            }
        }
        return result
    }
}
