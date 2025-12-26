import Foundation

/// Represents a post that the user wants to watch for replies
struct WatchedPost: Codable, Equatable {
    let id: String
    let boardAbv: String
    let threadNo: String
    let postNo: String
    let postText: String  // Preview of the post content
    let timestamp: Date
    var knownReplies: [String]  // Post numbers that have already replied to this post

    init(boardAbv: String, threadNo: String, postNo: String, postText: String, knownReplies: [String] = []) {
        self.id = UUID().uuidString
        self.boardAbv = boardAbv
        self.threadNo = threadNo
        self.postNo = postNo
        self.postText = String(postText.prefix(100))  // Store preview only
        self.timestamp = Date()
        self.knownReplies = knownReplies
    }
}

/// Manages posts that the user wants to watch for replies
/// When new replies to watched posts are detected, creates ReplyNotification objects
class WatchedPostsManager {
    static let shared = WatchedPostsManager()

    private let watchedPostsKey = "channer_watched_posts"
    private let syncQueue = DispatchQueue(label: "com.channer.watchedposts.sync", attributes: .concurrent)

    private init() {}

    // MARK: - Watch Management

    /// Gets all watched posts
    func getWatchedPosts() -> [WatchedPost] {
        var result: [WatchedPost] = []
        syncQueue.sync {
            result = fetchWatchedPostsFromDefaults()
        }
        return result
    }

    /// Gets watched posts for a specific thread
    func getWatchedPosts(forThread threadNo: String, board boardAbv: String) -> [WatchedPost] {
        return getWatchedPosts().filter { $0.threadNo == threadNo && $0.boardAbv == boardAbv }
    }

    /// Checks if a specific post is being watched
    func isWatching(postNo: String, threadNo: String, boardAbv: String) -> Bool {
        return getWatchedPosts().contains {
            $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv
        }
    }

    /// Adds a post to watch for replies
    func watchPost(boardAbv: String, threadNo: String, postNo: String, postText: String, existingReplies: [String] = []) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchWatchedPostsFromDefaults()

            // Don't add duplicates
            guard !posts.contains(where: { $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv }) else {
                return
            }

            let watchedPost = WatchedPost(
                boardAbv: boardAbv,
                threadNo: threadNo,
                postNo: postNo,
                postText: postText,
                knownReplies: existingReplies
            )
            posts.append(watchedPost)
            saveWatchedPosts(posts)
        }

        NotificationCenter.default.post(name: .watchedPostAdded, object: nil)
    }

    /// Removes a post from watch list
    func unwatchPost(postNo: String, threadNo: String, boardAbv: String) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchWatchedPostsFromDefaults()
            posts.removeAll { $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv }
            saveWatchedPosts(posts)
        }

        NotificationCenter.default.post(name: .watchedPostRemoved, object: nil)
    }

    /// Removes all watched posts for a thread (e.g., when thread is deleted)
    func unwatchAllPosts(forThread threadNo: String, board boardAbv: String) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchWatchedPostsFromDefaults()
            posts.removeAll { $0.threadNo == threadNo && $0.boardAbv == boardAbv }
            saveWatchedPosts(posts)
        }
    }

    /// Clears all watched posts
    func clearAllWatchedPosts() {
        syncQueue.sync(flags: .barrier) {
            saveWatchedPosts([])
        }

        NotificationCenter.default.post(name: .watchedPostRemoved, object: nil)
    }

    // MARK: - Reply Detection

    /// Checks for new replies to watched posts and creates notifications
    /// - Parameters:
    ///   - threadNo: The thread number
    ///   - boardAbv: The board abbreviation
    ///   - threadReplies: Array of reply texts (NSAttributedString)
    ///   - replyNumbers: Array of post numbers corresponding to each reply
    /// - Returns: Number of new reply notifications created
    @discardableResult
    func checkForNewReplies(
        threadNo: String,
        boardAbv: String,
        threadReplies: [NSAttributedString],
        replyNumbers: [String]
    ) -> Int {
        let watchedPosts = getWatchedPosts(forThread: threadNo, board: boardAbv)
        guard !watchedPosts.isEmpty else { return 0 }

        var newNotificationCount = 0
        var updatedWatchedPosts: [WatchedPost] = []

        for var watchedPost in watchedPosts {
            var foundNewReplies = false

            // Check each reply to see if it references this watched post
            for (index, reply) in threadReplies.enumerated() {
                guard index < replyNumbers.count else { continue }

                let replyText = reply.string
                let replyNo = replyNumbers[index]

                // Skip if this is the watched post itself
                guard replyNo != watchedPost.postNo else { continue }

                // Check if this reply references the watched post
                if replyText.contains(">>\(watchedPost.postNo)") {
                    // Check if we've already notified about this reply
                    if !watchedPost.knownReplies.contains(replyNo) {
                        // Determine notification type based on whether this is the user's own post
                        let isUserOwnPost = MyPostsManager.shared.isUserPost(
                            postNo: watchedPost.postNo,
                            threadNo: threadNo,
                            boardAbv: boardAbv
                        )
                        let notificationType: NotificationType = isUserOwnPost ? .myPostReply : .watchedPostReply

                        // New reply found! Create notification
                        let notification = ReplyNotification(
                            boardAbv: boardAbv,
                            threadNo: threadNo,
                            replyNo: replyNo,
                            replyToNo: watchedPost.postNo,
                            replyText: String(replyText.prefix(150)),
                            notificationType: notificationType
                        )
                        NotificationManager.shared.addNotification(notification)

                        // Mark this reply as known
                        watchedPost.knownReplies.append(replyNo)
                        foundNewReplies = true
                        newNotificationCount += 1
                    }
                }
            }

            if foundNewReplies {
                updatedWatchedPosts.append(watchedPost)
            }
        }

        // Update watched posts with new known replies
        if !updatedWatchedPosts.isEmpty {
            syncQueue.sync(flags: .barrier) {
                var allPosts = fetchWatchedPostsFromDefaults()
                for updatedPost in updatedWatchedPosts {
                    if let index = allPosts.firstIndex(where: {
                        $0.postNo == updatedPost.postNo &&
                        $0.threadNo == updatedPost.threadNo &&
                        $0.boardAbv == updatedPost.boardAbv
                    }) {
                        allPosts[index] = updatedPost
                    }
                }
                saveWatchedPosts(allPosts)
            }
        }

        return newNotificationCount
    }

    // MARK: - Private Methods

    private func fetchWatchedPostsFromDefaults() -> [WatchedPost] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: watchedPostsKey),
           let posts = try? JSONDecoder().decode([WatchedPost].self, from: data) {
            return posts
        }
        return []
    }

    private func saveWatchedPosts(_ posts: [WatchedPost]) {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(posts) {
            defaults.set(encoded, forKey: watchedPostsKey)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchedPostAdded = Notification.Name("channer.watchedPostAdded")
    static let watchedPostRemoved = Notification.Name("channer.watchedPostRemoved")
}
