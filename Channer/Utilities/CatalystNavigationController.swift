import UIKit

extension UIBarButtonItem {
    static func bottomToolbarFlexibleSpace() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    static func bottomToolbarFixedSpace(_ width: CGFloat) -> UIBarButtonItem {
        let item = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        item.width = width
        return item
    }
}

struct BottomToolbarItemGroup {
    let items: [UIBarButtonItem]

    init(_ items: [UIBarButtonItem]) {
        self.items = items
    }
}

protocol BottomToolbarConfigurable: AnyObject {
    var bottomToolbarItemGroups: [BottomToolbarItemGroup] { get }
    var prefersBottomToolbarHidden: Bool { get }
}

extension BottomToolbarConfigurable {
    var prefersBottomToolbarHidden: Bool {
        return false
    }
}

protocol BottomToolbarSearchProviding: AnyObject {
    var bottomToolbarSearchController: UISearchController? { get }
    var bottomToolbarSearchInitiallyExpanded: Bool { get }
}

extension BottomToolbarSearchProviding {
    var bottomToolbarSearchInitiallyExpanded: Bool {
        return false
    }
}

class CatalystNavigationController: UINavigationController, UINavigationControllerDelegate {

    private lazy var bottomBackButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(bottomBackButtonTapped)
        )
        item.accessibilityLabel = "Back"
        return item
    }()

    private lazy var bottomSearchButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            barButtonSystemItem: .search,
            target: self,
            action: #selector(bottomSearchButtonTapped)
        )
        item.accessibilityLabel = "Search"
        return item
    }()

    private lazy var bottomSearchCancelButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(bottomSearchCancelButtonTapped)
        )
        item.accessibilityLabel = "Close Search"
        return item
    }()

    private var activeSearchController: UISearchController?
    private var activeSearchOwner: UIViewController?
    private var isBottomSearchExpanded = false
    private var lastToolbarSignature = ""

    #if targetEnvironment(macCatalyst)
    private var mouseMonitor: AnyObject?
    private var hasHandledSwipeBack = false
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        configureBottomToolbarChrome()
        syncBottomToolbar(animated: false)

        #if targetEnvironment(macCatalyst)
        setupMouseBackButton()
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureBottomToolbarChrome()
        syncBottomToolbar(animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncBottomToolbar(animated: false)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        collapseBottomSearchIfNeeded()
        super.pushViewController(viewController, animated: animated)
        scheduleBottomToolbarSync(animated: animated)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        collapseBottomSearchIfNeeded()
        let poppedViewController = super.popViewController(animated: animated)
        scheduleBottomToolbarSync(animated: animated)
        return poppedViewController
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        collapseBottomSearchIfNeeded()
        let poppedViewControllers = super.popToRootViewController(animated: animated)
        scheduleBottomToolbarSync(animated: animated)
        return poppedViewControllers
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        collapseBottomSearchIfNeeded()
        super.setViewControllers(viewControllers, animated: animated)
        scheduleBottomToolbarSync(animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        syncBottomToolbar(animated: animated)
    }

    private func configureBottomToolbarChrome() {
        setNavigationBarHidden(true, animated: false)
        navigationBar.isHidden = true
        setToolbarHidden(false, animated: false)

        if #available(iOS 26.0, *) {
            return
        } else {
            let appearance = UIToolbarAppearance()
            appearance.configureWithDefaultBackground()
            toolbar.standardAppearance = appearance
            toolbar.scrollEdgeAppearance = appearance
            toolbar.compactAppearance = appearance
            if #available(iOS 15.0, *) {
                toolbar.compactScrollEdgeAppearance = appearance
            }
        }
    }

    private func scheduleBottomToolbarSync(animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.syncBottomToolbar(animated: animated)
        }
    }

    private func syncBottomToolbar(animated: Bool) {
        guard let viewController = topViewController else { return }

        configureBottomToolbarChrome()

        if activeSearchOwner !== viewController {
            isBottomSearchExpanded = false
            activeSearchController = nil
            activeSearchOwner = nil
        }

        if let searchProvider = viewController as? BottomToolbarSearchProviding,
           searchProvider.bottomToolbarSearchInitiallyExpanded,
           activeSearchOwner == nil {
            activeSearchController = searchProvider.bottomToolbarSearchController
            activeSearchOwner = viewController
            isBottomSearchExpanded = activeSearchController != nil
        }

        let toolbarItems = makeToolbarItems(for: viewController)
        let signature = toolbarSignature(for: viewController, items: toolbarItems)
        guard signature != lastToolbarSignature else { return }

        lastToolbarSignature = signature
        viewController.setToolbarItems(toolbarItems, animated: animated)

        let shouldHideToolbar = (viewController as? BottomToolbarConfigurable)?.prefersBottomToolbarHidden ?? false
        setToolbarHidden(shouldHideToolbar, animated: animated)

        if isBottomSearchExpanded {
            activeSearchController?.searchBar.becomeFirstResponder()
            activeSearchController?.isActive = true
        }
    }

    private func makeToolbarItems(for viewController: UIViewController) -> [UIBarButtonItem] {
        if isBottomSearchExpanded, let searchController = activeSearchController {
            return makeExpandedSearchItems(searchController: searchController)
        }

        if let configurable = viewController as? BottomToolbarConfigurable {
            return makeToolbarItems(from: configurable.bottomToolbarItemGroups, for: viewController)
        }

        return makeDefaultToolbarItems(for: viewController)
    }

    private func makeToolbarItems(from groups: [BottomToolbarItemGroup], for viewController: UIViewController) -> [UIBarButtonItem] {
        var effectiveGroups = groups
        if viewControllers.first !== viewController {
            let firstItems = [bottomBackButton] + (effectiveGroups.first?.items ?? [])
            if effectiveGroups.isEmpty {
                effectiveGroups = [BottomToolbarItemGroup(firstItems)]
            } else {
                effectiveGroups[0] = BottomToolbarItemGroup(firstItems)
            }
        }

        var items: [UIBarButtonItem] = []
        for group in effectiveGroups where !group.items.isEmpty {
            if !items.isEmpty {
                items.append(UIBarButtonItem.bottomToolbarFixedSpace(18))
            }
            items.append(contentsOf: group.items)
        }
        return items
    }

    private func makeDefaultToolbarItems(for viewController: UIViewController) -> [UIBarButtonItem] {
        let navigationItem = viewController.navigationItem
        var leadingItems: [UIBarButtonItem]
        if let leftBarButtonItems = navigationItem.leftBarButtonItems {
            leadingItems = leftBarButtonItems
        } else if let leftBarButtonItem = navigationItem.leftBarButtonItem {
            leadingItems = [leftBarButtonItem]
        } else {
            leadingItems = []
        }

        if viewControllers.first !== viewController {
            leadingItems.insert(bottomBackButton, at: 0)
        }

        if searchController(for: viewController) != nil {
            leadingItems.append(bottomSearchButton)
        }

        let trailingItems: [UIBarButtonItem]
        if let rightBarButtonItems = navigationItem.rightBarButtonItems {
            trailingItems = rightBarButtonItems
        } else if let rightBarButtonItem = navigationItem.rightBarButtonItem {
            trailingItems = [rightBarButtonItem]
        } else {
            trailingItems = []
        }

        guard !leadingItems.isEmpty || !trailingItems.isEmpty else { return [] }

        var items: [UIBarButtonItem] = []
        if !leadingItems.isEmpty {
            items.append(contentsOf: leadingItems)
        }

        if !leadingItems.isEmpty && !trailingItems.isEmpty {
            items.append(UIBarButtonItem.bottomToolbarFlexibleSpace())
        }

        if !trailingItems.isEmpty {
            items.append(contentsOf: Array(trailingItems.reversed()))
        }

        return items
    }

    private func makeExpandedSearchItems(searchController: UISearchController) -> [UIBarButtonItem] {
        let searchBar = searchController.searchBar
        let availableWidth = max(view.bounds.width - 96, 180)
        searchBar.frame = CGRect(x: 0, y: 0, width: min(availableWidth, 520), height: 44)
        searchBar.placeholder = searchBar.placeholder ?? "Search"
        searchBar.showsCancelButton = false

        let searchItem = UIBarButtonItem(customView: searchBar)
        return [searchItem, UIBarButtonItem.bottomToolbarFlexibleSpace(), bottomSearchCancelButton]
    }

    private func searchController(for viewController: UIViewController) -> UISearchController? {
        if let provider = viewController as? BottomToolbarSearchProviding {
            return provider.bottomToolbarSearchController
        }
        return viewController.navigationItem.searchController
    }

    private func toolbarSignature(for viewController: UIViewController, items: [UIBarButtonItem]) -> String {
        let itemIDs = items.map { String(ObjectIdentifier($0).hashValue) }.joined(separator: ",")
        let rightCount = viewController.navigationItem.rightBarButtonItems?.count ?? (viewController.navigationItem.rightBarButtonItem == nil ? 0 : 1)
        let leftCount = viewController.navigationItem.leftBarButtonItems?.count ?? (viewController.navigationItem.leftBarButtonItem == nil ? 0 : 1)
        return "\(ObjectIdentifier(viewController).hashValue)|\(viewControllers.count)|\(leftCount)|\(rightCount)|\(isBottomSearchExpanded)|\(itemIDs)"
    }

    private func collapseBottomSearchIfNeeded() {
        guard isBottomSearchExpanded else { return }
        activeSearchController?.searchBar.resignFirstResponder()
        activeSearchController?.isActive = false
        isBottomSearchExpanded = false
        activeSearchController = nil
        activeSearchOwner = nil
        lastToolbarSignature = ""
    }

    @objc private func bottomBackButtonTapped() {
        _ = popViewController(animated: true)
    }

    @objc private func bottomSearchButtonTapped() {
        guard let viewController = topViewController,
              let searchController = searchController(for: viewController) else { return }

        activeSearchController = searchController
        activeSearchOwner = viewController
        isBottomSearchExpanded = true
        lastToolbarSignature = ""
        syncBottomToolbar(animated: true)
    }

    @objc private func bottomSearchCancelButtonTapped() {
        collapseBottomSearchIfNeeded()
        lastToolbarSignature = ""
        syncBottomToolbar(animated: true)
    }

    #if targetEnvironment(macCatalyst)
    private func setupMouseBackButton() {
        guard let nsEventClass = NSClassFromString("NSEvent") else {
            print("DEBUG MOUSE: NSEvent class not found")
            return
        }
        print("DEBUG MOUSE: NSEvent class found")

        // NSEventMaskSwipe = 1 << 31
        let mask: UInt64 = 1 << 31

        let handler: @convention(block) (AnyObject) -> AnyObject? = { [weak self] event in
            let deltaX = event.value(forKey: "deltaX") as? CGFloat ?? 0
            let deltaY = event.value(forKey: "deltaY") as? CGFloat ?? 0
            print("DEBUG MOUSE SWIPE: deltaX=\(deltaX) deltaY=\(deltaY)")

            // Swipe right (deltaX > 0) = navigate back
            // Swipe left (deltaX < 0) = navigate forward
            // Use a flag to only handle once per gesture
            if deltaX != 0 {
                if deltaX > 0, self?.hasHandledSwipeBack == false {
                    self?.hasHandledSwipeBack = true
                    print("DEBUG MOUSE: Back swipe detected! Popping view controller.")
                    DispatchQueue.main.async {
                        if (self?.viewControllers.count ?? 0) > 1 {
                            self?.popViewController(animated: true)
                        }
                        // Reset flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.hasHandledSwipeBack = false
                        }
                    }
                    return nil
                }
            }
            return event
        }

        let sel = NSSelectorFromString("addLocalMonitorForEventsMatchingMask:handler:")
        guard let msgSendPtr = dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend") else {
            print("DEBUG MOUSE: Could not get objc_msgSend")
            return
        }

        typealias MsgSendType = @convention(c) (AnyObject, Selector, UInt64, Any) -> AnyObject?
        let msgSend = unsafeBitCast(msgSendPtr, to: MsgSendType.self)

        mouseMonitor = msgSend(nsEventClass, sel, mask, handler)
        print("DEBUG MOUSE: Swipe monitor installed, mouseMonitor=\(mouseMonitor != nil ? "set" : "nil")")
    }

    deinit {
        if let monitor = mouseMonitor {
            guard let nsEventClass = NSClassFromString("NSEvent") else { return }
            let sel = NSSelectorFromString("removeMonitor:")
            guard let msgSendPtr = dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend") else { return }

            typealias MsgSendType = @convention(c) (AnyObject, Selector, AnyObject) -> Void
            let msgSend = unsafeBitCast(msgSendPtr, to: MsgSendType.self)

            msgSend(nsEventClass, sel, monitor)
        }
    }
    #endif
}
