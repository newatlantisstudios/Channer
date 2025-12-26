import Foundation
import BackgroundTasks
import UIKit
import Alamofire
import SwiftyJSON

/// Manages background tasks for thread refresh and watched posts checking
/// Uses the modern BGTaskScheduler API (iOS 13+)
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // MARK: - Task Identifiers
    static let threadRefreshTaskIdentifier = "com.newatlantisstudios.channer.threadRefresh"
    static let watchedPostsTaskIdentifier = "com.newatlantisstudios.channer.watchedPostsCheck"

    private init() {}

    // MARK: - Task Registration

    /// Registers all background task handlers with BGTaskScheduler
    /// Must be called in application(_:didFinishLaunchingWithOptions:) before app finishes launching
    func registerTasks() {
        // Register app refresh task for quick favorite checks (~30 sec window)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.threadRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleThreadRefreshTask(task as! BGAppRefreshTask)
        }

        // Register processing task for watched posts check (longer execution window)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.watchedPostsTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleWatchedPostsTask(task as! BGProcessingTask)
        }

        print("BackgroundTaskManager: Registered background tasks")
    }

    // MARK: - Task Scheduling

    /// Schedules the thread refresh task
    /// Called when app enters background
    func scheduleThreadRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.threadRefreshTaskIdentifier)
        // Request to run no earlier than 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Scheduled thread refresh task")
        } catch {
            print("BackgroundTaskManager: Failed to schedule thread refresh task: \(error.localizedDescription)")
        }
    }

    /// Schedules the watched posts processing task
    /// Called when app enters background
    func scheduleWatchedPostsTask() {
        let request = BGProcessingTaskRequest(identifier: Self.watchedPostsTaskIdentifier)
        // Request to run no earlier than 30 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        // This task requires network connectivity
        request.requiresNetworkConnectivity = true
        // This task can run on battery power
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Scheduled watched posts task")
        } catch {
            print("BackgroundTaskManager: Failed to schedule watched posts task: \(error.localizedDescription)")
        }
    }

    /// Schedules all background tasks
    /// Called when app enters background
    func scheduleAllTasks() {
        // Only schedule if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else {
            print("BackgroundTaskManager: Notifications disabled, skipping task scheduling")
            return
        }

        scheduleThreadRefreshTask()

        // Only schedule watched posts task if there are watched posts
        if !WatchedPostsManager.shared.getWatchedPosts().isEmpty {
            scheduleWatchedPostsTask()
        }
    }

    // MARK: - Task Handlers

    /// Handles the thread refresh background task
    /// Checks favorited threads for new replies (~30 sec execution window)
    private func handleThreadRefreshTask(_ task: BGAppRefreshTask) {
        print("BackgroundTaskManager: Starting thread refresh task")

        // Schedule the next refresh
        scheduleThreadRefreshTask()

        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else {
            task.setTaskCompleted(success: true)
            return
        }

        // Load favorites
        let favorites = FavoritesManager.shared.loadFavorites()
        guard !favorites.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        // Create a task to check for updates
        let checkTask = Task {
            await checkForThreadUpdates(favorites)
        }

        // Handle task expiration
        task.expirationHandler = {
            checkTask.cancel()
            print("BackgroundTaskManager: Thread refresh task expired")
        }

        // Wait for completion
        Task {
            _ = await checkTask.value
            task.setTaskCompleted(success: true)
            print("BackgroundTaskManager: Thread refresh task completed")
        }
    }

    /// Handles the watched posts processing task
    /// Fetches full thread content and checks for replies to watched posts
    private func handleWatchedPostsTask(_ task: BGProcessingTask) {
        print("BackgroundTaskManager: Starting watched posts task")

        // Schedule the next check
        scheduleWatchedPostsTask()

        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else {
            task.setTaskCompleted(success: true)
            return
        }

        // Get watched posts
        let watchedPosts = WatchedPostsManager.shared.getWatchedPosts()
        guard !watchedPosts.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        // Create a task to check watched posts
        let checkTask = Task {
            await checkWatchedPosts(watchedPosts)
        }

        // Handle task expiration
        task.expirationHandler = {
            checkTask.cancel()
            print("BackgroundTaskManager: Watched posts task expired")
        }

        // Wait for completion
        Task {
            _ = await checkTask.value
            task.setTaskCompleted(success: true)
            print("BackgroundTaskManager: Watched posts task completed")
        }
    }

    // MARK: - Thread Update Checking

    /// Checks for updates to favorited threads
    private func checkForThreadUpdates(_ favorites: [ThreadData]) async {
        await withTaskGroup(of: Void.self) { group in
            for favorite in favorites {
                group.addTask {
                    await self.checkSingleThread(favorite)
                }
            }
        }
    }

    /// Checks a single thread for updates
    private func checkSingleThread(_ favorite: ThreadData) async {
        let url = "https://a.4cdn.org/\(favorite.boardAbv)/thread/\(favorite.number).json"

        do {
            let data = try await AF.request(url).serializingData().value
            let json = try JSON(data: data)

            guard let firstPost = json["posts"].array?.first else { return }

            let currentReplies = firstPost["replies"].intValue
            let storedReplies = favorite.replies

            if currentReplies > storedReplies {
                let newReplies = currentReplies - storedReplies

                // Update the thread in favorites
                var updatedThread = favorite
                updatedThread.currentReplies = currentReplies
                updatedThread.hasNewReplies = true

                await MainActor.run {
                    FavoritesManager.shared.updateFavorite(thread: updatedThread)
                    updateApplicationBadgeCount()
                }

                // Send notification
                sendThreadUpdateNotification(
                    threadNumber: favorite.number,
                    boardAbv: favorite.boardAbv,
                    newReplies: newReplies
                )
            }
        } catch {
            print("BackgroundTaskManager: Failed to check thread \(favorite.number): \(error.localizedDescription)")
        }
    }

    // MARK: - Watched Posts Checking

    /// Checks all watched posts for new replies
    private func checkWatchedPosts(_ watchedPosts: [WatchedPost]) async {
        // Group watched posts by thread
        var threadGroups: [String: [WatchedPost]] = [:]
        for post in watchedPosts {
            let key = "\(post.boardAbv)/\(post.threadNo)"
            if threadGroups[key] == nil {
                threadGroups[key] = []
            }
            threadGroups[key]?.append(post)
        }

        // Check each thread
        await withTaskGroup(of: Void.self) { group in
            for (_, posts) in threadGroups {
                guard let firstPost = posts.first else { continue }
                group.addTask {
                    await self.checkThreadForWatchedPostReplies(
                        boardAbv: firstPost.boardAbv,
                        threadNo: firstPost.threadNo,
                        watchedPosts: posts
                    )
                }
            }
        }
    }

    /// Fetches a thread and checks for replies to watched posts
    private func checkThreadForWatchedPostReplies(
        boardAbv: String,
        threadNo: String,
        watchedPosts: [WatchedPost]
    ) async {
        let url = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNo).json"

        do {
            let data = try await AF.request(url).serializingData().value
            let json = try JSON(data: data)

            guard let posts = json["posts"].array else { return }

            // Extract reply texts and numbers
            var replyTexts: [NSAttributedString] = []
            var replyNumbers: [String] = []

            for post in posts {
                let postNo = String(post["no"].intValue)
                let comment = post["com"].stringValue

                replyNumbers.append(postNo)
                replyTexts.append(NSAttributedString(string: comment))
            }

            // Check for new replies to watched posts
            let newReplyCount = WatchedPostsManager.shared.checkForNewReplies(
                threadNo: threadNo,
                boardAbv: boardAbv,
                threadReplies: replyTexts,
                replyNumbers: replyNumbers
            )

            if newReplyCount > 0 {
                // Send push notification for watched post replies
                sendWatchedPostNotification(
                    boardAbv: boardAbv,
                    threadNo: threadNo,
                    replyCount: newReplyCount
                )
            }
        } catch {
            print("BackgroundTaskManager: Failed to check watched posts in thread \(threadNo): \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications

    /// Sends a notification for thread updates
    private func sendThreadUpdateNotification(threadNumber: String, boardAbv: String, newReplies: Int) {
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Thread Update"
        content.body = "Thread /\(boardAbv)/\(threadNumber) has \(newReplies) new \(newReplies == 1 ? "reply" : "replies")"
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "threadNumber": threadNumber,
            "boardAbv": boardAbv
        ]

        let identifier = "thread-\(boardAbv)-\(threadNumber)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundTaskManager: Error sending thread notification: \(error.localizedDescription)")
            }
        }
    }

    /// Sends a notification for watched post replies
    private func sendWatchedPostNotification(boardAbv: String, threadNo: String, replyCount: Int) {
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Watched Post Reply"
        content.body = "Your watched post in /\(boardAbv)/\(threadNo) has \(replyCount) new \(replyCount == 1 ? "reply" : "replies")"
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "threadNumber": threadNo,
            "boardAbv": boardAbv,
            "isWatchedPostReply": true
        ]

        let identifier = "watched-\(boardAbv)-\(threadNo)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundTaskManager: Error sending watched post notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Badge Management

    /// Updates the application badge count
    private func updateApplicationBadgeCount() {
        guard UserDefaults.standard.bool(forKey: "channer_notifications_enabled") else {
            UIApplication.shared.applicationIconBadgeNumber = 0
            return
        }

        let favorites = FavoritesManager.shared.loadFavorites()
        let threadsWithNewReplies = favorites.filter { $0.hasNewReplies }
        let badgeCount = threadsWithNewReplies.count

        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }
    }
}
