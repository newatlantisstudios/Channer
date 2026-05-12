import UIKit

final class GalleryCellSizeManager {
    static let shared = GalleryCellSizeManager()

    private let galleryCellSizeKey = "channer_gallery_cell_size_index"
    private let galleryCellSizeMigrationV2Key = "channer_gallery_cell_size_migrated_v2"
    /// Number of columns for each size option: XXXS=8, XXS=7, XS=6, S=5, M=4, L=3, XL=2
    private let columnOptions: [CGFloat] = [8, 7, 6, 5, 4, 3, 2]
    private let defaultSizeIndex = 4

    private init() {
        let defaults = UserDefaults.standard
        let hasStoredSize = defaults.object(forKey: galleryCellSizeKey) != nil
        let hasMigrationFlag = defaults.object(forKey: galleryCellSizeMigrationV2Key) != nil

        defaults.register(defaults: [
            galleryCellSizeKey: defaultSizeIndex,
            galleryCellSizeMigrationV2Key: true
        ])

        if hasStoredSize && !hasMigrationFlag {
            // columnOptions gained two smaller entries at the front; shift saved index by +2
            // so existing users keep the same physical scale.
            let storedIndex = defaults.integer(forKey: galleryCellSizeKey)
            defaults.set(storedIndex + 2, forKey: galleryCellSizeKey)
            defaults.set(true, forKey: galleryCellSizeMigrationV2Key)
        }
    }

    var sizeIndex: Int {
        clampIndex(UserDefaults.standard.integer(forKey: galleryCellSizeKey))
    }

    var columns: CGFloat {
        columnOptions[sizeIndex]
    }

    func setSizeIndex(_ index: Int) {
        let clampedIndex = clampIndex(index)
        guard clampedIndex != sizeIndex else { return }

        UserDefaults.standard.set(clampedIndex, forKey: galleryCellSizeKey)
        NotificationCenter.default.post(name: .galleryCellSizeDidChange, object: nil)
    }

    private func clampIndex(_ index: Int) -> Int {
        max(0, min(index, columnOptions.count - 1))
    }
}

extension Notification.Name {
    static let galleryCellSizeDidChange = Notification.Name("GalleryCellSizeDidChangeNotification")
}
