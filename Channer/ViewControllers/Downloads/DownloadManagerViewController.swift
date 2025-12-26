//
//  DownloadManagerViewController.swift
//  Channer
//
//  View controller for displaying and managing all downloads
//

import UIKit

/// View controller displaying all downloads with filtering and management capabilities
class DownloadManagerViewController: UIViewController {

    // MARK: - Filter Types
    private enum DownloadFilter: Int, CaseIterable {
        case all = 0
        case active = 1
        case completed = 2
        case failed = 3

        var title: String {
            switch self {
            case .all: return "All"
            case .active: return "Active"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }

        var emptyMessage: String {
            switch self {
            case .all: return "No downloads"
            case .active: return "No active downloads"
            case .completed: return "No completed downloads"
            case .failed: return "No failed downloads"
            }
        }
    }

    // MARK: - UI Components
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let segmentedControl = UISegmentedControl(items: DownloadFilter.allCases.map { $0.title })
    private let emptyStateLabel = UILabel()
    private let refreshControl = UIRefreshControl()

    // MARK: - Data
    private var downloadGroups: [DownloadGroup] = []
    private var filteredGroups: [DownloadGroup] = []
    private var currentFilter: DownloadFilter = .all

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupNotifications()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        applyTheme()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = "Download Manager"

        applyTheme()

        // Navigation bar buttons
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showMoreOptions)
        )
        navigationItem.rightBarButtonItem = moreButton

        // Segmented control for filtering
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Empty state
        emptyStateLabel.text = "No downloads"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func applyTheme() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        emptyStateLabel.textColor = ThemeManager.shared.secondaryTextColor
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DownloadItemCell.self, forCellReuseIdentifier: DownloadItemCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadStatusChanged),
            name: DownloadManagerService.downloadStatusNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadProgressChanged),
            name: DownloadManagerService.downloadProgressNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queueUpdated),
            name: DownloadManagerService.downloadQueueUpdatedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    // MARK: - Data Management

    private func reloadData() {
        downloadGroups = DownloadManagerService.shared.getGroupedDownloads()
        applyFilter()
        tableView.reloadData()
        updateEmptyState()
        refreshControl.endRefreshing()
    }

    private func applyFilter() {
        switch currentFilter {
        case .all:
            filteredGroups = downloadGroups

        case .active:
            filteredGroups = downloadGroups.compactMap { group in
                let filtered = group.items.filter { $0.status == .downloading || $0.status == .pending }
                return filtered.isEmpty ? nil : DownloadGroup(
                    id: group.id,
                    boardAbv: group.boardAbv,
                    threadNumber: group.threadNumber,
                    items: filtered
                )
            }

        case .completed:
            filteredGroups = downloadGroups.compactMap { group in
                let filtered = group.items.filter { $0.status == .completed }
                return filtered.isEmpty ? nil : DownloadGroup(
                    id: group.id,
                    boardAbv: group.boardAbv,
                    threadNumber: group.threadNumber,
                    items: filtered
                )
            }

        case .failed:
            filteredGroups = downloadGroups.compactMap { group in
                let filtered = group.items.filter { $0.status == .failed || $0.status == .cancelled }
                return filtered.isEmpty ? nil : DownloadGroup(
                    id: group.id,
                    boardAbv: group.boardAbv,
                    threadNumber: group.threadNumber,
                    items: filtered
                )
            }
        }
    }

    private func updateEmptyState() {
        let isEmpty = filteredGroups.isEmpty
        emptyStateLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        emptyStateLabel.text = currentFilter.emptyMessage
    }

    // MARK: - Actions

    @objc private func filterChanged() {
        currentFilter = DownloadFilter(rawValue: segmentedControl.selectedSegmentIndex) ?? .all
        applyFilter()
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func refreshData() {
        reloadData()
    }

    @objc private func showMoreOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Pause All
        let activeCount = DownloadManagerService.shared.getActiveDownloads().count
        if activeCount > 0 {
            alert.addAction(UIAlertAction(title: "Pause All", style: .default) { _ in
                DownloadManagerService.shared.pauseAllDownloads()
            })
        }

        // Resume All
        let pausedCount = DownloadManagerService.shared.downloadItems.filter { $0.status == .paused }.count
        if pausedCount > 0 {
            alert.addAction(UIAlertAction(title: "Resume All", style: .default) { _ in
                DownloadManagerService.shared.resumeAllDownloads()
            })
        }

        // Retry All Failed
        let failedCount = DownloadManagerService.shared.getFailedDownloads().count
        if failedCount > 0 {
            alert.addAction(UIAlertAction(title: "Retry All Failed (\(failedCount))", style: .default) { _ in
                DownloadManagerService.shared.retryAllFailed()
            })
        }

        // Clear Completed
        let completedCount = DownloadManagerService.shared.getCompletedDownloads().count
        if completedCount > 0 {
            alert.addAction(UIAlertAction(title: "Clear Completed (\(completedCount))", style: .default) { [weak self] _ in
                self?.confirmClearCompleted()
            })
        }

        // Clear All
        let totalCount = DownloadManagerService.shared.getTotalDownloadCount()
        if totalCount > 0 {
            alert.addAction(UIAlertAction(title: "Clear All Downloads", style: .destructive) { [weak self] _ in
                self?.confirmClearAll()
            })
        }

        // Open Downloads Folder
        alert.addAction(UIAlertAction(title: "Open Downloads Folder", style: .default) { _ in
            self.openDownloadsFolder()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Configure for iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func confirmClearCompleted() {
        let alert = UIAlertController(
            title: "Clear Completed",
            message: "Remove all completed downloads from the list? Downloaded files will not be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            DownloadManagerService.shared.clearCompletedDownloads()
            self.reloadData()
        })
        present(alert, animated: true)
    }

    private func confirmClearAll() {
        let alert = UIAlertController(
            title: "Clear All Downloads",
            message: "Cancel all active downloads and remove all items from the list? Downloaded files will not be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            DownloadManagerService.shared.clearAllDownloads()
            self.reloadData()
        })
        present(alert, animated: true)
    }

    private func openDownloadsFolder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let batchDownloadsDir = documentsPath.appendingPathComponent("BatchDownloads", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: batchDownloadsDir, withIntermediateDirectories: true)

        // Open in Files app
        if let filesURL = URL(string: "shareddocuments://\(batchDownloadsDir.path)") {
            UIApplication.shared.open(filesURL, options: [:], completionHandler: nil)
        }
    }

    // MARK: - Notification Handlers

    @objc private func downloadStatusChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
        }
    }

    @objc private func downloadProgressChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let downloadId = userInfo["downloadId"] as? String,
              let progress = userInfo["progress"] as? Double,
              let bytesDownloaded = userInfo["bytesDownloaded"] as? Int64,
              let totalBytes = userInfo["totalBytes"] as? Int64 else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Find the cell and update only the progress
            for (sectionIndex, group) in self.filteredGroups.enumerated() {
                if let rowIndex = group.items.firstIndex(where: { $0.id == downloadId }) {
                    let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                    if let cell = self.tableView.cellForRow(at: indexPath) as? DownloadItemCell {
                        cell.updateProgress(progress, bytesDownloaded: bytesDownloaded, totalBytes: totalBytes)
                    }
                }
            }
        }
    }

    @objc private func queueUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
        }
    }

    @objc private func themeDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.applyTheme()
            self?.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource

extension DownloadManagerViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredGroups.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredGroups[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return filteredGroups[section].displayTitle
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DownloadItemCell.reuseIdentifier, for: indexPath) as! DownloadItemCell
        let item = filteredGroups[indexPath.section].items[indexPath.row]
        cell.configure(with: item)
        cell.delegate = self
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DownloadManagerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = filteredGroups[indexPath.section].items[indexPath.row]

        var actions: [UIContextualAction] = []

        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completion in
            DownloadManagerService.shared.removeDownload(id: item.id)
            self?.reloadData()
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        actions.append(deleteAction)

        // Retry action for failed downloads
        if item.status == .failed || item.status == .cancelled {
            let retryAction = UIContextualAction(style: .normal, title: "Retry") { [weak self] _, _, completion in
                DownloadManagerService.shared.retryDownload(id: item.id)
                self?.reloadData()
                completion(true)
            }
            retryAction.backgroundColor = .systemBlue
            retryAction.image = UIImage(systemName: "arrow.clockwise")
            actions.append(retryAction)
        }

        return UISwipeActionsConfiguration(actions: actions)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = filteredGroups[indexPath.section].items[indexPath.row]

        // If completed, open the file
        if item.status == .completed {
            openCompletedFile(item)
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        }
    }
}

// MARK: - DownloadItemCellDelegate

extension DownloadManagerViewController: DownloadItemCellDelegate {

    func downloadCellDidTapAction(_ cell: DownloadItemCell, item: DownloadItem) {
        switch item.status {
        case .downloading:
            DownloadManagerService.shared.pauseDownload(id: item.id)

        case .paused:
            DownloadManagerService.shared.resumeDownload(id: item.id)

        case .pending:
            // Cancel pending download
            DownloadManagerService.shared.cancelDownload(id: item.id)

        case .failed, .cancelled:
            DownloadManagerService.shared.retryDownload(id: item.id)

        case .completed:
            openCompletedFile(item)
        }
    }

    private func openCompletedFile(_ item: DownloadItem) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(item.destinationPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            showAlert(title: "File Not Found", message: "The downloaded file could not be found.")
            return
        }

        // Navigate to appropriate viewer based on media type
        if item.mediaType == .video {
            let vlcVC = WebMViewController()
            vlcVC.videoURL = fileURL.absoluteString
            vlcVC.hideDownloadButton = true
            navigationController?.pushViewController(vlcVC, animated: true)
        } else {
            let imageVC = ImageViewController(imageURL: fileURL)
            navigationController?.pushViewController(imageVC, animated: true)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
