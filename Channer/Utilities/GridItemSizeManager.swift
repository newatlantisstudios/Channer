import UIKit

final class GridItemSizeManager {
    static let shared = GridItemSizeManager()

    private let gridItemSizeKey = "channer_grid_item_size_index"
    private let gridItemSizeMigrationKey = "channer_grid_item_size_migrated_v2"
    private let gridItemSizeMigrationV3Key = "channer_grid_item_size_migrated_v3"
    private let sizeOptions: [CGFloat] = [0.35, 0.5, 0.65, 0.8, 1.0, 1.15, 1.3]
    private let defaultSizeIndex = 4

    private init() {
        if UserDefaults.standard.object(forKey: gridItemSizeKey) == nil {
            UserDefaults.standard.set(defaultSizeIndex, forKey: gridItemSizeKey)
            UserDefaults.standard.set(true, forKey: gridItemSizeMigrationKey)
            UserDefaults.standard.set(true, forKey: gridItemSizeMigrationV3Key)
        } else {
            if !UserDefaults.standard.bool(forKey: gridItemSizeMigrationKey) {
                let storedIndex = UserDefaults.standard.integer(forKey: gridItemSizeKey)
                if storedIndex <= 2 {
                    UserDefaults.standard.set(storedIndex + 2, forKey: gridItemSizeKey)
                }
                UserDefaults.standard.set(true, forKey: gridItemSizeMigrationKey)
            }
            if !UserDefaults.standard.bool(forKey: gridItemSizeMigrationV3Key) {
                // sizeOptions gained two smaller entries at the front; shift saved index by +2 so
                // existing users keep the same physical scale.
                let storedIndex = UserDefaults.standard.integer(forKey: gridItemSizeKey)
                UserDefaults.standard.set(storedIndex + 2, forKey: gridItemSizeKey)
                UserDefaults.standard.set(true, forKey: gridItemSizeMigrationV3Key)
            }
        }
    }

    var sizeIndex: Int {
        clampIndex(UserDefaults.standard.integer(forKey: gridItemSizeKey))
    }

    var scaleFactor: CGFloat {
        sizeOptions[sizeIndex]
    }

    func setSizeIndex(_ index: Int) {
        let clampedIndex = clampIndex(index)
        guard clampedIndex != sizeIndex else { return }

        UserDefaults.standard.set(clampedIndex, forKey: gridItemSizeKey)
        NotificationCenter.default.post(name: .gridItemSizeDidChange, object: nil)
    }

    private func clampIndex(_ index: Int) -> Int {
        max(0, min(index, sizeOptions.count - 1))
    }
}

extension Notification.Name {
    static let gridItemSizeDidChange = Notification.Name("GridItemSizeDidChangeNotification")
}
