import UIKit

final class ThumbnailSizeManager {
    static let shared = ThumbnailSizeManager()

    private let thumbnailSizeKey = "channer_thumbnail_size_index"
    private let sizeOptions: [CGFloat] = [80, 100, 120, 150, 180, 220]

    private init() {
        if UserDefaults.standard.object(forKey: thumbnailSizeKey) == nil {
            UserDefaults.standard.set(2, forKey: thumbnailSizeKey) // Default: L (120)
        }
    }

    var sizeIndex: Int {
        clampIndex(UserDefaults.standard.integer(forKey: thumbnailSizeKey))
    }

    var thumbnailSize: CGFloat {
        sizeOptions[sizeIndex]
    }

    /// Cell height for board thread cells: thumbnail + insets + stats row
    var boardCellHeight: CGFloat {
        thumbnailSize + 46 // 14 top inset + 4 gap + 21 stats + 7 bottom
    }

    /// Minimum cell height for thread reply cells
    var replyCellMinHeight: CGFloat {
        thumbnailSize + 52 // 18 corner inset + ~20 reply count + 8 gap + ~6 bottom
    }

    func setSizeIndex(_ index: Int) {
        let clampedIndex = clampIndex(index)
        guard clampedIndex != sizeIndex else { return }

        UserDefaults.standard.set(clampedIndex, forKey: thumbnailSizeKey)
        NotificationCenter.default.post(name: .thumbnailSizeDidChange, object: nil)
    }

    private func clampIndex(_ index: Int) -> Int {
        max(0, min(index, sizeOptions.count - 1))
    }
}

extension Notification.Name {
    static let thumbnailSizeDidChange = Notification.Name("ThumbnailSizeDidChangeNotification")
}
