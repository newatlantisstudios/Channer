import UIKit
import AVFoundation

class FilesListVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIContextMenuInteractionDelegate {
    
    // MARK: - Types
    private enum ViewMode: Int {
        case grid
        case list
    }

    private enum ContentScope: Int {
        case allMedia
        case currentFolder
    }

    private struct FileItem {
        let url: URL
        let isDirectory: Bool
    }

    // MARK: - Properties
    private let rootDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    /// Items currently displayed.
    private var items: [FileItem] = []
    
    /// The current directory being displayed.
    private var currentDirectory: URL
    
    /// Current view mode (grid or list).
    private var viewMode: ViewMode = .grid

    /// Current content scope (all media or current folder).
    private var contentScope: ContentScope = .allMedia
    
    /// The collection view to display thumbnails of files.
    private var collectionView: UICollectionView!
    
    /// Tracks whether we're in selection mode
    private var isSelectionMode: Bool = false
    
    /// Set of selected index paths
    private var selectedIndexPaths: Set<IndexPath> = []
    
    /// Maximum number of concurrent video previews to limit resource usage.
    private let maxConcurrentVideoPreviews = 4

    /// Navigation bar buttons
    private var selectButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    private var deleteButton: UIBarButtonItem!
    private var moveButton: UIBarButtonItem!
    private var optionsButton: UIBarButtonItem!
    private var downloadManagerButton: UIBarButtonItem!
    
    // MARK: - Initializers
    /// Initializes the view controller with an optional directory.
    /// - Parameter directory: The directory to display. Defaults to the documents directory.
    init(directory: URL? = nil) {
        self.currentDirectory = directory ?? rootDirectory
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Required initializer with coder. Not implemented.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad - FilesListVC")
        view.backgroundColor = .systemBackground
        updateNavigationTitle()
        
        // Remove custom back/home button to use navigation controller's default back button
        // The navigation controller will automatically show a back button with an arrow
        
        // Set up navigation bar buttons
        setupNavigationBar()
        
        // Set up the collection view
        setupCollectionView()
        
        // Load files from the current directory
        loadFiles()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if MediaSettings.videoPreviewInDownloads && viewMode == .grid {
            updateVideoPreviewsForVisibleCells()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAllVideoPreviews()
    }

    // MARK: - Setup Methods
    /// Configures the collection view for thumbnail display.
    private func setupCollectionView() {
        let layout = makeLayout(for: viewMode)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(FileThumbnailCell.self, forCellWithReuseIdentifier: FileThumbnailCell.reuseIdentifier)
        collectionView.register(FileListCell.self, forCellWithReuseIdentifier: FileListCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        
        // Enable context menu interactions for delete functionality
        let interaction = UIContextMenuInteraction(delegate: self)
        collectionView.addInteraction(interaction)
        
        view.addSubview(collectionView)
        
        // Set up constraints for full screen
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func makeLayout(for viewMode: ViewMode) -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        switch viewMode {
        case .grid:
            layout.minimumInteritemSpacing = 5
            layout.minimumLineSpacing = 5
            layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        case .list:
            layout.minimumInteritemSpacing = 0
            layout.minimumLineSpacing = 1
            layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        }
        return layout
    }

    private func updateLayout(animated: Bool = true) {
        let layout = makeLayout(for: viewMode)
        if animated {
            collectionView.setCollectionViewLayout(layout, animated: true) { [weak self] _ in
                self?.collectionView.collectionViewLayout.invalidateLayout()
                self?.collectionView.reloadData()
            }
        } else {
            collectionView.setCollectionViewLayout(layout, animated: false)
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
        }
    }

    private func updateNavigationTitle() {
        switch contentScope {
        case .allMedia:
            navigationItem.title = "All Media"

        case .currentFolder:
            navigationItem.title = currentDirectory == rootDirectory ? "App Folder" : currentDirectory.lastPathComponent
        }
    }
    
    /// Sets up navigation bar buttons for selection mode
    private func setupNavigationBar() {
        selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(selectButtonTapped))
        cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonTapped))
        deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelectedItems))
        deleteButton.isEnabled = false
        moveButton = UIBarButtonItem(title: "Move", style: .plain, target: self, action: #selector(moveSelectedItemsAction))
        moveButton.isEnabled = false

        downloadManagerButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down.circle"),
            style: .plain,
            target: self,
            action: #selector(openDownloadManager)
        )

        optionsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: nil, action: nil)
        optionsButton.menu = makeOptionsMenu()

        navigationItem.rightBarButtonItems = [selectButton, optionsButton, downloadManagerButton]
    }

    private func makeOptionsMenu() -> UIMenu {
        let gridAction = UIAction(
            title: "Grid View",
            image: UIImage(systemName: "square.grid.2x2"),
            state: viewMode == .grid ? .on : .off
        ) { [weak self] _ in
            self?.setViewMode(.grid)
        }

        let listAction = UIAction(
            title: "List View",
            image: UIImage(systemName: "list.bullet"),
            state: viewMode == .list ? .on : .off
        ) { [weak self] _ in
            self?.setViewMode(.list)
        }

        let viewMenu = UIMenu(title: "View Mode", options: .displayInline, children: [gridAction, listAction])

        let allMediaAction = UIAction(
            title: "All Media",
            image: UIImage(systemName: "square.stack"),
            state: contentScope == .allMedia ? .on : .off
        ) { [weak self] _ in
            self?.setContentScope(.allMedia)
        }

        let folderAction = UIAction(
            title: "App Folder",
            image: UIImage(systemName: "folder"),
            state: contentScope == .currentFolder ? .on : .off
        ) { [weak self] _ in
            self?.setContentScope(.currentFolder)
        }

        let scopeMenu = UIMenu(title: "Content", options: .displayInline, children: [allMediaAction, folderAction])

        let newFolderAttributes: UIMenuElement.Attributes = contentScope == .currentFolder ? [] : [.disabled]
        let newFolderAction = UIAction(
            title: "New Folder",
            image: UIImage(systemName: "folder.badge.plus"),
            attributes: newFolderAttributes
        ) { [weak self] _ in
            guard let self = self else { return }
            self.promptForNewFolder(in: self.currentDirectory)
        }

        return UIMenu(title: "", children: [viewMenu, scopeMenu, newFolderAction])
    }

    private func refreshOptionsMenu() {
        optionsButton.menu = makeOptionsMenu()
    }

    private func setViewMode(_ mode: ViewMode) {
        guard viewMode != mode else { return }
        stopAllVideoPreviews()
        viewMode = mode
        updateLayout()
        refreshOptionsMenu()

        if MediaSettings.videoPreviewInDownloads && mode == .grid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.updateVideoPreviewsForVisibleCells()
            }
        }
    }

    private func setContentScope(_ scope: ContentScope) {
        guard contentScope != scope else { return }
        contentScope = scope
        if isSelectionMode {
            exitSelectionMode()
        }
        updateNavigationTitle()
        refreshOptionsMenu()
        loadFiles()
    }

    private func promptForNewFolder(in directory: URL, completion: ((URL) -> Void)? = nil) {
        let alert = UIAlertController(title: "New Folder", message: "Enter a name for the new folder.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Folder name"
            textField.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let folderName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !folderName.isEmpty else { return }
            self.createFolder(named: folderName, in: directory, completion: completion)
        })
        present(alert, animated: true)
    }

    private func createFolder(named folderName: String, in directory: URL, completion: ((URL) -> Void)? = nil) {
        let folderURL = directory.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            completion?(folderURL)
            if completion == nil {
                loadFiles()
            }
        } catch {
            let alert = UIAlertController(
                title: "Folder Not Created",
                message: "Unable to create the folder. \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func openDownloadManager() {
        let downloadManagerVC = DownloadManagerViewController()
        navigationController?.pushViewController(downloadManagerVC, animated: true)
    }
    
    // MARK: - Selection Mode Actions
    
    @objc private func selectButtonTapped() {
        isSelectionMode = true
        collectionView.allowsMultipleSelection = true
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItems = [deleteButton, moveButton]
        
        updateSelectionActionStates()
    }
    
    @objc private func cancelButtonTapped() {
        exitSelectionMode()
    }
    
    @objc private func deleteSelectedItems() {
        guard !selectedIndexPaths.isEmpty else { return }
        
        let itemCount = selectedIndexPaths.count
        
        let alert = UIAlertController(
            title: "Delete \(itemCount) Item\(itemCount > 1 ? "s" : "")",
            message: "Are you sure you want to delete \(itemCount) item\(itemCount > 1 ? "s" : "")? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.performBatchDelete()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }

    @objc private func moveSelectedItemsAction() {
        guard !selectedIndexPaths.isEmpty else { return }

        let baseDirectory = contentScope == .currentFolder ? currentDirectory : rootDirectory
        let destinationFolders = fetchSubfolders(in: baseDirectory)

        let alert = UIAlertController(title: "Move to Folder", message: nil, preferredStyle: .actionSheet)

        if contentScope == .allMedia {
            alert.addAction(UIAlertAction(title: "App Folder", style: .default) { [weak self] _ in
                self?.moveSelectedItems(to: baseDirectory)
            })
        } else if currentDirectory != rootDirectory {
            let parentDirectory = currentDirectory.deletingLastPathComponent()
            let parentName = parentDirectory.lastPathComponent.isEmpty ? "App Folder" : parentDirectory.lastPathComponent
            alert.addAction(UIAlertAction(title: "Move to \(parentName)", style: .default) { [weak self] _ in
                self?.moveSelectedItems(to: parentDirectory)
            })
        }

        for folderURL in destinationFolders {
            let folderName = folderURL.lastPathComponent
            alert.addAction(UIAlertAction(title: folderName, style: .default) { [weak self] _ in
                self?.moveSelectedItems(to: folderURL)
            })
        }

        if contentScope == .currentFolder {
            alert.addAction(UIAlertAction(title: "New Folder", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.promptForNewFolder(in: baseDirectory) { newFolderURL in
                    self.moveSelectedItems(to: newFolderURL)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = moveButton
        }

        present(alert, animated: true)
    }

    private func fetchSubfolders(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return contents.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            print("DEBUG: FilesListVC - Failed to fetch subfolders: \(error)")
            return []
        }
    }

    private func moveSelectedItems(to destinationFolder: URL) {
        let fileManager = FileManager.default
        var failedMoves: [String] = []

        let sortedIndexPaths = selectedIndexPaths.sorted { $0.row > $1.row }

        for indexPath in sortedIndexPaths {
            let item = items[indexPath.row]
            let sourceURL = item.url

            if sourceURL.deletingLastPathComponent() == destinationFolder {
                continue
            }

            if item.isDirectory {
                let sourcePath = sourceURL.standardizedFileURL.path
                let destinationPath = destinationFolder.standardizedFileURL.path
                if destinationPath.hasPrefix(sourcePath + "/") {
                    failedMoves.append(sourceURL.lastPathComponent)
                    continue
                }
            }

            let destinationURL = uniqueDestinationURL(for: sourceURL, in: destinationFolder)

            do {
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                if !item.isDirectory {
                    moveThumbnailIfNeeded(from: sourceURL, to: destinationURL)
                }
            } catch {
                print("ERROR: FilesListVC - Failed to move item: \(error.localizedDescription)")
                failedMoves.append(sourceURL.lastPathComponent)
            }
        }

        exitSelectionMode()
        loadFiles()

        if !failedMoves.isEmpty {
            let alert = UIAlertController(
                title: "Move Failed",
                message: "Could not move: \(failedMoves.joined(separator: ", "))",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func uniqueDestinationURL(for sourceURL: URL, in destinationFolder: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension

        var destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(baseName) \(counter)"
            let fileName = fileExtension.isEmpty ? newName : "\(newName).\(fileExtension)"
            destinationURL = destinationFolder.appendingPathComponent(fileName)
            counter += 1
        }

        return destinationURL
    }

    private func moveThumbnailIfNeeded(from sourceURL: URL, to destinationURL: URL) {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "webm" || fileExtension == "mp4" else { return }

        let fileManager = FileManager.default
        let thumbnailURL = getLocalThumbnailURL(for: sourceURL)
        let destinationThumbnailURL = getLocalThumbnailURL(for: destinationURL)

        guard fileManager.fileExists(atPath: thumbnailURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: destinationThumbnailURL.path) {
                try fileManager.removeItem(at: destinationThumbnailURL)
            }
            try fileManager.moveItem(at: thumbnailURL, to: destinationThumbnailURL)
        } catch {
            print("DEBUG: FilesListVC - Failed to move thumbnail: \(error)")
        }
    }
    
    private func performBatchDelete() {
        let fileManager = FileManager.default
        var failedDeletions: [String] = []
        var indexPathsToDelete: [IndexPath] = []
        
        let sortedIndexPaths = selectedIndexPaths.sorted { $0.row > $1.row }
        
        for indexPath in sortedIndexPaths {
            let item = items[indexPath.row]
            let fileURL = item.url
            
            do {
                if !item.isDirectory && (fileURL.pathExtension.lowercased() == "webm" || fileURL.pathExtension.lowercased() == "mp4") {
                    let thumbnailURL = getLocalThumbnailURL(for: fileURL)
                    if fileManager.fileExists(atPath: thumbnailURL.path) {
                        try fileManager.removeItem(at: thumbnailURL)
                    }
                }
                
                try fileManager.removeItem(at: fileURL)
                
                items.remove(at: indexPath.row)
                indexPathsToDelete.append(indexPath)
                
                print("DEBUG: FilesListVC - Successfully deleted: \(fileURL.lastPathComponent)")
                
            } catch {
                print("ERROR: FilesListVC - Failed to delete file: \(error.localizedDescription)")
                failedDeletions.append(fileURL.lastPathComponent)
            }
        }
        
        collectionView.deleteItems(at: indexPathsToDelete)
        
        exitSelectionMode()
        
        if !failedDeletions.isEmpty {
            let errorAlert = UIAlertController(
                title: "Some Deletions Failed",
                message: "Could not delete: \(failedDeletions.joined(separator: ", "))",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(errorAlert, animated: true, completion: nil)
        }
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        let selectedItems = selectedIndexPaths
        selectedIndexPaths.removeAll()
        collectionView.allowsMultipleSelection = false
        
        // Deselect all items
        for indexPath in selectedItems {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = [selectButton, optionsButton, downloadManagerButton]
        
        // Refresh collection view to remove selection UI
        collectionView.reloadData()
    }
    
    private func updateSelectionActionStates() {
        let hasSelection = !selectedIndexPaths.isEmpty
        deleteButton.isEnabled = hasSelection
        moveButton.isEnabled = hasSelection
    }
    
    // MARK: - Data Loading
    /// Loads files based on the selected scope.
    func loadFiles() {
        let fileManager = FileManager.default
        var loadedItems: [FileItem] = []

        switch contentScope {
        case .allMedia:
            if let enumerator = fileManager.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                        if resourceValues.isRegularFile == true && resourceValues.isDirectory == false {
                            loadedItems.append(FileItem(url: fileURL, isDirectory: false))
                        }
                    } catch {
                        print("DEBUG: FilesListVC - Error reading file properties: \(error)")
                    }
                }
            }

        case .currentFolder:
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: currentDirectory,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for fileURL in contents {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    let isFile = resourceValues.isRegularFile ?? false
                    if isDirectory || isFile {
                        loadedItems.append(FileItem(url: fileURL, isDirectory: isDirectory))
                    }
                }
            } catch {
                print("DEBUG: FilesListVC - Error reading directory contents: \(error)")
            }
        }

        if contentScope == .currentFolder {
            let directories = loadedItems.filter { $0.isDirectory }.sorted {
                $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
            let files = loadedItems.filter { !$0.isDirectory }.sorted {
                $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
            items = directories + files
        } else {
            items = loadedItems.sorted {
                $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
        }

        if !selectedIndexPaths.isEmpty {
            selectedIndexPaths.removeAll()
            updateSelectionActionStates()
        }

        print("DEBUG: FilesListVC - Loaded \(items.count) items in scope: \(contentScope)")
        collectionView.reloadData()

        // Start video previews after cells are laid out
        if MediaSettings.videoPreviewInDownloads && viewMode == .grid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.updateVideoPreviewsForVisibleCells()
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    /// Returns the number of items in the collection view section.
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    /// Configures and returns the cell for the given index path.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.row]
        switch viewMode {
        case .grid:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FileThumbnailCell.reuseIdentifier, for: indexPath) as! FileThumbnailCell
            configureGridCell(cell, with: item, at: indexPath)
            return cell

        case .list:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell
            configureListCell(cell, with: item, at: indexPath)
            return cell
        }
    }

    private func configureGridCell(_ cell: FileThumbnailCell, with item: FileItem, at indexPath: IndexPath) {
        let fileURL = item.url
        let fileName = fileURL.lastPathComponent

        if item.isDirectory {
            let folderImage = UIImage(systemName: "folder.fill")
            cell.configure(with: folderImage, fileName: fileName, isDirectory: true)
            cell.setVideoIconVisible(false)
        } else {
            configureFileCell(cell: cell, fileURL: fileURL, fileName: fileName, indexPath: indexPath, detailText: detailTextForItem(item))
            let ext = fileURL.pathExtension.lowercased()
            let isVideo = ext == "webm" || ext == "mp4" || ext == "mov"
            cell.setVideoIconVisible(isVideo && !MediaSettings.videoPreviewInDownloads)
        }

        let isSelected = selectedIndexPaths.contains(indexPath)
        cell.setSelectionMode(isSelectionMode, isSelected: isSelected)
    }

    private func configureListCell(_ cell: FileListCell, with item: FileItem, at indexPath: IndexPath) {
        let fileURL = item.url
        let fileName = fileURL.lastPathComponent
        let detailText = detailTextForItem(item)

        if item.isDirectory {
            let folderImage = UIImage(systemName: "folder.fill")
            cell.configure(with: folderImage, fileName: fileName, isDirectory: true, detailText: detailText)
        } else {
            configureFileCell(cell: cell, fileURL: fileURL, fileName: fileName, indexPath: indexPath, detailText: detailText)
        }

        let isSelected = selectedIndexPaths.contains(indexPath)
        cell.setSelectionMode(isSelectionMode, isSelected: isSelected)
    }

    private func configureFileCell(cell: FileThumbnailCell, fileURL: URL, fileName: String, indexPath: IndexPath, detailText: String?) {
        let fileExtension = fileURL.pathExtension.lowercased()

        if let savedThumbnail = loadSavedThumbnail(for: fileURL) {
            print("DEBUG: FilesListVC - Using saved thumbnail for: \(fileURL.lastPathComponent)")
            cell.configure(with: savedThumbnail, fileName: fileName, isDirectory: false)
        } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
            if let image = UIImage(contentsOfFile: fileURL.path) {
                let thumbnail = resizeImage(image, to: CGSize(width: 150, height: 150))
                cell.configure(with: thumbnail, fileName: fileName, isDirectory: false)
            } else {
                let imageIcon = UIImage(systemName: "photo.fill")
                cell.configure(with: imageIcon, fileName: fileName, isDirectory: false)
            }
        } else if fileExtension == "webm" || fileExtension == "mp4" {
            print("DEBUG: FilesListVC - No saved thumbnail found for video: \(fileURL.path)")

            let videoImage = UIImage(systemName: "video.fill")
            cell.configure(with: videoImage, fileName: fileName, isDirectory: false)

            generateThumbnail(for: fileURL) { [weak self] image in
                guard let self = self, let image = image else { return }
                DispatchQueue.main.async {
                    self.updateVisibleCell(at: indexPath, image: image, fileName: fileName, isDirectory: false, detailText: detailText)
                }
            }
        } else if fileExtension == "gif" {
            let image = UIImage(contentsOfFile: fileURL.path)
            cell.configure(with: image, fileName: fileName, isDirectory: false)
        } else {
            let fileImage = UIImage(systemName: "doc.fill")
            cell.configure(with: fileImage, fileName: fileName, isDirectory: false)
        }
    }

    private func configureFileCell(cell: FileListCell, fileURL: URL, fileName: String, indexPath: IndexPath, detailText: String?) {
        let fileExtension = fileURL.pathExtension.lowercased()

        if let savedThumbnail = loadSavedThumbnail(for: fileURL) {
            print("DEBUG: FilesListVC - Using saved thumbnail for: \(fileURL.lastPathComponent)")
            cell.configure(with: savedThumbnail, fileName: fileName, isDirectory: false, detailText: detailText)
        } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
            if let image = UIImage(contentsOfFile: fileURL.path) {
                let thumbnail = resizeImage(image, to: CGSize(width: 150, height: 150))
                cell.configure(with: thumbnail, fileName: fileName, isDirectory: false, detailText: detailText)
            } else {
                let imageIcon = UIImage(systemName: "photo.fill")
                cell.configure(with: imageIcon, fileName: fileName, isDirectory: false, detailText: detailText)
            }
        } else if fileExtension == "webm" || fileExtension == "mp4" {
            print("DEBUG: FilesListVC - No saved thumbnail found for video: \(fileURL.path)")

            let videoImage = UIImage(systemName: "video.fill")
            cell.configure(with: videoImage, fileName: fileName, isDirectory: false, detailText: detailText)

            generateThumbnail(for: fileURL) { [weak self] image in
                guard let self = self, let image = image else { return }
                DispatchQueue.main.async {
                    self.updateVisibleCell(at: indexPath, image: image, fileName: fileName, isDirectory: false, detailText: detailText)
                }
            }
        } else if fileExtension == "gif" {
            let image = UIImage(contentsOfFile: fileURL.path)
            cell.configure(with: image, fileName: fileName, isDirectory: false, detailText: detailText)
        } else {
            let fileImage = UIImage(systemName: "doc.fill")
            cell.configure(with: fileImage, fileName: fileName, isDirectory: false, detailText: detailText)
        }
    }

    private func detailTextForItem(_ item: FileItem) -> String? {
        if item.isDirectory {
            return "Folder"
        }
        let ext = item.url.pathExtension
        return ext.isEmpty ? "File" : ext.uppercased()
    }

    private func updateVisibleCell(at indexPath: IndexPath, image: UIImage?, fileName: String, isDirectory: Bool, detailText: String?) {
        if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
            cell.configure(with: image, fileName: fileName, isDirectory: isDirectory)
            cell.setSelectionMode(isSelectionMode, isSelected: selectedIndexPaths.contains(indexPath))
        } else if let cell = collectionView.cellForItem(at: indexPath) as? FileListCell {
            cell.configure(with: image, fileName: fileName, isDirectory: isDirectory, detailText: detailText)
            cell.setSelectionMode(isSelectionMode, isSelected: selectedIndexPaths.contains(indexPath))
        }
    }
    
    // MARK: - UICollectionViewDelegate
    /// Handles the selection of an item in the collection view.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.insert(indexPath)
            updateSelectionActionStates()

            if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: true)
            } else if let cell = collectionView.cellForItem(at: indexPath) as? FileListCell {
                cell.setSelectionMode(isSelectionMode, isSelected: true)
            }
            return
        }

        let item = items[indexPath.row]
        if item.isDirectory {
            guard contentScope == .currentFolder else { return }
            let filesVC = FilesListVC(directory: item.url)
            filesVC.viewMode = viewMode
            filesVC.contentScope = .currentFolder
            navigationController?.pushViewController(filesVC, animated: true)
            return
        }

        let selectedURL = item.url

        print("DEBUG: FilesListVC - Selected file: \(selectedURL.lastPathComponent)")
        print("DEBUG: FilesListVC - File path: \(selectedURL.path)")
        print("DEBUG: FilesListVC - File extension: \(selectedURL.pathExtension.lowercased())")
        print("DEBUG: FilesListVC - File exists: \(FileManager.default.fileExists(atPath: selectedURL.path))")

        let fileExtension = selectedURL.pathExtension.lowercased()

        if ["jpg", "jpeg", "png"].contains(fileExtension) {
            print("DEBUG: FilesListVC - Opening image file with ImageViewController")
            let imageViewController = ImageViewController(imageURL: selectedURL)
            navigationController?.pushViewController(imageViewController, animated: true)
        } else if fileExtension == "gif" {
            print("DEBUG: FilesListVC - Opening GIF file with urlWeb for animation support")
            let urlWebViewController = urlWeb()
            urlWebViewController.images = [selectedURL]
            urlWebViewController.currentIndex = 0
            navigationController?.pushViewController(urlWebViewController, animated: true)
        } else if fileExtension == "webm" || fileExtension == "mp4" {
            print("DEBUG: FilesListVC - Opening local video with VLCKit (WebMViewController)")
            print("DEBUG: FilesListVC - Video URL: \(selectedURL.absoluteString)")

            let videoFiles: [URL] = items.compactMap { item in
                guard !item.isDirectory else { return nil }
                let ext = item.url.pathExtension.lowercased()
                return (ext == "webm" || ext == "mp4") ? item.url : nil
            }

            let selectedIndex = videoFiles.firstIndex(of: selectedURL) ?? 0

            let vlcVC = WebMViewController()
            vlcVC.videoURL = selectedURL.absoluteString
            vlcVC.videoURLs = videoFiles
            vlcVC.currentIndex = selectedIndex
            vlcVC.hideDownloadButton = true
            navigationController?.pushViewController(vlcVC, animated: true)
        } else {
            print("DEBUG: FilesListVC - Unsupported file type: \(fileExtension)")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.remove(indexPath)
            updateSelectionActionStates()

            // Update cell's selection state
            if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: false)
            } else if let cell = collectionView.cellForItem(at: indexPath) as? FileListCell {
                cell.setSelectionMode(isSelectionMode, isSelected: false)
            }
        }
    }

    /// Handles cell highlighting for touch feedback (matching ImageGalleryVC)
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
            cell.setHighlighted(true, animated: true)
        } else if let cell = collectionView.cellForItem(at: indexPath) as? FileListCell {
            cell.setHighlighted(true, animated: true)
        }
    }
    
    /// Handles removing cell highlighting (matching ImageGalleryVC)
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
            cell.setHighlighted(false, animated: true)
        } else if let cell = collectionView.cellForItem(at: indexPath) as? FileListCell {
            cell.setHighlighted(false, animated: true)
        }
    }

    
    // MARK: - UICollectionViewDelegateFlowLayout
    /// Defines the size of each item in the collection view.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return CGSize(width: 100, height: 100)
        }

        let availableWidth = collectionView.bounds.width - layout.sectionInset.left - layout.sectionInset.right

        switch viewMode {
        case .grid:
            let itemsPerRow: CGFloat = 4
            let totalSpacing = layout.minimumInteritemSpacing * (itemsPerRow - 1)
            let widthPerItem = (availableWidth - totalSpacing) / itemsPerRow
            let heightWithLabel = widthPerItem + 30
            return CGSize(width: widthPerItem, height: heightWithLabel)

        case .list:
            return CGSize(width: availableWidth, height: 64)
        }
    }
    
    // MARK: - Helper Methods
    /// Generates a thumbnail for video files.
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        print("DEBUG: FilesListVC - generateThumbnail called for: \(url.path)")
        print("DEBUG: FilesListVC - URL scheme: \(url.scheme ?? "nil")")
        print("DEBUG: FilesListVC - Is file URL: \(url.isFileURL)")
        
        // Check for VP9 codec which AVFoundation may not handle well
        if url.pathExtension.lowercased() == "webm" {
            do {
                let data = try Data(contentsOf: url, options: [.dataReadingMapped])
                let headerData = data.prefix(4096)
                let headerString = String(data: headerData, encoding: .ascii) ?? ""
                let isVP9 = headerString.range(of: "VP90", options: .caseInsensitive) != nil ||
                           headerString.range(of: "vp09", options: .caseInsensitive) != nil
                
                print("DEBUG: FilesListVC - Header VP9 detection: \(isVP9)")
                
                if isVP9 {
                    print("DEBUG: FilesListVC - VP9 detected - AVFoundation may fail, skipping thumbnail generation")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
            } catch {
                print("DEBUG: FilesListVC - Could not read file header: \(error)")
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            let asset = AVAsset(url: url)
            print("DEBUG: FilesListVC - Created AVAsset")
            
            // Check if asset is readable
            let duration = asset.duration
            print("DEBUG: FilesListVC - Asset duration: \(duration.seconds) seconds")
            print("DEBUG: FilesListVC - Asset is readable: \(asset.isReadable)")
            
            // If asset is not readable or has invalid duration, fail fast
            if !asset.isReadable || duration.seconds <= 0 || duration.seconds.isNaN {
                print("DEBUG: FilesListVC - Asset is not readable or has invalid duration")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceBefore = CMTime.zero
            imageGenerator.requestedTimeToleranceAfter = CMTime.zero
            
            // Try multiple time points in case the video has issues at the beginning
            let timesToTry = [
                CMTime(seconds: 0.5, preferredTimescale: 60),
                CMTime(seconds: 1, preferredTimescale: 60),
                CMTime(seconds: 0, preferredTimescale: 60)
            ]
            
            var thumbnailGenerated = false
            
            for time in timesToTry {
                if thumbnailGenerated { break }
                
                print("DEBUG: FilesListVC - Trying to generate thumbnail at time: \(time.seconds)s")
                
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let thumbnailImage = UIImage(cgImage: cgImage)
                    
                    let size = CGSize(width: 150, height: 150)
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    thumbnailImage.draw(in: CGRect(origin: .zero, size: size))
                    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    print("DEBUG: FilesListVC - Successfully generated thumbnail at time: \(time.seconds)s")
                    thumbnailGenerated = true
                    
                    DispatchQueue.main.async {
                        completion(scaledImage)
                    }
                    break
                } catch {
                    print("DEBUG: FilesListVC - Error generating thumbnail at time \(time.seconds)s: \(error.localizedDescription)")
                    print("DEBUG: FilesListVC - Error details: \(error)")
                }
            }
            
            if !thumbnailGenerated {
                print("DEBUG: FilesListVC - Failed to generate thumbnail at all time points")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Thumbnail Helper Methods
    
    /// Loads a saved thumbnail for a media file
    private func loadSavedThumbnail(for mediaURL: URL) -> UIImage? {
        let thumbnailURL = getLocalThumbnailURL(for: mediaURL)
        
        guard FileManager.default.fileExists(atPath: thumbnailURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: thumbnailURL)
            return UIImage(data: data)
        } catch {
            print("DEBUG: FilesListVC - Failed to load thumbnail: \(error)")
            return nil
        }
    }
    
    /// Gets the URL where a thumbnail should be stored for a given media file
    private func getLocalThumbnailURL(for mediaURL: URL) -> URL {
        let directory = mediaURL.deletingLastPathComponent()
        let fileName = mediaURL.deletingPathExtension().lastPathComponent
        let thumbnailFileName = ".\(fileName).thumbnail.png" // Hidden file with dot prefix
        return directory.appendingPathComponent(thumbnailFileName)
    }
    
    /// Resizes an image to the specified size
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    // MARK: - UIContextMenuInteractionDelegate
    
    /// Provides context menu configuration for collection view items
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        // Disable context menu during selection mode
        guard !isSelectionMode else { return nil }
        
        let locationInCollectionView = interaction.location(in: collectionView)
        
        guard let indexPath = collectionView.indexPathForItem(at: locationInCollectionView) else {
            return nil
        }
        
        let item = items[indexPath.row]
        let fileName = item.url.lastPathComponent
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.showDeleteConfirmation(for: item, at: indexPath)
            }
            
            return UIMenu(title: fileName, children: [deleteAction])
        }
    }
    
    // MARK: - Delete Functionality
    
    /// Shows a confirmation alert before deleting a file
    private func showDeleteConfirmation(for item: FileItem, at indexPath: IndexPath) {
        let fileName = item.url.lastPathComponent
        let itemType = item.isDirectory ? "folder" : "file"
        
        let alert = UIAlertController(
            title: "Delete \(itemType.capitalized)",
            message: "Are you sure you want to delete \"\(fileName)\"? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteItem(item, at: indexPath)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    /// Deletes the file at the specified URL and updates the collection view
    private func deleteItem(_ item: FileItem, at indexPath: IndexPath) {
        let fileManager = FileManager.default
        let fileURL = item.url
        
        do {
            if !item.isDirectory && (fileURL.pathExtension.lowercased() == "webm" || fileURL.pathExtension.lowercased() == "mp4") {
                let thumbnailURL = getLocalThumbnailURL(for: fileURL)
                if fileManager.fileExists(atPath: thumbnailURL.path) {
                    try fileManager.removeItem(at: thumbnailURL)
                    print("DEBUG: FilesListVC - Deleted thumbnail for: \(fileURL.lastPathComponent)")
                }
            }
            
            try fileManager.removeItem(at: fileURL)
            
            items.remove(at: indexPath.row)
            
            collectionView.deleteItems(at: [indexPath])
            
            print("DEBUG: FilesListVC - Successfully deleted: \(fileURL.lastPathComponent)")
            
        } catch {
            print("ERROR: FilesListVC - Failed to delete file: \(error.localizedDescription)")
            
            let errorAlert = UIAlertController(
                title: "Delete Failed",
                message: "Could not delete \"\(fileURL.lastPathComponent)\". \(error.localizedDescription)",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(errorAlert, animated: true, completion: nil)
        }
    }

    // MARK: - Video Preview Management

    /// Called when the user scrolls the collection view. Updates video previews for visible cells.
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if MediaSettings.videoPreviewInDownloads && viewMode == .grid {
            updateVideoPreviewsForVisibleCells()
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate && MediaSettings.videoPreviewInDownloads && viewMode == .grid {
            updateVideoPreviewsForVisibleCells()
        }
    }

    /// Starts video previews for visible video cells and stops previews for cells that scrolled off-screen.
    private func updateVideoPreviewsForVisibleCells() {
        guard MediaSettings.videoPreviewInDownloads, viewMode == .grid else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        var activeCount = 0

        // Sort so we start previews for cells closest to center first
        let center = collectionView.bounds.midY
        let sorted = visibleIndexPaths.sorted { a, b in
            guard let cellA = collectionView.cellForItem(at: a),
                  let cellB = collectionView.cellForItem(at: b) else { return false }
            return abs(cellA.frame.midY - center) < abs(cellB.frame.midY - center)
        }

        // Collect which index paths should be playing
        var shouldPlaySet = Set<IndexPath>()
        for indexPath in sorted {
            guard indexPath.row < items.count else { continue }
            let item = items[indexPath.row]
            guard !item.isDirectory else { continue }
            let ext = item.url.pathExtension.lowercased()
            guard ext == "webm" || ext == "mp4" || ext == "mov" else { continue }

            if activeCount < maxConcurrentVideoPreviews {
                shouldPlaySet.insert(indexPath)
                activeCount += 1
            }
        }

        // Stop previews for cells no longer in the play set
        for indexPath in visibleIndexPaths {
            guard let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell else { continue }
            if !shouldPlaySet.contains(indexPath) && cell.isPlayingVideoPreview {
                cell.stopVideoPreview()
            }
        }

        // Start previews for cells in the play set that aren't already playing
        for indexPath in shouldPlaySet {
            guard indexPath.row < items.count else { continue }
            guard let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell else { continue }
            if !cell.isPlayingVideoPreview {
                let item = items[indexPath.row]
                cell.startVideoPreview(url: item.url)
            }
        }
    }

    /// Stops all active video previews.
    private func stopAllVideoPreviews() {
        for cell in collectionView.visibleCells {
            if let thumbnailCell = cell as? FileThumbnailCell {
                thumbnailCell.stopVideoPreview()
            }
        }
    }
}
