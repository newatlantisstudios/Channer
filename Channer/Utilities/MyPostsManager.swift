import Foundation

/// Represents a post made by the user
struct UserPost: Codable, Equatable {
    let id: String
    let boardAbv: String
    let threadNo: String
    let postNo: String
    let timestamp: Date

    init(boardAbv: String, threadNo: String, postNo: String) {
        self.id = UUID().uuidString
        self.boardAbv = boardAbv
        self.threadNo = threadNo
        self.postNo = postNo
        self.timestamp = Date()
    }
}

/// Manages tracking of user's own posts for reply notifications
/// When a user posts, their post is stored here and automatically watched for replies
class MyPostsManager {
    static let shared = MyPostsManager()

    private let userPostsKey = "channer_user_posts"
    private let syncQueue = DispatchQueue(label: "com.channer.myposts.sync", attributes: .concurrent)

    private init() {}

    // MARK: - Post Management

    /// Gets all user posts
    func getUserPosts() -> [UserPost] {
        var result: [UserPost] = []
        syncQueue.sync {
            result = fetchUserPostsFromDefaults()
        }
        return result
    }

    /// Adds a user post and automatically watches it for replies
    /// - Parameters:
    ///   - boardAbv: Board abbreviation
    ///   - threadNo: Thread number
    ///   - postNo: The post number of the user's post
    ///   - postText: Text content of the post (for watch preview)
    ///   - existingReplies: Any existing replies to mark as known
    func addUserPost(boardAbv: String, threadNo: String, postNo: String, postText: String = "", existingReplies: [String] = []) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchUserPostsFromDefaults()

            // Don't add duplicates
            guard !posts.contains(where: { $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv }) else {
                return
            }

            let userPost = UserPost(boardAbv: boardAbv, threadNo: threadNo, postNo: postNo)
            posts.append(userPost)
            saveUserPosts(posts)
        }

        // Auto-watch this post for replies
        WatchedPostsManager.shared.watchPost(
            boardAbv: boardAbv,
            threadNo: threadNo,
            postNo: postNo,
            postText: postText.isEmpty ? "Your post" : postText,
            existingReplies: existingReplies
        )

        NotificationCenter.default.post(name: .userPostAdded, object: nil)
    }

    /// Checks if a post belongs to the user
    /// - Parameters:
    ///   - postNo: Post number
    ///   - threadNo: Thread number
    ///   - boardAbv: Board abbreviation
    /// - Returns: True if the post was made by the user
    func isUserPost(postNo: String, threadNo: String, boardAbv: String) -> Bool {
        return getUserPosts().contains {
            $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv
        }
    }

    /// Gets user posts for a specific thread
    func getUserPosts(forThread threadNo: String, board boardAbv: String) -> [UserPost] {
        return getUserPosts().filter { $0.threadNo == threadNo && $0.boardAbv == boardAbv }
    }

    /// Removes a user post record
    func removeUserPost(postNo: String, threadNo: String, boardAbv: String) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchUserPostsFromDefaults()
            posts.removeAll { $0.postNo == postNo && $0.threadNo == threadNo && $0.boardAbv == boardAbv }
            saveUserPosts(posts)
        }
    }

    /// Clears posts older than a specified date
    /// - Parameter date: Posts older than this will be removed
    func clearOldPosts(olderThan date: Date) {
        syncQueue.sync(flags: .barrier) {
            var posts = fetchUserPostsFromDefaults()
            let originalCount = posts.count
            posts.removeAll { $0.timestamp < date }

            if posts.count != originalCount {
                saveUserPosts(posts)
            }
        }
    }

    /// Clears all user post records
    func clearAllUserPosts() {
        syncQueue.sync(flags: .barrier) {
            saveUserPosts([])
        }
    }

    // MARK: - Private Methods

    private func fetchUserPostsFromDefaults() -> [UserPost] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: userPostsKey),
           let posts = try? JSONDecoder().decode([UserPost].self, from: data) {
            return posts
        }
        return []
    }

    private func saveUserPosts(_ posts: [UserPost]) {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(posts) {
            defaults.set(encoded, forKey: userPostsKey)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userPostAdded = Notification.Name("channer.userPostAdded")
}
