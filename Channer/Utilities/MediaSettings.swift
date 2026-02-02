import Foundation

struct MediaSettings {
    static let defaultMutedKey = "channer_media_default_muted"

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
}
