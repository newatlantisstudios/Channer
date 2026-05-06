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
        button.addTarget(target, action: action, for: .touchUpInside)

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

class CatalystNavigationController: UINavigationController, UINavigationControllerDelegate, UITextFieldDelegate {

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
        guard signature != lastToolbarSignature else {
            setToolbarHidden(shouldHideToolbar, animated: animated)
            return
        }

        mirroredToolbarItems.removeAll()
        lastToolbarSignature = signature
        viewController.setToolbarItems(toolbarItems, animated: animated)

        setToolbarHidden(shouldHideToolbar, animated: animated)

        if isBottomSearchExpanded, let textField = activeToolbarSearchTextField {
            DispatchQueue.main.async { [weak self, weak textField] in
                guard self?.activeToolbarSearchTextField === textField else { return }
                textField?.becomeFirstResponder()
            }
        }
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
            button.addTarget(sourceItem.target, action: action, for: .touchUpInside)
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
        button.addTarget(self, action: action, for: .touchUpInside)

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
