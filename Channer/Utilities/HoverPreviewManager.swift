import UIKit

final class HoverPreviewManager {
    static let shared = HoverPreviewManager()

    private let videoSoundKey = "channer_hover_video_sound_enabled"
    private let videoSizeKey = "channer_hover_video_size_index"
    private let imageSizeKey = "channer_hover_image_size_index"

    private let isIPad = UIDevice.current.userInterfaceIdiom == .pad

    // Video sizes: iPad [450, 550, 650, 750], iPhone [350, 450, 550, 650]
    private var videoSizeOptions: [CGFloat] {
        isIPad ? [450, 550, 650, 750] : [350, 450, 550, 650]
    }

    // Image sizes: iPad [550, 650, 750, 850, 950], iPhone [450, 550, 650, 750, 850]
    private var imageSizeOptions: [CGFloat] {
        isIPad ? [550, 650, 750, 850, 950] : [450, 550, 650, 750, 850]
    }

    private init() {
        if UserDefaults.standard.object(forKey: videoSoundKey) == nil {
            UserDefaults.standard.set(false, forKey: videoSoundKey)
        }
        if UserDefaults.standard.object(forKey: videoSizeKey) == nil {
            UserDefaults.standard.set(2, forKey: videoSizeKey) // Default: L
        }
        if UserDefaults.standard.object(forKey: imageSizeKey) == nil {
            UserDefaults.standard.set(3, forKey: imageSizeKey) // Default: XL
        }
    }

    var videoSoundEnabled: Bool {
        UserDefaults.standard.bool(forKey: videoSoundKey)
    }

    var videoSizeIndex: Int {
        clampIndex(UserDefaults.standard.integer(forKey: videoSizeKey), max: videoSizeOptions.count - 1)
    }

    var imageSizeIndex: Int {
        clampIndex(UserDefaults.standard.integer(forKey: imageSizeKey), max: imageSizeOptions.count - 1)
    }

    var videoPreviewSize: CGFloat {
        videoSizeOptions[videoSizeIndex]
    }

    var imagePreviewSize: CGFloat {
        imageSizeOptions[imageSizeIndex]
    }

    func setVideoSoundEnabled(_ enabled: Bool) {
        guard enabled != videoSoundEnabled else { return }
        UserDefaults.standard.set(enabled, forKey: videoSoundKey)
        NotificationCenter.default.post(name: .hoverPreviewSettingsDidChange, object: nil)
    }

    func setVideoSizeIndex(_ index: Int) {
        let clamped = clampIndex(index, max: videoSizeOptions.count - 1)
        guard clamped != videoSizeIndex else { return }
        UserDefaults.standard.set(clamped, forKey: videoSizeKey)
        NotificationCenter.default.post(name: .hoverPreviewSettingsDidChange, object: nil)
    }

    func setImageSizeIndex(_ index: Int) {
        let clamped = clampIndex(index, max: imageSizeOptions.count - 1)
        guard clamped != imageSizeIndex else { return }
        UserDefaults.standard.set(clamped, forKey: imageSizeKey)
        NotificationCenter.default.post(name: .hoverPreviewSettingsDidChange, object: nil)
    }

    private func clampIndex(_ index: Int, max: Int) -> Int {
        Swift.max(0, Swift.min(index, max))
    }
}

extension Notification.Name {
    static let hoverPreviewSettingsDidChange = Notification.Name("HoverPreviewSettingsDidChangeNotification")
}
