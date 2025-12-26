import Foundation

/// Result of a post submission attempt
struct PostResult {
    /// Whether the post was submitted successfully
    let success: Bool

    /// The post number if successful (for replies)
    let postNumber: Int?

    /// The thread number if successful (for new threads)
    let threadNumber: Int?

    /// Error message if the post failed
    let errorMessage: String?

    /// Create a successful result
    static func success(postNumber: Int? = nil, threadNumber: Int? = nil) -> PostResult {
        return PostResult(success: true, postNumber: postNumber, threadNumber: threadNumber, errorMessage: nil)
    }

    /// Create a failure result
    static func failure(_ message: String) -> PostResult {
        return PostResult(success: false, postNumber: nil, threadNumber: nil, errorMessage: message)
    }
}

/// Common posting errors
enum PostingError: Error, LocalizedError {
    case notAuthenticated
    case invalidBoard
    case emptyComment
    case imageRequired
    case imageTooLarge
    case networkError(Error)
    case serverError(String)
    case rateLimited
    case banned
    case threadClosed
    case threadArchived

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in with a 4chan Pass to post"
        case .invalidBoard:
            return "Invalid board specified"
        case .emptyComment:
            return "Post comment cannot be empty"
        case .imageRequired:
            return "An image is required to start a new thread"
        case .imageTooLarge:
            return "Image file size exceeds the maximum allowed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .rateLimited:
            return "Please wait before posting again"
        case .banned:
            return "You are banned from posting"
        case .threadClosed:
            return "This thread is closed"
        case .threadArchived:
            return "This thread is archived"
        }
    }
}
