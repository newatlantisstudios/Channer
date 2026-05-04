import UIKit
import ObjectiveC.runtime

extension UIViewController {
    private static let installAppearanceLogging: Void = {
        let original = #selector(UIViewController.viewDidAppear(_:))
        let swizzled = #selector(UIViewController.channer_loggedViewDidAppear(_:))
        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    static func enableAppearanceLogging() {
        _ = installAppearanceLogging
    }

    @objc func channer_loggedViewDidAppear(_ animated: Bool) {
        channer_loggedViewDidAppear(animated)
        guard Bundle(for: type(of: self)) == Bundle.main else { return }
        print("[VC] \(String(describing: type(of: self))) appeared")
    }
}
