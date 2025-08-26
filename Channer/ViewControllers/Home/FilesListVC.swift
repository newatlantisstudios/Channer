import UIKit
import AVFoundation

class FilesListVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIContextMenuInteractionDelegate {
    
    // MARK: - Properties
    /// An array to hold file URLs.
    var files: [URL] = []
    
    /// The current directory being displayed.
    var currentDirectory: URL
    
    /// The collection view to display thumbnails of files.
    var collectionView: UICollectionView!
    
    /// Tracks whether we're in selection mode
    var isSelectionMode: Bool = false
    
    /// Set of selected index paths
    var selectedIndexPaths: Set<IndexPath> = []
    
    /// Navigation bar buttons
    var selectButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    var deleteButton: UIBarButtonItem!
    
    // MARK: - Initializers
    /// Initializes the view controller with an optional directory.
    /// - Parameter directory: The directory to display. Defaults to the documents directory.
    init(directory: URL? = nil) {
        self.currentDirectory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
        self.navigationItem.title = "Files"
        
        // Remove custom back/home button to use navigation controller's default back button
        // The navigation controller will automatically show a back button with an arrow
        
        // Set up navigation bar buttons
        setupNavigationBar()
        
        // Set up the collection view
        setupCollectionView()
        
        // Load files from the current directory
        loadFiles()
    }
    
    // MARK: - Setup Methods
    /// Configures the collection view for thumbnail display.
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(FileThumbnailCell.self, forCellWithReuseIdentifier: FileThumbnailCell.reuseIdentifier)
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
    
    /// Sets up navigation bar buttons for selection mode
    private func setupNavigationBar() {
        selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(selectButtonTapped))
        cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonTapped))
        deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelectedItems))
        deleteButton.isEnabled = false
        
        navigationItem.rightBarButtonItem = selectButton
    }
    
    // MARK: - Selection Mode Actions
    
    @objc private func selectButtonTapped() {
        isSelectionMode = true
        collectionView.allowsMultipleSelection = true
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = deleteButton
        
        updateDeleteButtonState()
    }
    
    @objc private func cancelButtonTapped() {
        exitSelectionMode()
    }
    
    @objc private func deleteSelectedItems() {
        guard !selectedIndexPaths.isEmpty else { return }
        
        let selectedFiles = selectedIndexPaths.map { files[$0.row] }
        let fileCount = selectedFiles.count
        
        let alert = UIAlertController(
            title: "Delete \(fileCount) Item\(fileCount > 1 ? "s" : "")",
            message: "Are you sure you want to delete \(fileCount) item\(fileCount > 1 ? "s" : "")? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.performBatchDelete(selectedFiles)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func performBatchDelete(_ filesToDelete: [URL]) {
        let fileManager = FileManager.default
        var failedDeletions: [String] = []
        var indexPathsToDelete: [IndexPath] = []
        
        // Sort selected index paths in descending order to delete from the end first
        let sortedIndexPaths = selectedIndexPaths.sorted { $0.row > $1.row }
        
        for indexPath in sortedIndexPaths {
            let fileURL = files[indexPath.row]
            
            do {
                // If it's a video file, also delete its thumbnail
                if fileURL.pathExtension.lowercased() == "webm" || fileURL.pathExtension.lowercased() == "mp4" {
                    let thumbnailURL = getLocalThumbnailURL(for: fileURL)
                    if fileManager.fileExists(atPath: thumbnailURL.path) {
                        try fileManager.removeItem(at: thumbnailURL)
                    }
                }
                
                // Delete the main file or directory
                try fileManager.removeItem(at: fileURL)
                
                // Remove from data source (removing from end to maintain indices)
                files.remove(at: indexPath.row)
                indexPathsToDelete.append(indexPath)
                
                print("DEBUG: FilesListVC - Successfully deleted: \(fileURL.lastPathComponent)")
                
            } catch {
                print("ERROR: FilesListVC - Failed to delete file: \(error.localizedDescription)")
                failedDeletions.append(fileURL.lastPathComponent)
            }
        }
        
        // Update collection view
        collectionView.deleteItems(at: indexPathsToDelete)
        
        // Exit selection mode
        exitSelectionMode()
        
        // Show error message if any deletions failed
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
        selectedIndexPaths.removeAll()
        collectionView.allowsMultipleSelection = false
        
        // Deselect all items
        if let selectedItems = collectionView.indexPathsForSelectedItems {
            for indexPath in selectedItems {
                collectionView.deselectItem(at: indexPath, animated: false)
            }
        }
        
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = selectButton
        
        // Refresh collection view to remove selection UI
        collectionView.reloadData()
    }
    
    private func updateDeleteButtonState() {
        deleteButton.isEnabled = !selectedIndexPaths.isEmpty
    }
    
    // MARK: - Data Loading
    /// Loads files from the current directory into the files array.
    func loadFiles() {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: nil)
            files = fileURLs.filter { !$0.lastPathComponent.hasPrefix(".") } // Filter out hidden files
            print("DEBUG: FilesListVC - Loaded \(files.count) files from directory: \(currentDirectory.path)")
            collectionView.reloadData()
        } catch {
            print("Error loading files from directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UICollectionViewDataSource
    /// Returns the number of items in the collection view section.
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return files.count
    }
    
    /// Configures and returns the cell for the given index path.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FileThumbnailCell.reuseIdentifier, for: indexPath) as! FileThumbnailCell
        let fileURL = files[indexPath.row]
        let fileName = fileURL.lastPathComponent
        let isDirectory = fileURL.hasDirectoryPath
        
        if isDirectory {
            // Display folder icon for directories
            let folderImage = UIImage(systemName: "folder.fill")
            cell.configure(with: folderImage, fileName: fileName, isDirectory: true)
        } else {
            let fileExtension = fileURL.pathExtension.lowercased()
            
            // First try to load a saved thumbnail
            if let savedThumbnail = loadSavedThumbnail(for: fileURL) {
                print("DEBUG: FilesListVC - Using saved thumbnail for: \(fileURL.lastPathComponent)")
                cell.configure(with: savedThumbnail, fileName: fileName, isDirectory: false)
            } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
                // For images, generate thumbnail from the actual image
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    let thumbnail = resizeImage(image, to: CGSize(width: 150, height: 150))
                    cell.configure(with: thumbnail, fileName: fileName, isDirectory: false)
                } else {
                    let imageIcon = UIImage(systemName: "photo.fill")
                    cell.configure(with: imageIcon, fileName: fileName, isDirectory: false)
                }
            } else if fileExtension == "webm" || fileExtension == "mp4" {
                print("DEBUG: FilesListVC - No saved thumbnail found for video: \(fileURL.path)")
                
                // Set fallback icon immediately
                let videoImage = UIImage(systemName: "video.fill")
                cell.configure(with: videoImage, fileName: fileName, isDirectory: false)
                
                // Try to generate thumbnail as fallback (but this should rarely happen now)
                generateThumbnail(for: fileURL) { image in
                    DispatchQueue.main.async {
                        if let image = image {
                            print("DEBUG: FilesListVC - Generated fallback thumbnail for \(fileURL.lastPathComponent)")
                            cell.configure(with: image, fileName: fileName, isDirectory: false)
                        }
                    }
                }
            } else if fileExtension == "gif" {
                // For GIFs, show the actual image as thumbnail
                let image = UIImage(contentsOfFile: fileURL.path)
                cell.configure(with: image, fileName: fileName, isDirectory: false)
            } else {
                // Display generic file icon for other file types
                let fileImage = UIImage(systemName: "doc.fill")
                cell.configure(with: fileImage, fileName: fileName, isDirectory: false)
            }
        }
        
        // Configure selection mode UI
        let isSelected = selectedIndexPaths.contains(indexPath)
        cell.setSelectionMode(isSelectionMode, isSelected: isSelected)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    /// Handles the selection of an item in the collection view.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.insert(indexPath)
            updateDeleteButtonState()
            
            // Update cell's selection state
            if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: true)
            }
            return
        }
        
        let selectedURL = files[indexPath.row]
            
            print("DEBUG: FilesListVC - Selected file: \(selectedURL.lastPathComponent)")
            print("DEBUG: FilesListVC - File path: \(selectedURL.path)")
            print("DEBUG: FilesListVC - File extension: \(selectedURL.pathExtension.lowercased())")
            print("DEBUG: FilesListVC - Is directory: \(selectedURL.hasDirectoryPath)")
            print("DEBUG: FilesListVC - File exists: \(FileManager.default.fileExists(atPath: selectedURL.path))")
            
            if selectedURL.hasDirectoryPath {
                print("DEBUG: FilesListVC - Handling directory selection")
                if selectedURL.lastPathComponent.lowercased() == "images" {
                    print("DEBUG: FilesListVC - Opening Images directory with ThumbnailGridVC")
                    // Push a thumbnail grid for image files
                    let imageGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["jpg", "jpeg", "png"])
                    navigationController?.pushViewController(imageGalleryVC, animated: true)
                } else if selectedURL.lastPathComponent.lowercased() == "webm" {
                    print("DEBUG: FilesListVC - Opening WebM directory with ThumbnailGridVC")
                    // Push a thumbnail grid for webm files
                    let webmGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["webm"])
                    navigationController?.pushViewController(webmGalleryVC, animated: true)
                } else {
                    print("DEBUG: FilesListVC - Opening generic directory with FilesListVC")
                    // For other directories, push FilesListVC to continue exploring
                    let filesListVC = FilesListVC(directory: selectedURL)
                    navigationController?.pushViewController(filesListVC, animated: true)
                }
            } else {
                print("DEBUG: FilesListVC - Handling individual file selection")
                // Handle individual file selection
                let fileExtension = selectedURL.pathExtension.lowercased()
                
                if ["jpg", "jpeg", "png"].contains(fileExtension) {
                    print("DEBUG: FilesListVC - Opening image file with ImageViewController")
                    // Open image in ImageViewController
                    let imageViewController = ImageViewController(imageURL: selectedURL)
                    navigationController?.pushViewController(imageViewController, animated: true)
                } else if fileExtension == "gif" {
                    print("DEBUG: FilesListVC - Opening GIF file with urlWeb for animation support")
                    // Open GIF in urlWeb for animation support
                    let urlWebViewController = urlWeb()
                    urlWebViewController.images = [selectedURL]
                    urlWebViewController.currentIndex = 0
                    navigationController?.pushViewController(urlWebViewController, animated: true)
                } else if fileExtension == "webm" || fileExtension == "mp4" {
                    print("DEBUG: FilesListVC - Opening local video with VLCKit (WebMViewController)")
                    print("DEBUG: FilesListVC - Video URL: \(selectedURL.absoluteString)")
                    // Use VLCKit-only player for local video files
                    let vlcVC = WebMViewController()
                    vlcVC.videoURL = selectedURL.absoluteString
                    vlcVC.hideDownloadButton = true
                    navigationController?.pushViewController(vlcVC, animated: true)
                } else {
                    print("DEBUG: FilesListVC - Unsupported file type: \(fileExtension)")
                }
            }
        }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.remove(indexPath)
            updateDeleteButtonState()
            
            // Update cell's selection state
            if let cell = collectionView.cellForItem(at: indexPath) as? FileThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: false)
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    /// Defines the size of each item in the collection view.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the width for four items across, with spacing between them
        let padding: CGFloat = 5
        let availableWidth = collectionView.frame.width - (padding * 3) // Space for 4 items and 3 paddings between them
        let widthPerItem = availableWidth / 4
        // Add extra height for the filename label (approximately 30 points for 2 lines of text)
        let heightWithLabel = widthPerItem + 30
        return CGSize(width: widthPerItem, height: heightWithLabel)
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
        
        let fileURL = files[indexPath.row]
        let fileName = fileURL.lastPathComponent
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.showDeleteConfirmation(for: fileURL, at: indexPath)
            }
            
            return UIMenu(title: fileName, children: [deleteAction])
        }
    }
    
    // MARK: - Delete Functionality
    
    /// Shows a confirmation alert before deleting a file
    private func showDeleteConfirmation(for fileURL: URL, at indexPath: IndexPath) {
        let fileName = fileURL.lastPathComponent
        let isDirectory = fileURL.hasDirectoryPath
        let itemType = isDirectory ? "folder" : "file"
        
        let alert = UIAlertController(
            title: "Delete \(itemType.capitalized)",
            message: "Are you sure you want to delete \"\(fileName)\"? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteFile(at: fileURL, indexPath: indexPath)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    /// Deletes the file at the specified URL and updates the collection view
    private func deleteFile(at fileURL: URL, indexPath: IndexPath) {
        let fileManager = FileManager.default
        
        do {
            // If it's a video file, also delete its thumbnail
            if fileURL.pathExtension.lowercased() == "webm" || fileURL.pathExtension.lowercased() == "mp4" {
                let thumbnailURL = getLocalThumbnailURL(for: fileURL)
                if fileManager.fileExists(atPath: thumbnailURL.path) {
                    try fileManager.removeItem(at: thumbnailURL)
                    print("DEBUG: FilesListVC - Deleted thumbnail for: \(fileURL.lastPathComponent)")
                }
            }
            
            // Delete the main file or directory
            try fileManager.removeItem(at: fileURL)
            
            // Update the data source
            files.remove(at: indexPath.row)
            
            // Update the collection view
            collectionView.deleteItems(at: [indexPath])
            
            print("DEBUG: FilesListVC - Successfully deleted: \(fileURL.lastPathComponent)")
            
        } catch {
            print("ERROR: FilesListVC - Failed to delete file: \(error.localizedDescription)")
            
            // Show error alert
            let errorAlert = UIAlertController(
                title: "Delete Failed",
                message: "Could not delete \"\(fileURL.lastPathComponent)\". \(error.localizedDescription)",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(errorAlert, animated: true, completion: nil)
        }
    }
}
