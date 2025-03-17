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
        setupAppearance()
        setupMainWindow()
        return true
    }
    
    // MARK: - Appearance Setup
    /// Sets up the global appearance for UI elements.
    private func setupAppearance() {
        // Configure navigation bar appearance for both light and dark modes
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Apply the appearance settings to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }
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
        let detailController = boardTV()
        return UINavigationController(rootViewController: detailController)
    }
}
