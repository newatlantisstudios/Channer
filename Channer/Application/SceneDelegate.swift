import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        window.rootViewController = appDelegate?.createRootNavigationController()
        window.makeKeyAndVisible()

        self.window = window
        appDelegate?.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        BackgroundTaskManager.shared.scheduleAllTasks()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        if appDelegate?.window === window {
            appDelegate?.window = nil
        }
        window = nil
    }
}
