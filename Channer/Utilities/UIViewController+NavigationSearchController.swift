import UIKit

extension UIViewController {
    func installNavigationSearchControllerIfNeeded(_ searchController: UISearchController, onAttach: (() -> Void)? = nil) {
        let vcName = String(describing: type(of: self))
#if targetEnvironment(macCatalyst)
        print("[NavSearchExt] installNavigationSearchControllerIfNeeded called on \(vcName) (macCatalyst) — hasCoordinator=\(transitionCoordinator != nil) currentlySet=\(navigationItem.searchController != nil)")
        let attachSearchController = { [weak self] in
            guard let self else {
                print("[NavSearchExt] attachSearchController — self is nil")
                return
            }
            guard self.isViewLoaded, self.view.window != nil else {
                print("[NavSearchExt] attachSearchController — view not loaded or no window")
                return
            }
            guard self.navigationController?.topViewController === self else {
                print("[NavSearchExt] attachSearchController — not top VC")
                return
            }
            guard self.navigationItem.searchController !== searchController else {
                print("[NavSearchExt] attachSearchController — already set, skipping")
                return
            }
            print("[NavSearchExt] attachSearchController — calling onAttach and setting searchController on \(vcName)")
            onAttach?()
            self.navigationItem.searchController = searchController
            print("[NavSearchExt] attachSearchController — done, searchController is now set")
        }

        if let coordinator = transitionCoordinator {
            print("[NavSearchExt] deferring to transitionCoordinator completion")
            coordinator.animate(alongsideTransition: nil) { context in
                print("[NavSearchExt] transitionCoordinator completion — cancelled=\(context.isCancelled)")
                guard !context.isCancelled else { return }
                DispatchQueue.main.async(execute: attachSearchController)
            }
        } else {
            print("[NavSearchExt] no coordinator, dispatching async")
            DispatchQueue.main.async(execute: attachSearchController)
        }
        return
#else
        print("[NavSearchExt] installNavigationSearchControllerIfNeeded called on \(vcName) (non-macCatalyst) — currentlySet=\(navigationItem.searchController != nil)")
        guard navigationItem.searchController !== searchController else {
            print("[NavSearchExt] already set, skipping")
            return
        }
        print("[NavSearchExt] setting searchController directly on \(vcName)")
        onAttach?()
        navigationItem.searchController = searchController
#endif
    }

    func suspendNavigationSearchControllerForTransition() {
        let vcName = String(describing: type(of: self))
#if targetEnvironment(macCatalyst)
        guard let searchController = navigationItem.searchController else {
            print("[NavSearchExt] suspendNavigationSearchControllerForTransition on \(vcName) — no searchController to suspend")
            return
        }
        print("[NavSearchExt] suspendNavigationSearchControllerForTransition on \(vcName) — suspending, hasCoordinator=\(transitionCoordinator != nil)")
        view.endEditing(true)
        searchController.searchBar.resignFirstResponder()
        if searchController.isActive {
            searchController.isActive = false
        }

        let detachSearchController = { [weak self] in
            guard let self else { return }
            guard self.navigationItem.searchController === searchController else {
                print("[NavSearchExt] detachSearchController — searchController already changed, skipping")
                return
            }
            print("[NavSearchExt] detachSearchController — removing searchController from \(vcName)")
            self.navigationItem.searchController = nil
        }

        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { context in
                guard !context.isCancelled else { return }
                DispatchQueue.main.async(execute: detachSearchController)
            }
        } else {
            DispatchQueue.main.async(execute: detachSearchController)
        }
#else
        // On iOS, leaving the search bar focused/active during a pop produces a
        // visible "snap" as the nav bar resizes. Just resign focus and deactivate
        // — the searchController stays attached to navigationItem so the pop
        // animates smoothly.
        guard let searchController = navigationItem.searchController else {
            print("[NavSearchExt] suspendNavigationSearchControllerForTransition on \(vcName) — no searchController (iOS)")
            return
        }
        view.endEditing(true)
        searchController.searchBar.resignFirstResponder()
        if searchController.isActive {
            searchController.isActive = false
        }
#endif
    }
}
