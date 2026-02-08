import UIKit

final class GalleryCellSizeManager {
    static let shared = GalleryCellSizeManager()

    private let galleryCellSizeKey = "channer_gallery_cell_size_index"
    /// Number of columns for each size option: XS=6, S=5, M=4, L=3, XL=2
    private let columnOptions: [CGFloat] = [6, 5, 4, 3, 2]

    private init() {
        if UserDefaults.standard.object(forKey: galleryCellSizeKey) == nil {
            UserDefaults.standard.set(2, forKey: galleryCellSizeKey) // Default: M (4 columns)
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
