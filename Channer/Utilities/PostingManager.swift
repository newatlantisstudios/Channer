import Foundation
import Alamofire

/// Manages post submission to 4chan
class PostingManager {

    static let shared = PostingManager()

    private let syncQueue = DispatchQueue(label: "com.channer.postingmanager.sync", attributes: .concurrent)

    /// Base URL for posting
    private let postingBaseURL = "https://sys.4chan.org"

    /// Last post time for rate limiting
    private var lastPostTime: Date?

    /// Minimum time between posts (in seconds)
    private let minimumPostInterval: TimeInterval = 30

    private init() {}

    // MARK: - Public Methods

    /// Submit a post to 4chan
    /// - Parameters:
    ///   - postData: The post data to submit
    ///   - completion: Callback with the result
    func submitPost(_ postData: PostData, completion: @escaping (Result<PostResult, PostingError>) -> Void) {
        // Check authentication
        guard PassAuthManager.shared.isAuthenticated else {
            completion(.failure(.notAuthenticated))
            return
        }

        // Validate post data
        if let validationError = validatePost(postData) {
            completion(.failure(validationError))
            return
        }

        // Check rate limiting
        if let lastTime = lastPostTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumPostInterval {
                completion(.failure(.rateLimited))
                return
            }
        }

        // Build URL
        let url = "\(postingBaseURL)/\(postData.board)/post"

        // Generate deletion password
        let password = PostData.generatePassword()

        // Build headers with cookies
        var headers: HTTPHeaders = [
            "Referer": "https://boards.4chan.org/\(postData.board)/",
            "Origin": "https://boards.4chan.org"
        ]

        // Add cookie header
        if let cookieHeader = PassAuthManager.shared.getCookieHeader() {
            headers.add(name: "Cookie", value: cookieHeader)
        }

        // Upload with multipart form data
        AF.upload(multipartFormData: { multipartFormData in
            // Required fields
            multipartFormData.append("regist".data(using: .utf8)!, withName: "mode")
            multipartFormData.append(String(postData.resto).data(using: .utf8)!, withName: "resto")
            multipartFormData.append(password.data(using: .utf8)!, withName: "pwd")

            // Comment (required)
            multipartFormData.append(postData.comment.data(using: .utf8)!, withName: "com")

            // Optional fields
            if let name = postData.name, !name.isEmpty {
                multipartFormData.append(name.data(using: .utf8)!, withName: "name")
            }

            if let email = postData.email, !email.isEmpty {
                multipartFormData.append(email.data(using: .utf8)!, withName: "email")
            }

            if let subject = postData.subject, !subject.isEmpty {
                multipartFormData.append(subject.data(using: .utf8)!, withName: "sub")
            }

            // Image upload
            if let imageData = postData.imageData,
               let filename = postData.imageFilename,
               let mimeType = postData.imageMimeType {
                multipartFormData.append(imageData, withName: "upfile", fileName: filename, mimeType: mimeType)
            }

            // Spoiler flag
            if postData.spoiler {
                multipartFormData.append("on".data(using: .utf8)!, withName: "spoiler")
            }

        }, to: url, headers: headers)
        .responseData { [weak self] response in
            self?.handlePostResponse(response, completion: completion)
        }
    }

    /// Submit a reply to a thread
    /// - Parameters:
    ///   - board: Board abbreviation
    ///   - threadNumber: Thread number to reply to
    ///   - comment: Reply comment text
    ///   - name: Optional poster name
    ///   - email: Optional email/options
    ///   - imageData: Optional image data
    ///   - imageFilename: Optional image filename
    ///   - imageMimeType: Optional image MIME type
    ///   - spoiler: Whether to spoiler the image
    ///   - completion: Callback with result
    func submitReply(
        board: String,
        threadNumber: Int,
        comment: String,
        name: String? = nil,
        email: String? = nil,
        imageData: Data? = nil,
        imageFilename: String? = nil,
        imageMimeType: String? = nil,
        spoiler: Bool = false,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        let postData = PostData(
            board: board,
            resto: threadNumber,
            name: name,
            email: email,
            subject: nil,
            comment: comment,
            imageData: imageData,
            imageFilename: imageFilename,
            imageMimeType: imageMimeType,
            spoiler: spoiler
        )

        submitPost(postData, completion: completion)
    }

    /// Submit a new thread
    /// - Parameters:
    ///   - board: Board abbreviation
    ///   - subject: Thread subject
    ///   - comment: Thread comment text
    ///   - name: Optional poster name
    ///   - email: Optional email/options
    ///   - imageData: Required image data
    ///   - imageFilename: Image filename
    ///   - imageMimeType: Image MIME type
    ///   - spoiler: Whether to spoiler the image
    ///   - completion: Callback with result
    func submitNewThread(
        board: String,
        subject: String?,
        comment: String,
        name: String? = nil,
        email: String? = nil,
        imageData: Data,
        imageFilename: String,
        imageMimeType: String,
        spoiler: Bool = false,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        let postData = PostData(
            board: board,
            resto: 0,
            name: name,
            email: email,
            subject: subject,
            comment: comment,
            imageData: imageData,
            imageFilename: imageFilename,
            imageMimeType: imageMimeType,
            spoiler: spoiler
        )

        submitPost(postData, completion: completion)
    }

    // MARK: - Private Methods

    /// Validate post data before submission
    private func validatePost(_ postData: PostData) -> PostingError? {
        // Check board
        if postData.board.isEmpty {
            return .invalidBoard
        }

        // Check comment (allow empty if image is attached)
        if postData.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           postData.imageData == nil {
            return .emptyComment
        }

        // Check image for new threads (most boards require it)
        if postData.isNewThread && postData.imageData == nil {
            return .imageRequired
        }

        // Check image size (4MB limit for most boards)
        if let imageData = postData.imageData {
            let maxSize = 4 * 1024 * 1024 // 4MB
            if imageData.count > maxSize {
                return .imageTooLarge
            }
        }

        return nil
    }

    /// Handle the response from the posting request
    private func handlePostResponse(
        _ response: AFDataResponse<Data>,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        switch response.result {
        case .success(let data):
            // Parse HTML response
            let htmlString = String(data: data, encoding: .utf8) ?? ""

            // Check for success
            if let postNumber = parseSuccessResponse(htmlString) {
                lastPostTime = Date()
                completion(.success(PostResult.success(postNumber: postNumber)))
                return
            }

            // Check for thread creation success
            if let threadNumber = parseThreadCreationResponse(htmlString) {
                lastPostTime = Date()
                completion(.success(PostResult.success(threadNumber: threadNumber)))
                return
            }

            // Check for error
            if let errorMessage = parseErrorResponse(htmlString) {
                // Check for specific errors
                if errorMessage.lowercased().contains("banned") {
                    completion(.failure(.banned))
                } else if errorMessage.lowercased().contains("wait") ||
                          errorMessage.lowercased().contains("flood") {
                    completion(.failure(.rateLimited))
                } else if errorMessage.lowercased().contains("closed") {
                    completion(.failure(.threadClosed))
                } else if errorMessage.lowercased().contains("archived") {
                    completion(.failure(.threadArchived))
                } else {
                    completion(.failure(.serverError(errorMessage)))
                }
                return
            }

            // Unknown response
            completion(.failure(.serverError("Unknown server response")))

        case .failure(let error):
            completion(.failure(.networkError(error)))
        }
    }

    /// Parse success response to extract post number
    private func parseSuccessResponse(_ html: String) -> Int? {
        // Look for patterns like "Post successful" or redirect with post number
        // 4chan returns HTML with meta refresh or JavaScript redirect

        // Pattern 1: Meta refresh with thread/post number
        // <meta http-equiv="refresh" content="1;URL=https://boards.4chan.org/g/thread/12345#p67890">
        if let range = html.range(of: "#p(\\d+)", options: .regularExpression) {
            let postNumberStr = html[range].dropFirst(2) // Remove "#p"
            return Int(postNumberStr)
        }

        // Pattern 2: JavaScript redirect
        // location.href = "https://boards.4chan.org/g/thread/12345#p67890"
        if let range = html.range(of: "thread/\\d+#p(\\d+)", options: .regularExpression) {
            let match = html[range]
            if let pRange = match.range(of: "#p(\\d+)", options: .regularExpression) {
                let postNumberStr = match[pRange].dropFirst(2)
                return Int(postNumberStr)
            }
        }

        return nil
    }

    /// Parse thread creation response to extract thread number
    private func parseThreadCreationResponse(_ html: String) -> Int? {
        // For new threads, look for the thread number in redirect
        // location.href = "https://boards.4chan.org/g/thread/12345"
        if let range = html.range(of: "thread/(\\d+)(?:[^#]|$)", options: .regularExpression) {
            let match = html[range]
            if let numRange = match.range(of: "\\d+", options: .regularExpression) {
                return Int(match[numRange])
            }
        }

        return nil
    }

    /// Parse error response to extract error message
    private func parseErrorResponse(_ html: String) -> String? {
        // Look for error message in HTML
        // Pattern 1: <span id="errmsg">Error message</span>
        if let range = html.range(of: "(?<=id=\"errmsg\"[^>]*>)[^<]+", options: .regularExpression) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Pattern 2: <font color=red><b>Error message</b></font>
        if let range = html.range(of: "(?<=<b>Error:)[^<]+", options: .regularExpression) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Pattern 3: General error text
        if let range = html.range(of: "(?<=<body[^>]*>)[^<]+Error[^<]+", options: .regularExpression) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Check if it's an error page at all
        if html.lowercased().contains("error") && !html.contains("thread/") {
            // Try to extract any text from body
            if let bodyStart = html.range(of: "<body"),
               let bodyEnd = html.range(of: "</body>") {
                let content = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
                let stripped = content.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if stripped.count < 300 {
                    return stripped
                }
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    /// Get MIME type for image file extension
    static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webm":
            return "video/webm"
        case "mp4", "m4v":
            return "video/mp4"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }
}
