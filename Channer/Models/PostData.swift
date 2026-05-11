import Foundation

/// Data model for post submission to 4chan
struct PostData {
    private static let deletionPasswordKey = "channer_deletion_password"

    /// Board abbreviation (e.g., "g", "v", "a")
    let board: String

    /// Thread number for replies (0 for new threads)
    let resto: Int

    /// Poster name (optional, defaults to Anonymous)
    var name: String?

    /// Email field (can contain options like "sage")
    var email: String?

    /// Subject line (primarily for new threads)
    var subject: String?

    /// Post comment text
    let comment: String

    /// Image data for file upload (optional for replies, required for new threads on most boards)
    var imageData: Data?

    /// Original filename for the uploaded image
    var imageFilename: String?

    /// MIME type for the uploaded image
    var imageMimeType: String?

    /// Whether the image should be marked as a spoiler
    var spoiler: Bool = false

    /// 4chan TCaptcha challenge id, required when posting without Pass
    var captchaChallenge: String?

    /// 4chan TCaptcha response, when the challenge requires one
    var captchaResponse: String?

    /// Whether this is a new thread (resto == 0)
    var isNewThread: Bool {
        return resto == 0
    }

    /// Generate a random deletion password
    static func generatePassword() -> String {
        if let existingPassword = UserDefaults.standard.string(forKey: deletionPasswordKey),
           !existingPassword.isEmpty {
            return existingPassword
        }

        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let password = String((0..<8).map { _ in characters.randomElement()! })
        UserDefaults.standard.set(password, forKey: deletionPasswordKey)
        return password
    }

    /// Stored deletion password used for posts submitted from this app.
    static func storedDeletionPassword() -> String? {
        guard let password = UserDefaults.standard.string(forKey: deletionPasswordKey),
              !password.isEmpty else {
            return nil
        }

        return password
    }
}
