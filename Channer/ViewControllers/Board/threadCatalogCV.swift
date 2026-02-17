import UIKit
import Alamofire
import SwiftyJSON

class threadCatalogCV: UICollectionViewController, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating {
    var boardName = ""
    var boardAbv = "a"
    var boardPassed = false
    var threadData: [ThreadData] = []
    var filteredThreadData: [ThreadData] = []

    private var isLoading = false
    private let totalPages = 10
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let searchController = UISearchController(searchResultsController: nil)
    private var lastLayoutWidth: CGFloat = 0
    private var lastGridSizeIndex: Int = GridItemSizeManager.shared.sizeIndex

    private let threadsDisplayModeKey = ThreadViewControllerFactory.threadsDisplayModeKey

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupLoadingIndicator()
        setupSearchController()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gridItemSizeDidChange),
            name: .gridItemSizeDidChange,
            object: nil
        )

        if !boardPassed {
            let userDefaultsKey = "defaultBoard"
            if let savedBoardAbv = UserDefaults.standard.string(forKey: userDefaultsKey) {
                boardAbv = savedBoardAbv
            } else {
                boardAbv = "a"
            }
            title = "/\(boardAbv)/"
        }

        if title?.isEmpty != false {
            title = "/\(boardAbv)/"
        }

        setupSortButton()
        loadThreads()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let currentMode = UserDefaults.standard.integer(forKey: threadsDisplayModeKey)
        guard currentMode == ThreadDisplayMode.list.rawValue else { return }

        let listVC = ThreadViewControllerFactory.makeBoardViewController(
            boardName: boardName,
            boardAbv: boardAbv,
            boardPassed: boardPassed
        )

        guard listVC is boardTV else { return }

        var viewControllers = navigationController?.viewControllers ?? []
        if let index = viewControllers.firstIndex(of: self) {
            viewControllers[index] = listVC
            navigationController?.setViewControllers(viewControllers, animated: false)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let currentWidth = collectionView.bounds.width
        let gridSizeIndex = GridItemSizeManager.shared.sizeIndex
        guard currentWidth > 0 else { return }

        if currentWidth != lastLayoutWidth || gridSizeIndex != lastGridSizeIndex {
            lastLayoutWidth = currentWidth
            lastGridSizeIndex = gridSizeIndex
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.backgroundColor = ThemeManager.shared.backgroundColor
            collectionView.reloadData()
        }
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = ThemeManager.shared.backgroundColor
        collectionView.alwaysBounceVertical = true
        collectionView.register(threadCatalogCell.self, forCellWithReuseIdentifier: "threadCatalogCell")

        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = ThemeManager.shared.primaryTextColor
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func setupLoadingIndicator() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search threads"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    @objc private func gridItemSizeDidChange(_ notification: Notification) {
        lastGridSizeIndex = GridItemSizeManager.shared.sizeIndex
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @objc private func handlePullToRefresh() {
        loadThreads()
    }

    // MARK: - Search
    func updateSearchResults(for searchController: UISearchController) {
        applyFiltersAndSearch()
        collectionView.reloadData()
    }

    private func applyFiltersAndSearch() {
        var results = threadData

        if ContentFilterManager.shared.isFilteringEnabled() {
            let filters = ContentFilterManager.shared.getAllFilters()
            if !filters.keywords.isEmpty {
                let lowercasedKeywords = filters.keywords.map { $0.lowercased() }
                results = results.filter { thread in
                    let threadContent = (thread.title + " " + thread.comment).lowercased()
                    return !lowercasedKeywords.contains { threadContent.contains($0) }
                }
            }
        }

        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            results = results.filter { thread in
                let threadContent = (thread.title + " " + thread.comment).lowercased()
                return threadContent.contains(lowercasedQuery)
            }
        }

        filteredThreadData = results
    }

    // MARK: - Data Loading
    private func loadThreads() {
        guard !isLoading else {
            collectionView.refreshControl?.endRefreshing()
            return
        }

        isLoading = true
        loadingIndicator.startAnimating()

        StatisticsManager.shared.recordBoardVisit(boardAbv: boardAbv)

        let dispatchGroup = DispatchGroup()
        var newThreadData: [ThreadData] = []
        var errors: [Error] = []
        let serialQueue = DispatchQueue(label: "com.channer.threadCatalogDataQueue")
        let processingQueue = DispatchQueue(label: "com.channer.threadCatalogProcessing", qos: .userInitiated)

        for page in 1...totalPages {
            dispatchGroup.enter()
            let url = "https://a.4cdn.org/\(boardAbv)/\(page).json"

            AF.request(url).responseData(queue: processingQueue) { response in
                defer { dispatchGroup.leave() }

                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if let threads = json["threads"].array {
                            let pageThreads = threads.enumerated().compactMap { (index, threadJson) in
                                var thread = ThreadData(from: threadJson, boardAbv: self.boardAbv)
                                thread.bumpIndex = (page - 1) * threads.count + index
                                return thread.number.isEmpty ? nil : thread
                            }

                            serialQueue.sync {
                                newThreadData.append(contentsOf: pageThreads)
                            }
                        }
                    } catch {
                        serialQueue.sync {
                            errors.append(error)
                        }
                    }

                case .failure(let error):
                    serialQueue.sync {
                        errors.append(error)
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            self.collectionView.refreshControl?.endRefreshing()

            if !errors.isEmpty {
                print("Errors loading threads: \(errors)")
            }

            let dedupedThreads = newThreadData.reduce(into: [String: ThreadData]()) { result, thread in
                if let existing = result[thread.number] {
                    let existingReplies = existing.currentReplies ?? existing.replies
                    let newReplies = thread.currentReplies ?? thread.replies
                    let existingBump = existing.bumpIndex ?? Int.max
                    let newBump = thread.bumpIndex ?? Int.max

                    if newBump < existingBump || newReplies > existingReplies {
                        result[thread.number] = thread
                    }
                } else {
                    result[thread.number] = thread
                }
            }

            self.threadData = Array(dedupedThreads.values).sorted {
                Int($0.number) ?? 0 > Int($1.number) ?? 0
            }

            self.applyFiltersAndSearch()
            self.collectionView.reloadData()
        }
    }

    // MARK: - UICollectionView Data Source
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredThreadData.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "threadCatalogCell", for: indexPath) as? threadCatalogCell else {
            return UICollectionViewCell()
        }

        let thread = filteredThreadData[indexPath.row]
        cell.configure(with: thread)
        return cell
    }

    // MARK: - UICollectionView Delegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let thread = filteredThreadData[indexPath.row]
        let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"

        HistoryManager.shared.addThreadToHistory(thread)

        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = .systemBackground
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(indicator)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
        indicator.startAnimating()

        AF.request(url).response { response in
            DispatchQueue.main.async {
                loadingView.removeFromSuperview()
            }

            guard let data = response.data,
                  let json = try? JSON(data: data),
                  !json["posts"].isEmpty else {
                print("Thread not available or invalid response.")
                return
            }

            let vc = threadRepliesTV()
            vc.boardAbv = thread.boardAbv
            vc.threadNumber = thread.number
            vc.totalImagesInThread = thread.stats.components(separatedBy: "/").last.flatMap { Int($0) } ?? 0

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        let metrics = gridLayoutMetrics(for: collectionView.bounds.width)
        return UIEdgeInsets(top: metrics.sectionInset, left: metrics.sectionInset, bottom: metrics.sectionInset, right: metrics.sectionInset)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        gridLayoutMetrics(for: collectionView.bounds.width).lineSpacing
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        gridLayoutMetrics(for: collectionView.bounds.width).interItemSpacing
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        gridLayoutMetrics(for: collectionView.bounds.width).cellSize
    }

    private struct GridLayoutMetrics {
        let cellSize: CGSize
        let sectionInset: CGFloat
        let interItemSpacing: CGFloat
        let lineSpacing: CGFloat
    }

    // MARK: - Sorting

    private enum SortOption {
        case replyCount
        case newestCreation
        case bumpOrder
        case lastReply
    }

    private func setupSortButton() {
        let sortImage = UIImage(named: "sort")?.withRenderingMode(.alwaysTemplate)
        let resizedSortImage = sortImage?.resized(to: CGSize(width: 22, height: 22))
        let sortButton = UIBarButtonItem(image: resizedSortImage, style: .plain, target: self, action: #selector(sortButtonTapped))

        if var rightBarButtonItems = navigationItem.rightBarButtonItems {
            rightBarButtonItems.append(sortButton)
            navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            navigationItem.rightBarButtonItems = [sortButton]
        }
    }

    @objc private func sortButtonTapped() {
        let alertController = UIAlertController(title: "Sort", message: nil, preferredStyle: .actionSheet)

        let bumpOrderAction = UIAlertAction(title: "Bump Order", style: .default) { _ in
            self.sortThreads(by: .bumpOrder)
        }
        let lastReplyAction = UIAlertAction(title: "Last Reply", style: .default) { _ in
            self.sortThreads(by: .lastReply)
        }
        let replyCountAction = UIAlertAction(title: "Highest Reply Count", style: .default) { _ in
            self.sortThreads(by: .replyCount)
        }
        let newestCreationAction = UIAlertAction(title: "Newest Creation", style: .default) { _ in
            self.sortThreads(by: .newestCreation)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(bumpOrderAction)
        alertController.addAction(lastReplyAction)
        alertController.addAction(replyCountAction)
        alertController.addAction(newestCreationAction)
        alertController.addAction(cancelAction)

        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.first { $0.action == #selector(sortButtonTapped) }
            popoverController.permittedArrowDirections = .up
        }

        present(alertController, animated: true, completion: nil)
    }

    private func sortThreads(by option: SortOption) {
        switch option {
        case .replyCount:
            filteredThreadData.sort { $0.replies > $1.replies }
        case .newestCreation:
            filteredThreadData.sort { $0.createdAt > $1.createdAt }
        case .bumpOrder:
            filteredThreadData.sort {
                if let bump1 = $0.bumpIndex, let bump2 = $1.bumpIndex {
                    return bump1 < bump2
                }
                return Int($0.number) ?? 0 > Int($1.number) ?? 0
            }
        case .lastReply:
            filteredThreadData.sort {
                if let time1 = $0.lastReplyTime, let time2 = $1.lastReplyTime {
                    return time1 > time2
                }
                return $0.replies > $1.replies
            }
        }
        collectionView.reloadData()
    }

    private func gridLayoutMetrics(for collectionViewWidth: CGFloat) -> GridLayoutMetrics {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let gridScale = GridItemSizeManager.shared.scaleFactor
        let sectionInset: CGFloat = isPad ? 12 : 10
        let interItemSpacing: CGFloat = isPad ? 12 : 10
        let lineSpacing: CGFloat = isPad ? 14 : 12

        let columns: CGFloat
        if isPad {
            if collectionViewWidth > 1000 {
                columns = 6
            } else if collectionViewWidth > 800 {
                columns = 5
            } else {
                columns = 4
            }
        } else {
            columns = collectionViewWidth > 400 ? 3 : 2
        }

        let availableWidth = collectionViewWidth - (sectionInset * 2)
        let baseItemWidth = floor((availableWidth - (interItemSpacing * (columns - 1))) / columns)
        let targetItemWidth = baseItemWidth * gridScale
        var adjustedColumns = floor((availableWidth + interItemSpacing) / (targetItemWidth + interItemSpacing))
        adjustedColumns = max(adjustedColumns, 1)
        let itemWidth = floor((availableWidth - (interItemSpacing * (adjustedColumns - 1))) / adjustedColumns)
        let itemHeight = itemWidth * 1.55

        return GridLayoutMetrics(
            cellSize: CGSize(width: itemWidth, height: itemHeight),
            sectionInset: sectionInset,
            interItemSpacing: interItemSpacing,
            lineSpacing: lineSpacing
        )
    }
}
