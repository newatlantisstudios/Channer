import Foundation

struct MediaSettings {
    static let defaultMutedKey = "channer_media_default_muted"
    static let videoPreviewInDownloadsKey = "channer_video_preview_in_downloads"

    static var defaultMuted: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: defaultMutedKey) == nil {
                defaults.set(true, forKey: defaultMutedKey)
            }
            return defaults.bool(forKey: defaultMutedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultMutedKey)
        }
    }

    static var videoPreviewInDownloads: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: videoPreviewInDownloadsKey) == nil {
                defaults.set(false, forKey: videoPreviewInDownloadsKey)
            }
            return defaults.bool(forKey: videoPreviewInDownloadsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: videoPreviewInDownloadsKey)
        }
    }
}
