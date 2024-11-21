import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupMainWindow()
        return true
    }

    private func setupMainWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = createSplitViewController()
        window?.makeKeyAndVisible()
    }

    private func createSplitViewController() -> UISplitViewController {
        let splitViewController = CustomSplitViewController(style: .doubleColumn)
        splitViewController.setViewController(createMasterNavigationController(), for: .primary)
        splitViewController.setViewController(createDetailNavigationController(), for: .secondary)
        splitViewController.preferredDisplayMode = .oneOverSecondary
        return splitViewController
    }

    private func createMasterNavigationController() -> UINavigationController {
        let masterController = boardsCV(collectionViewLayout: UICollectionViewFlowLayout())
        return UINavigationController(rootViewController: masterController)
    }

    private func createDetailNavigationController() -> UINavigationController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailController = storyboard.instantiateViewController(withIdentifier: "boardTV") as? boardTV else {
            fatalError("Could not instantiate boardTV from storyboard.")
        }
        return UINavigationController(rootViewController: detailController)
    }
}
