import Foundation

struct MediaSettings {
    static let defaultMutedKey = "channer_media_default_muted"
    static let videoPreviewInDownloadsKey = "channer_video_preview_in_downloads"
    static let defaultVideoVolumeKey = "channer_media_default_video_volume"
    static let webMMetadataKey = "channer_media_webm_metadata_enabled"
    static let revealSpoilerThumbnailsKey = "channer_media_reveal_spoiler_thumbnails"
    static let replaceGIFThumbnailsKey = "channer_media_replace_gif_thumbnails"
    static let replaceJPGThumbnailsKey = "channer_media_replace_jpg_thumbnails"
    static let replacePNGThumbnailsKey = "channer_media_replace_png_thumbnails"
    static let replaceVideoThumbnailsKey = "channer_media_replace_video_thumbnails"
    static let hidePostsWithoutImagesKey = "channer_media_hide_posts_without_images"
    static let hideAllImagesKey = "channer_media_hide_all_images"
    static let mouseWheelVolumeKey = "channer_media_mouse_wheel_volume"
    static let soundPostsKey = "channer_media_sound_posts_enabled"
    static let pdfInGalleryKey = "channer_media_pdf_in_gallery"

    private static let registeredDefaults: Void = {
        UserDefaults.standard.register(defaults: [
            defaultMutedKey: true,
            videoPreviewInDownloadsKey: false,
            defaultVideoVolumeKey: 0.5,
            webMMetadataKey: true,
            revealSpoilerThumbnailsKey: false,
            replaceGIFThumbnailsKey: false,
            replaceJPGThumbnailsKey: false,
            replacePNGThumbnailsKey: false,
            replaceVideoThumbnailsKey: false,
            hidePostsWithoutImagesKey: false,
            hideAllImagesKey: false,
            mouseWheelVolumeKey: true,
            soundPostsKey: false,
            pdfInGalleryKey: false
        ])
    }()

    private static func bool(for key: String, default _: Bool) -> Bool {
        _ = registeredDefaults
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func setBool(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static var defaultMuted: Bool {
        get {
            bool(for: defaultMutedKey, default: true)
        }
        set {
            setBool(newValue, for: defaultMutedKey)
        }
    }

    static var videoPreviewInDownloads: Bool {
        get {
            bool(for: videoPreviewInDownloadsKey, default: false)
        }
        set {
            setBool(newValue, for: videoPreviewInDownloadsKey)
        }
    }

    static var defaultVideoVolume: Float {
        get {
            _ = Self.registeredDefaults
            return max(0, min(1, UserDefaults.standard.float(forKey: defaultVideoVolumeKey)))
        }
        set {
            UserDefaults.standard.set(max(0, min(1, newValue)), forKey: defaultVideoVolumeKey)
        }
    }

    static var defaultVLCVolume: Int32 {
        Int32((defaultVideoVolume * 100).rounded())
    }

    static var webMMetadataEnabled: Bool {
        get { bool(for: webMMetadataKey, default: true) }
        set { setBool(newValue, for: webMMetadataKey) }
    }

    static var revealSpoilerThumbnails: Bool {
        get { bool(for: revealSpoilerThumbnailsKey, default: false) }
        set { setBool(newValue, for: revealSpoilerThumbnailsKey) }
    }

    static var replaceGIFThumbnails: Bool {
        get { bool(for: replaceGIFThumbnailsKey, default: false) }
        set { setBool(newValue, for: replaceGIFThumbnailsKey) }
    }

    static var replaceJPGThumbnails: Bool {
        get { bool(for: replaceJPGThumbnailsKey, default: false) }
        set { setBool(newValue, for: replaceJPGThumbnailsKey) }
    }

    static var replacePNGThumbnails: Bool {
        get { bool(for: replacePNGThumbnailsKey, default: false) }
        set { setBool(newValue, for: replacePNGThumbnailsKey) }
    }

    static var replaceVideoThumbnails: Bool {
        get { bool(for: replaceVideoThumbnailsKey, default: false) }
        set { setBool(newValue, for: replaceVideoThumbnailsKey) }
    }

    static var hidePostsWithoutImages: Bool {
        get { bool(for: hidePostsWithoutImagesKey, default: false) }
        set { setBool(newValue, for: hidePostsWithoutImagesKey) }
    }

    static var hideAllImages: Bool {
        get { bool(for: hideAllImagesKey, default: false) }
        set { setBool(newValue, for: hideAllImagesKey) }
    }

    static var mouseWheelVolumeEnabled: Bool {
        get { bool(for: mouseWheelVolumeKey, default: true) }
        set { setBool(newValue, for: mouseWheelVolumeKey) }
    }

    static var soundPostsEnabled: Bool {
        get { bool(for: soundPostsKey, default: false) }
        set { setBool(newValue, for: soundPostsKey) }
    }

    static var pdfInGallery: Bool {
        get { bool(for: pdfInGalleryKey, default: false) }
        set { setBool(newValue, for: pdfInGalleryKey) }
    }

    static func isSupportedGalleryURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return pdfInGallery
        }
        return ["jpg", "jpeg", "png", "gif", "webm", "mp4"].contains(ext)
    }

    static func shouldReplaceThumbnail(forExtension ext: String) -> Bool {
        switch ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) {
        case "jpg", "jpeg":
            return replaceJPGThumbnails
        case "png":
            return replacePNGThumbnails
        case "gif":
            return replaceGIFThumbnails
        case "webm", "mp4":
            return replaceVideoThumbnails
        default:
            return false
        }
    }

    static func thumbnailURL(from raw: String, useHighQuality: Bool, isSpoiler: Bool = false) -> URL? {
        if isSpoiler && !revealSpoilerThumbnails {
            return URL(string: "https://s.4cdn.org/image/spoiler.png")
        }

        guard let url = URL(string: raw) else { return nil }
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            return nil
        }

        if ext == "webm" || ext == "mp4" {
            return suffixThumbnailURL(from: raw, replacingExtension: ext)
        }

        if useHighQuality || shouldReplaceThumbnail(forExtension: ext) {
            return url
        }

        return suffixThumbnailURL(from: raw, replacingExtension: ext) ?? url
    }

    private static func suffixThumbnailURL(from raw: String, replacingExtension ext: String) -> URL? {
        let comps = raw.split(separator: "/")
        guard let last = comps.last, let dot = last.firstIndex(of: ".") else {
            return URL(string: raw)
        }
        let filename = String(last[..<dot]) + "s.jpg"
        return URL(string: raw.replacingOccurrences(of: String(last), with: filename))
    }

    static func soundPostURL(from filename: String?) -> URL? {
        guard soundPostsEnabled,
              let filename = filename,
              let range = filename.range(of: #"\[sound=([^\]]+)\]"#, options: .regularExpression) else {
            return nil
        }

        let token = String(filename[range])
            .replacingOccurrences(of: "[sound=", with: "")
            .replacingOccurrences(of: "]", with: "")

        if let url = URL(string: token), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(token)")
    }
}

final class WebMMetadataFetcher {
    static let shared = WebMMetadataFetcher()

    private let queue = DispatchQueue(label: "com.channer.webmMetadata", qos: .utility)
    private var cache: [URL: String?] = [:]

    private init() {}

    func fetchTitle(for url: URL, completion: @escaping (String?) -> Void) {
        queue.async {
            if self.cache.keys.contains(url) {
                let cached = self.cache[url] ?? nil
                DispatchQueue.main.async { completion(cached) }
                return
            }

            var request = URLRequest(url: url)
            request.setValue("bytes=0-9999", forHTTPHeaderField: "Range")

            URLSession.shared.dataTask(with: request) { data, _, _ in
                let title = data.flatMap { Self.parseTitle(from: [UInt8]($0)) }
                self.queue.async {
                    self.cache[url] = title
                    DispatchQueue.main.async { completion(title) }
                }
            }.resume()
        }
    }

    private static func parseTitle(from bytes: [UInt8]) -> String? {
        var index = 0

        func readInt() -> Int? {
            guard index < bytes.count else { return nil }
            var value = Int(bytes[index])
            index += 1
            var length = 0
            while length < 8 && value < (0x80 >> length) {
                length += 1
            }
            value ^= (0x80 >> length)
            while length > 0 && index < bytes.count {
                value = (value << 8) ^ Int(bytes[index])
                index += 1
                length -= 1
            }
            return value
        }

        while index < bytes.count {
            guard let element = readInt(), let size = readInt() else { return nil }
            if element == 0x3BA9 {
                guard index + size <= bytes.count else { return nil }
                let titleBytes = Array(bytes[index..<(index + size)])
                return String(data: Data(titleBytes), encoding: .utf8)
            }
            if element != 0x8538067 && element != 0x549A966 {
                index = min(bytes.count, index + size)
            }
        }

        return nil
    }
}
