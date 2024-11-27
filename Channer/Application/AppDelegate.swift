import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    /// The main application window.
    var window: UIWindow?

    // MARK: - UIApplicationDelegate Methods
    /// Called when the application has finished launching.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupMainWindow()
        return true
    }

    // MARK: - Window Setup
    /// Sets up the main application window and root view controller.
    private func setupMainWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = createSplitViewController()
        window?.makeKeyAndVisible()
    }

    // MARK: - Split View Controller Setup
    /// Creates and configures the main split view controller.
    private func createSplitViewController() -> UISplitViewController {
        let splitViewController = CustomSplitViewController(style: .doubleColumn)
        splitViewController.setViewController(createMasterNavigationController(), for: .primary)
        splitViewController.setViewController(createDetailNavigationController(), for: .secondary)
        splitViewController.preferredDisplayMode = .oneOverSecondary
        return splitViewController
    }

    // MARK: - Navigation Controllers Creation
    /// Creates the master navigation controller for the primary column.
    private func createMasterNavigationController() -> UINavigationController {
        let masterController = boardsCV(collectionViewLayout: UICollectionViewFlowLayout())
        return UINavigationController(rootViewController: masterController)
    }

    /// Creates the detail navigation controller for the secondary column.
    private func createDetailNavigationController() -> UINavigationController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailController = storyboard.instantiateViewController(withIdentifier: "boardTV") as? boardTV else {
            fatalError("Could not instantiate boardTV from storyboard.")
        }
        return UINavigationController(rootViewController: detailController)
    }
}
