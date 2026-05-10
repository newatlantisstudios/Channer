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

extension UIPopoverPresentationController {
    func channerAnchor(
        in presenter: UIViewController,
        barButtonItem: UIBarButtonItem? = nil,
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil,
        permittedArrowDirections: UIPopoverArrowDirection = .any
    ) {
        if let barButtonItem = barButtonItem {
            self.barButtonItem = barButtonItem
            self.permittedArrowDirections = permittedArrowDirections
            return
        }

        guard let presenterView = presenter.view else { return }
        let anchorView = sourceView ?? presenterView
        self.sourceView = anchorView
        self.sourceRect = sourceRect ?? CGRect(x: anchorView.bounds.midX, y: anchorView.bounds.midY, width: 1, height: 1)
        self.permittedArrowDirections = permittedArrowDirections
    }

    func channerEnsureAnchor(in presenter: UIViewController) {
        guard sourceView == nil && barButtonItem == nil else { return }
        channerAnchor(in: presenter)
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

protocol BottomToolbarSearchDismissHandling: AnyObject {
    func bottomToolbarSearchDidRequestDismissal()
}

private final class BottomToolbarSearchContainer: UIView {
    private var contentSize: CGSize

    var toolbarSignature: String {
        return "\(Int(contentSize.width.rounded()))x\(Int(contentSize.height.rounded()))"
    }

    init(
        searchTextField: UISearchTextField,
        showsBackButton: Bool,
        target: Any?,
        backAction: Selector,
        closeAction: Selector,
        size: CGSize
    ) {
        self.contentSize = size
        super.init(frame: CGRect(origin: .zero, size: size))

        isUserInteractionEnabled = true
        translatesAutoresizingMaskIntoConstraints = false

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if showsBackButton {
            stackView.addArrangedSubview(Self.makeIconButton(
                systemImageName: "chevron.backward",
                accessibilityLabel: "Back",
                target: target,
                action: backAction
            ))
        }

        stackView.addArrangedSubview(searchTextField)
        stackView.addArrangedSubview(Self.makeIconButton(
            systemImageName: "xmark",
            accessibilityLabel: "Close Search",
            target: target,
            action: closeAction
        ))

        addSubview(stackView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return contentSize
    }

    private static func makeIconButton(systemImageName: String, accessibilityLabel: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        button.setImage(UIImage(systemName: systemImageName, withConfiguration: imageConfiguration), for: .normal)
        button.tintColor = .black
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityIdentifier = accessibilityLabel
        #if targetEnvironment(macCatalyst)
        button.addTarget(target, action: action, for: .primaryActionTriggered)
        #else
        button.addTarget(target, action: action, for: .touchUpInside)
        #endif

        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        button.configuration = configuration
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])

        return button
    }
}

private final class EdgeBackPopAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.28
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        let width = containerView.bounds.width
        toView.frame = finalFrame.offsetBy(dx: -width * 0.3, dy: 0)
        containerView.insertSubview(toView, belowSubview: fromView)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                fromView.frame = finalFrame.offsetBy(dx: width, dy: 0)
                toView.frame = finalFrame
            },
            completion: { _ in
                let didComplete = !transitionContext.transitionWasCancelled
                if !didComplete {
                    fromView.frame = finalFrame
                    toView.removeFromSuperview()
                }
                transitionContext.completeTransition(didComplete)
            }
        )
    }
}

#if targetEnvironment(macCatalyst)
private final class MouseBackButtonGestureRecognizer: UIGestureRecognizer {
    // UIEvent button masks are one-based: primary = 1, secondary = 2, middle = 3, back = 4.
    private static let backButtonMask = UIEvent.ButtonMask(rawValue: 1 << 3)
    private var isTrackingBackButton = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard event.buttonMask.contains(Self.backButtonMask),
              touches.contains(where: { $0.type == .indirectPointer }) else {
            state = .failed
            return
        }

        isTrackingBackButton = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTrackingBackButton else {
            state = .failed
            return
        }

        state = .recognized
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        isTrackingBackButton = false
        state = .cancelled
    }

    override func reset() {
        isTrackingBackButton = false
    }
}
#endif

class CatalystNavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate {

    private lazy var bottomBackButton: UIBarButtonItem = {
        return makeInternalToolbarButtonItem(
            systemImageName: "chevron.backward",
            accessibilityLabel: "Back",
            action: #selector(bottomBackButtonTapped)
        )
    }()

    private lazy var bottomSearchButton: UIBarButtonItem = {
        return makeInternalToolbarButtonItem(
            systemImageName: "magnifyingglass",
            accessibilityLabel: "Search",
            action: #selector(bottomSearchButtonTapped)
        )
    }()

    private lazy var bottomSearchCancelButton: UIBarButtonItem = {
        return makeInternalToolbarButtonItem(
            systemImageName: "xmark",
            accessibilityLabel: "Close Search",
            action: #selector(bottomSearchCancelButtonTapped)
        )
    }()

    private var activeSearchController: UISearchController?
    private var activeSearchOwner: UIViewController?
    private var activeToolbarSearchTextField: UISearchTextField?
    private var activeToolbarSearchItem: UIBarButtonItem?
    private var activeToolbarSearchShowsBackButton = false
    private var activeToolbarSearchSize = CGSize.zero
    private var isBottomSearchExpanded = false
    private weak var manuallyCollapsedSearchOwner: UIViewController?
    private var lastToolbarSignature = ""
    private var mirroredToolbarItems: [ObjectIdentifier: UIBarButtonItem] = [:]
    private let edgeBackPopAnimator = EdgeBackPopAnimator()
    private var edgeBackInteractionController: UIPercentDrivenInteractiveTransition?
    private lazy var edgeBackGestureRecognizer: UIScreenEdgePanGestureRecognizer = {
        let gestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeBackGesture(_:)))
        gestureRecognizer.edges = .left
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()

    #if targetEnvironment(macCatalyst)
    private lazy var mouseBackButtonGestureRecognizer: MouseBackButtonGestureRecognizer = {
        let gestureRecognizer = MouseBackButtonGestureRecognizer(target: self, action: #selector(handleMouseBackButton(_:)))
        gestureRecognizer.cancelsTouchesInView = true
        gestureRecognizer.delaysTouchesBegan = false
        gestureRecognizer.delaysTouchesEnded = false
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()

    private lazy var trackpadBackGestureRecognizer: UIPanGestureRecognizer = {
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleTrackpadBackGesture(_:)))
        gestureRecognizer.allowedScrollTypesMask = .continuous
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delaysTouchesBegan = false
        gestureRecognizer.delaysTouchesEnded = false
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        configureInteractivePopGesture()
        configureEdgeBackGesture()
        #if targetEnvironment(macCatalyst)
        configureTrackpadBackGesture()
        configureMouseBackButton()
        #endif
        configureBottomToolbarChrome()
        syncBottomToolbar(animated: false)
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

    #if targetEnvironment(macCatalyst)
    override var keyCommands: [UIKeyCommand]? {
        let backCommand = UIKeyCommand(
            title: "Back",
            action: #selector(handleCommandBack),
            input: "[",
            modifierFlags: .command
        )

        return (super.keyCommands ?? []) + [backCommand]
    }
    #endif

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        collapseBottomSearchIfNeeded()
        super.pushViewController(viewController, animated: animated)
        updateInteractivePopGestureState()
        scheduleBottomToolbarSync(animated: animated)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        collapseBottomSearchIfNeeded()
        let poppedViewController = super.popViewController(animated: animated)
        updateInteractivePopGestureState()
        scheduleBottomToolbarSync(animated: animated)
        return poppedViewController
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        collapseBottomSearchIfNeeded()
        let poppedViewControllers = super.popToRootViewController(animated: animated)
        updateInteractivePopGestureState()
        scheduleBottomToolbarSync(animated: animated)
        return poppedViewControllers
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        collapseBottomSearchIfNeeded()
        super.setViewControllers(viewControllers, animated: animated)
        updateInteractivePopGestureState()
        scheduleBottomToolbarSync(animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        edgeBackInteractionController = nil
        updateInteractivePopGestureState()
        syncBottomToolbar(animated: animated)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        guard operation == .pop,
              edgeBackInteractionController != nil else { return nil }

        return edgeBackPopAnimator
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        return edgeBackInteractionController
    }

    private func configureInteractivePopGesture() {
        interactivePopGestureRecognizer?.delegate = self
        updateInteractivePopGestureState()
    }

    private func configureEdgeBackGesture() {
        view.addGestureRecognizer(edgeBackGestureRecognizer)
        updateInteractivePopGestureState()
    }

    #if targetEnvironment(macCatalyst)
    private func configureTrackpadBackGesture() {
        view.addGestureRecognizer(trackpadBackGestureRecognizer)
        updateInteractivePopGestureState()
    }

    private func configureMouseBackButton() {
        view.addGestureRecognizer(mouseBackButtonGestureRecognizer)
        updateInteractivePopGestureState()
    }

    private var canPopFromMouseBackButton: Bool {
        return view.window != nil &&
            viewControllers.count > 1 &&
            transitionCoordinator == nil &&
            presentedViewController == nil
    }

    @objc private func handleCommandBack() {
        guard canPopFromMouseBackButton else { return }
        _ = popViewController(animated: true)
    }

    @objc private func handleMouseBackButton(_ gestureRecognizer: MouseBackButtonGestureRecognizer) {
        guard gestureRecognizer.state == .recognized,
              canPopFromMouseBackButton else { return }
        _ = popViewController(animated: true)
    }
    #endif

    private func updateInteractivePopGestureState() {
        let canNavigateBack = viewControllers.count > 1
        interactivePopGestureRecognizer?.isEnabled = false
        edgeBackGestureRecognizer.isEnabled = canNavigateBack || edgeBackInteractionController != nil
        #if targetEnvironment(macCatalyst)
        mouseBackButtonGestureRecognizer.isEnabled = canNavigateBack
        trackpadBackGestureRecognizer.isEnabled = canNavigateBack || edgeBackInteractionController != nil
        #endif
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === interactivePopGestureRecognizer ||
            gestureRecognizer === edgeBackGestureRecognizer {
            return viewControllers.count > 1 && transitionCoordinator == nil
        }

        #if targetEnvironment(macCatalyst)
        if gestureRecognizer === mouseBackButtonGestureRecognizer {
            return canPopFromMouseBackButton
        }

        if gestureRecognizer === trackpadBackGestureRecognizer {
            guard viewControllers.count > 1,
                  transitionCoordinator == nil,
                  let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = panGestureRecognizer.velocity(in: view)
            return velocity.x > 0 && abs(velocity.x) > abs(velocity.y) * 1.25
        }
        #endif

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        #if targetEnvironment(macCatalyst)
        if gestureRecognizer === trackpadBackGestureRecognizer ||
            otherGestureRecognizer === trackpadBackGestureRecognizer {
            return true
        }
        #endif

        return false
    }

    @objc private func handleEdgeBackGesture(_ gestureRecognizer: UIScreenEdgePanGestureRecognizer) {
        let translationX = max(0, gestureRecognizer.translation(in: view).x)
        let progress = min(max(translationX / max(view.bounds.width, 1), 0), 1)

        switch gestureRecognizer.state {
        case .began:
            guard viewControllers.count > 1,
                  transitionCoordinator == nil else { return }

            edgeBackInteractionController = UIPercentDrivenInteractiveTransition()
            edgeBackInteractionController?.completionCurve = .easeOut
            _ = popViewController(animated: true)

        case .changed:
            edgeBackInteractionController?.update(progress)

        case .ended:
            let velocityX = gestureRecognizer.velocity(in: view).x
            let shouldFinish = progress > 0.35 || velocityX > 700
            if shouldFinish {
                edgeBackInteractionController?.finish()
            } else {
                edgeBackInteractionController?.cancel()
            }
            edgeBackInteractionController = nil
            updateInteractivePopGestureState()

        case .cancelled, .failed:
            edgeBackInteractionController?.cancel()
            edgeBackInteractionController = nil
            updateInteractivePopGestureState()

        default:
            break
        }
    }

    #if targetEnvironment(macCatalyst)
    @objc private func handleTrackpadBackGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translationX = max(0, gestureRecognizer.translation(in: view).x)
        let progressDistance = min(max(view.bounds.width * 0.45, 180), 360)
        let progress = min(max(translationX / progressDistance, 0), 1)

        switch gestureRecognizer.state {
        case .began:
            guard viewControllers.count > 1,
                  transitionCoordinator == nil else { return }

            edgeBackInteractionController = UIPercentDrivenInteractiveTransition()
            edgeBackInteractionController?.completionCurve = .easeOut
            _ = popViewController(animated: true)

        case .changed:
            edgeBackInteractionController?.update(progress)

        case .ended:
            let velocity = gestureRecognizer.velocity(in: view)
            let shouldFinish = progress > 0.35 || velocity.x > 650
            if shouldFinish {
                edgeBackInteractionController?.finish()
            } else {
                edgeBackInteractionController?.cancel()
            }
            edgeBackInteractionController = nil
            updateInteractivePopGestureState()

        case .cancelled, .failed:
            edgeBackInteractionController?.cancel()
            edgeBackInteractionController = nil
            updateInteractivePopGestureState()

        default:
            break
        }
    }
    #endif

    private func configureBottomToolbarChrome() {
        debugPrintBottomToolbarChrome("configureBottomToolbarChrome before")

        defer {
            updateInteractivePopGestureState()
        }

        setNavigationBarHidden(true, animated: false)
        navigationBar.isHidden = true
        setToolbarHidden(false, animated: false)

        if #available(iOS 26.0, *) {
            debugPrintBottomToolbarChrome("configureBottomToolbarChrome after iOS26 return")
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

        debugPrintBottomToolbarChrome("configureBottomToolbarChrome after")
    }

    private func scheduleBottomToolbarSync(animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.syncBottomToolbar(animated: animated)
        }
    }

    private func syncBottomToolbar(animated: Bool) {
        guard let viewController = topViewController else { return }

        debugPrintBottomToolbarChrome("syncBottomToolbar start top=\(String(describing: type(of: viewController))) animated=\(animated)")
        configureBottomToolbarChrome()

        if activeSearchOwner !== viewController {
            isBottomSearchExpanded = false
            activeSearchController = nil
            activeSearchOwner = nil
            clearActiveToolbarSearchView()
        }

        if let searchProvider = viewController as? BottomToolbarSearchProviding,
           searchProvider.bottomToolbarSearchInitiallyExpanded,
           manuallyCollapsedSearchOwner !== viewController,
           activeSearchOwner == nil {
            activeSearchController = searchProvider.bottomToolbarSearchController
            activeSearchOwner = viewController
            isBottomSearchExpanded = activeSearchController != nil
        }

        let toolbarItems = makeToolbarItems(for: viewController)
        let signature = toolbarSignature(for: viewController, items: toolbarItems)
        let shouldHideToolbar = (viewController as? BottomToolbarConfigurable)?.prefersBottomToolbarHidden ?? false
        debugPrintBottomToolbarChrome("syncBottomToolbar items=\(toolbarItems.count) signature=\(signature) last=\(lastToolbarSignature) shouldHideToolbar=\(shouldHideToolbar)")
        guard signature != lastToolbarSignature else {
            setToolbarHidden(shouldHideToolbar, animated: animated)
            debugPrintBottomToolbarChrome("syncBottomToolbar unchanged after setToolbarHidden")
            return
        }

        mirroredToolbarItems.removeAll()
        lastToolbarSignature = signature
        viewController.setToolbarItems(toolbarItems, animated: animated)

        setToolbarHidden(shouldHideToolbar, animated: animated)
        debugPrintBottomToolbarChrome("syncBottomToolbar applied toolbar items")

        if isBottomSearchExpanded, let textField = activeToolbarSearchTextField {
            DispatchQueue.main.async { [weak self, weak textField] in
                guard self?.activeToolbarSearchTextField === textField else { return }
                textField?.becomeFirstResponder()
            }
        }
    }

    private func debugPrintBottomToolbarChrome(_ context: String) {
        guard shouldPrintBottomToolbarChromeDebug else { return }

        print("[BottomToolbarNavDebug] \(context)")
        print("[BottomToolbarNavDebug] top=\(String(describing: topViewController.map { type(of: $0) })) viewControllers=\(viewControllers.map { String(describing: type(of: $0)) })")
        print("[BottomToolbarNavDebug] isNavigationBarHidden=\(isNavigationBarHidden) navBar.isHidden=\(navigationBar.isHidden) navBar.isTranslucent=\(navigationBar.isTranslucent) navBar.backgroundColor=\(String(describing: navigationBar.backgroundColor)) navBar.frame=\(navigationBar.frame)")
        print("[BottomToolbarNavDebug] toolbarHidden=\(isToolbarHidden) toolbar.isHidden=\(toolbar.isHidden) toolbar.isTranslucent=\(toolbar.isTranslucent) toolbar.backgroundColor=\(String(describing: toolbar.backgroundColor)) toolbar.frame=\(toolbar.frame)")
        debugPrintToolbarAppearance("standard", toolbar.standardAppearance)
        debugPrintToolbarAppearance("scrollEdge", toolbar.scrollEdgeAppearance)
        debugPrintToolbarAppearance("compact", toolbar.compactAppearance)
        if #available(iOS 15.0, *) {
            debugPrintToolbarAppearance("compactScrollEdge", toolbar.compactScrollEdgeAppearance)
        }
    }

    private var shouldPrintBottomToolbarChromeDebug: Bool {
        let debugViewControllerNames = viewControllers.map { String(describing: type(of: $0)) }
        return debugViewControllerNames.contains { name in
            name.contains("threadReplies") ||
            name.contains("ImageViewController") ||
            name.contains("WebMViewController") ||
            name.contains("urlWeb") ||
            name.contains("ImageGalleryVC")
        }
    }

    private func debugPrintToolbarAppearance(_ name: String, _ appearance: UIToolbarAppearance?) {
        guard let appearance else {
            print("[BottomToolbarNavDebug] \(name) appearance=nil")
            return
        }

        print("[BottomToolbarNavDebug] \(name) backgroundColor=\(String(describing: appearance.backgroundColor)) backgroundEffect=\(String(describing: appearance.backgroundEffect)) shadowColor=\(String(describing: appearance.shadowColor)) backgroundImage=\(String(describing: appearance.backgroundImage)) shadowImage=\(String(describing: appearance.shadowImage))")
    }

    private func makeToolbarItems(for viewController: UIViewController) -> [UIBarButtonItem] {
        if isBottomSearchExpanded, let searchController = activeSearchController {
            return makeExpandedSearchItems(searchController: searchController, for: viewController)
        }

        if let configurable = viewController as? BottomToolbarConfigurable {
            return makeToolbarItems(from: configurable.bottomToolbarItemGroups, for: viewController)
        }

        return makeDefaultToolbarItems(for: viewController)
    }

    func showBottomToolbarSearch(_ searchController: UISearchController, owner viewController: UIViewController) {
        guard topViewController === viewController else { return }

        activeSearchController = searchController
        activeSearchOwner = viewController
        manuallyCollapsedSearchOwner = nil
        isBottomSearchExpanded = true
        lastToolbarSignature = ""
        syncBottomToolbar(animated: true)
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
            items.append(contentsOf: mirroredItems(from: group.items))
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
            items.append(contentsOf: mirroredItems(from: leadingItems))
        }

        if !leadingItems.isEmpty || !trailingItems.isEmpty {
            items.append(UIBarButtonItem.bottomToolbarFlexibleSpace())
        }

        if !trailingItems.isEmpty {
            items.append(contentsOf: mirroredItems(from: Array(trailingItems.reversed())))
        }

        return items
    }

    private func makeExpandedSearchItems(searchController: UISearchController, for viewController: UIViewController) -> [UIBarButtonItem] {
        let searchBar = searchController.searchBar
        let includesBackButton = viewControllers.first !== viewController
        let safeWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        let availableWidth = max(safeWidth > 0 ? safeWidth : view.bounds.width, 260)
        let horizontalInset: CGFloat = traitCollection.horizontalSizeClass == .compact ? 56 : 120
        let searchGroupWidth = min(max(availableWidth - horizontalInset, 250), 500)
        let searchGroupSize = CGSize(width: searchGroupWidth, height: 36)
        let placeholder = searchBar.placeholder?.isEmpty == false ? searchBar.placeholder! : "Search"
        searchBar.placeholder = placeholder

        if let searchItem = activeToolbarSearchItem,
           activeToolbarSearchShowsBackButton == includesBackButton,
           abs(activeToolbarSearchSize.width - searchGroupSize.width) < 1,
           abs(activeToolbarSearchSize.height - searchGroupSize.height) < 1,
           let searchTextField = activeToolbarSearchTextField {
            configureToolbarSearchTextField(searchTextField, searchBar: searchBar, placeholder: placeholder)
            return [
                UIBarButtonItem.bottomToolbarFlexibleSpace(),
                searchItem,
                UIBarButtonItem.bottomToolbarFlexibleSpace()
            ]
        }

        let searchTextField = UISearchTextField(frame: CGRect(origin: .zero, size: CGSize(width: searchGroupWidth, height: 30)))
        configureToolbarSearchTextField(searchTextField, searchBar: searchBar, placeholder: placeholder)
        activeToolbarSearchTextField = searchTextField

        let searchContainer = BottomToolbarSearchContainer(
            searchTextField: searchTextField,
            showsBackButton: includesBackButton,
            target: self,
            backAction: #selector(bottomBackButtonTapped),
            closeAction: #selector(bottomSearchCancelButtonTapped),
            size: searchGroupSize
        )
        let searchItem = UIBarButtonItem(customView: searchContainer)
        activeToolbarSearchItem = searchItem
        activeToolbarSearchShowsBackButton = includesBackButton
        activeToolbarSearchSize = searchGroupSize

        return [
            UIBarButtonItem.bottomToolbarFlexibleSpace(),
            searchItem,
            UIBarButtonItem.bottomToolbarFlexibleSpace()
        ]
    }

    private func configureToolbarSearchTextField(_ searchTextField: UISearchTextField, searchBar: UISearchBar, placeholder: String) {
        if searchTextField.text != searchBar.text {
            searchTextField.text = searchBar.text
        }
        searchTextField.placeholder = placeholder
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.placeholderText]
        )
        searchTextField.font = UIFont.systemFont(ofSize: 14)
        searchTextField.textColor = .label
        searchTextField.tintColor = .systemBlue
        searchTextField.returnKeyType = .search
        searchTextField.enablesReturnKeyAutomatically = true
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.delegate = self
        searchTextField.removeTarget(self, action: #selector(bottomToolbarSearchTextChanged(_:)), for: .editingChanged)
        searchTextField.addTarget(self, action: #selector(bottomToolbarSearchTextChanged(_:)), for: .editingChanged)
    }

    private func searchController(for viewController: UIViewController) -> UISearchController? {
        if let provider = viewController as? BottomToolbarSearchProviding {
            return provider.bottomToolbarSearchController
        }
        return viewController.navigationItem.searchController
    }

    private func mirroredItems(from sourceItems: [UIBarButtonItem]) -> [UIBarButtonItem] {
        return sourceItems.map { mirroredItem(for: $0) }
    }

    private func mirroredItem(for sourceItem: UIBarButtonItem) -> UIBarButtonItem {
        if sourceItem === bottomBackButton ||
            sourceItem === bottomSearchButton ||
            sourceItem === bottomSearchCancelButton ||
            sourceItem.customView != nil {
            return sourceItem
        }

        let identifier = ObjectIdentifier(sourceItem)
        if let item = mirroredToolbarItems[identifier] {
            return item
        }

        let item = UIBarButtonItem(customView: makeToolbarButton(for: sourceItem))

        item.isEnabled = sourceItem.isEnabled
        item.tintColor = sourceItem.tintColor
        item.width = sourceItem.width
        item.tag = sourceItem.tag
        item.accessibilityLabel = sourceItem.accessibilityLabel
        item.accessibilityIdentifier = sourceItem.accessibilityIdentifier
        item.menu = sourceItem.menu

        mirroredToolbarItems[identifier] = item
        return item
    }

    private func makeToolbarButton(for sourceItem: UIBarButtonItem) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = sourceItem.tintColor
        button.isEnabled = sourceItem.isEnabled
        button.accessibilityLabel = sourceItem.accessibilityLabel ?? sourceItem.title
        button.accessibilityIdentifier = sourceItem.accessibilityIdentifier

        if let image = sourceItem.image {
            button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: max(sourceItem.width, 44)),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
        } else {
            let title = sourceItem.title ?? sourceItem.accessibilityLabel ?? ""
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
            button.configuration = configuration
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 44),
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: max(sourceItem.width, 44))
            ])
        }

        if let menu = sourceItem.menu {
            button.menu = menu
            button.showsMenuAsPrimaryAction = sourceItem.action == nil
        }

        if let action = sourceItem.action {
            #if targetEnvironment(macCatalyst)
            button.addTarget(sourceItem.target, action: action, for: .primaryActionTriggered)
            #else
            button.addTarget(sourceItem.target, action: action, for: .touchUpInside)
            #endif
        }

        return button
    }

    private func makeInternalToolbarButtonItem(systemImageName: String, accessibilityLabel: String, action: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemImageName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = .black
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityIdentifier = accessibilityLabel
        #if targetEnvironment(macCatalyst)
        button.addTarget(self, action: action, for: .primaryActionTriggered)
        #else
        button.addTarget(self, action: action, for: .touchUpInside)
        #endif

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])

        let item = UIBarButtonItem(customView: button)
        item.tintColor = .black
        item.accessibilityLabel = accessibilityLabel
        item.accessibilityIdentifier = accessibilityLabel
        return item
    }

    private func toolbarSignature(for viewController: UIViewController, items: [UIBarButtonItem]) -> String {
        let rightCount = viewController.navigationItem.rightBarButtonItems?.count ?? (viewController.navigationItem.rightBarButtonItem == nil ? 0 : 1)
        let leftCount = viewController.navigationItem.leftBarButtonItems?.count ?? (viewController.navigationItem.leftBarButtonItem == nil ? 0 : 1)
        let itemSignature = items.map { toolbarSignature(for: $0) }.joined(separator: ",")
        return "\(ObjectIdentifier(viewController).hashValue)|\(viewControllers.count)|\(leftCount)|\(rightCount)|\(isBottomSearchExpanded)|\(itemSignature)"
    }

    private func toolbarSignature(for item: UIBarButtonItem) -> String {
        if item === bottomBackButton {
            return "back"
        }
        if item === bottomSearchButton {
            return "search"
        }
        if item === bottomSearchCancelButton {
            return "cancel-search"
        }
        if let searchContainer = item.customView as? BottomToolbarSearchContainer {
            return "search-container:\(searchContainer.toolbarSignature)"
        }
        if item.customView != nil {
            return "custom:\(item.customView?.bounds.width ?? 0)"
        }
        let action = item.action.map { NSStringFromSelector($0) } ?? "nil"
        let enabled = item.isEnabled ? "enabled" : "disabled"
        let title = item.title ?? ""
        let image = item.image?.accessibilityIdentifier ?? item.image?.description ?? ""
        return "\(title)|\(image)|\(action)|\(item.tag)|\(enabled)"
    }

    private func collapseBottomSearchIfNeeded() {
        guard isBottomSearchExpanded else { return }
        clearActiveToolbarSearchView()
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
        manuallyCollapsedSearchOwner = nil
        isBottomSearchExpanded = true
        lastToolbarSignature = ""
        syncBottomToolbar(animated: true)
    }

    @objc private func bottomSearchCancelButtonTapped() {
        manuallyCollapsedSearchOwner = activeSearchOwner ?? topViewController
        (activeSearchOwner as? BottomToolbarSearchDismissHandling)?.bottomToolbarSearchDidRequestDismissal()
        collapseBottomSearchIfNeeded()
        lastToolbarSignature = ""
        syncBottomToolbar(animated: true)
    }

    @objc private func bottomToolbarSearchTextChanged(_ textField: UISearchTextField) {
        guard let searchBar = activeSearchController?.searchBar else { return }
        let text = textField.text ?? ""
        searchBar.text = text
        searchBar.delegate?.searchBar?(searchBar, textDidChange: text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let searchBar = activeSearchController?.searchBar else { return true }
        searchBar.text = textField.text
        textField.resignFirstResponder()
        searchBar.delegate?.searchBarSearchButtonClicked?(searchBar)
        return false
    }

    private func clearActiveToolbarSearchView() {
        activeToolbarSearchTextField?.resignFirstResponder()
        activeToolbarSearchTextField = nil
        activeToolbarSearchItem = nil
        activeToolbarSearchShowsBackButton = false
        activeToolbarSearchSize = .zero
    }

}
