import UIKit

enum ThreadDisplayMode: Int {
    case list = 0
    case catalog = 1
}

struct ThreadViewControllerFactory {
    static let threadsDisplayModeKey = "channer_threads_display_mode"

    static func makeBoardViewController(boardName: String, boardAbv: String, boardPassed: Bool = true) -> UIViewController {
        let mode = UserDefaults.standard.integer(forKey: threadsDisplayModeKey)

        if mode == ThreadDisplayMode.catalog.rawValue {
            let catalogVC = threadCatalogCV(collectionViewLayout: UICollectionViewFlowLayout())
            catalogVC.boardName = boardName
            catalogVC.boardAbv = boardAbv
            catalogVC.boardPassed = boardPassed
            catalogVC.title = "/\(boardAbv)/"
            return catalogVC
        }

        let listVC = boardTV()
        listVC.boardName = boardName
        listVC.boardAbv = boardAbv
        listVC.boardPassed = boardPassed
        listVC.title = "/\(boardAbv)/"
        return listVC
    }
}
