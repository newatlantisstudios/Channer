import UIKit
import AVFoundation

class ThumbnailGridVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIContextMenuInteractionDelegate {
    
    var files: [URL] = []
    var collectionView: UICollectionView!
    let fileTypes: [String]
    let directory: URL
    
    /// Tracks whether we're in selection mode
    var isSelectionMode: Bool = false
    
    /// Set of selected index paths
    var selectedIndexPaths: Set<IndexPath> = []
    
    /// Navigation bar buttons
    var selectButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    var deleteButton: UIBarButtonItem!

    // MARK: - Initialization
    // Handles the initialization of the view controller with a directory and supported file types.
    
    init(directory: URL, fileTypes: [String]) {
        self.directory = directory
        self.fileTypes = fileTypes
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle Methods
    // Manages the view controller's lifecycle events.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        self.navigationItem.title = directory.lastPathComponent
        
        setupNavigationBar()
        setupCollectionView()
        loadFiles()
    }
    
    // MARK: - Setup Methods
    // Configures UI components and layouts.
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(WebMThumbnailCell.self, forCellWithReuseIdentifier: WebMThumbnailCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true // Enable vertical bounce
        
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
                
                // Delete the main file
                try fileManager.removeItem(at: fileURL)
                
                // Remove from data source (removing from end to maintain indices)
                files.remove(at: indexPath.row)
                indexPathsToDelete.append(indexPath)
                
                print("DEBUG: ThumbnailGridVC - Successfully deleted: \(fileURL.lastPathComponent)")
                
            } catch {
                print("ERROR: ThumbnailGridVC - Failed to delete file: \(error.localizedDescription)")
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
    // Loads files from the specified directory.
    
    func loadFiles() {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            // Filter out hidden files (those starting with ".") AND filter by file type
            files = fileURLs.filter { 
                !$0.lastPathComponent.hasPrefix(".") && fileTypes.contains($0.pathExtension.lowercased()) 
            }
            print("DEBUG: ThumbnailGridVC - Loaded \(files.count) non-hidden files from \(directory.path)")
            collectionView.reloadData()
        } catch {
            print("Error loading files from directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UICollectionViewDataSource
    // Provides data for the collection view.
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return files.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WebMThumbnailCell.reuseIdentifier, for: indexPath) as! WebMThumbnailCell
        let fileURL = files[indexPath.row]
        
        // First try to load a saved thumbnail
        if let savedThumbnail = loadSavedThumbnail(for: fileURL) {
            print("DEBUG: ThumbnailGridVC - Using saved thumbnail for: \(fileURL.lastPathComponent)")
            cell.configure(with: savedThumbnail)
        } else if fileURL.pathExtension.lowercased() == "webm" {
            generateThumbnail(for: fileURL) { image in
                DispatchQueue.main.async {
                    cell.configure(with: image)
                }
            }
        } else if ["jpg", "jpeg", "png"].contains(fileURL.pathExtension.lowercased()) {
            let image = UIImage(contentsOfFile: fileURL.path)
            cell.configure(with: image)
        }
        
        // Configure selection mode UI
        let isSelected = selectedIndexPaths.contains(indexPath)
        cell.setSelectionMode(isSelectionMode, isSelected: isSelected)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    // Handles user interactions with the collection view.
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.insert(indexPath)
            updateDeleteButtonState()
            
            // Update cell's selection state
            if let cell = collectionView.cellForItem(at: indexPath) as? WebMThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: true)
            }
            return
        }
        
        let selectedURL = files[indexPath.row]
        var vc: UIViewController

        if selectedURL.pathExtension.lowercased() == "webm" {
            print("DEBUG: ThumbnailGridVC - WebM file selected: \(selectedURL.absoluteString)")
            
            // Simple header-based VP9 detection
            do {
                let data = try Data(contentsOf: selectedURL, options: [.dataReadingMapped])
                let headerData = data.prefix(4096)
                let headerString = String(data: headerData, encoding: .ascii) ?? ""
                let isVP9 = headerString.range(of: "VP90", options: .caseInsensitive) != nil ||
                           headerString.range(of: "vp09", options: .caseInsensitive) != nil
                
                print("DEBUG: ThumbnailGridVC - Header VP9 detection: \(isVP9)")
                
                if isVP9 {
                    print("DEBUG: ThumbnailGridVC - VP9 detected - may fail with VLCKit")
                    print("DEBUG: ThumbnailGridVC - Consider implementing fallback to WKWebView for VP9 files")
                } else {
                    print("DEBUG: ThumbnailGridVC - VP8 or other codec detected - should work with VLCKit")
                }
            } catch {
                print("DEBUG: ThumbnailGridVC - Could not read file header: \(error)")
            }
            
            // Play .webm video using WebMViewController
            let webMViewController = WebMViewController()
            webMViewController.videoURL = selectedURL.absoluteString
            webMViewController.hideDownloadButton = true
            vc = webMViewController
        } else if ["jpg", "jpeg", "png"].contains(selectedURL.pathExtension.lowercased()) {
            // Show image in full view using ImageViewController
            vc = ImageViewController(imageURL: selectedURL)
        } else {
            print("Selected file is not a supported format.")
            return
        }

        // Push to the navigation stack
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            selectedIndexPaths.remove(indexPath)
            updateDeleteButtonState()
            
            // Update cell's selection state
            if let cell = collectionView.cellForItem(at: indexPath) as? WebMThumbnailCell {
                cell.setSelectionMode(isSelectionMode, isSelected: false)
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    // Defines the layout of the collection view cells.
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the width for four items across, with 5 points of spacing between them
        let padding: CGFloat = 5
        let availableWidth = collectionView.frame.width - (padding * 3) // Space for 4 items and 3 paddings between them
        let widthPerItem = availableWidth / 4
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    // MARK: - Helper Methods
    // Provides utility functions for the view controller.
    
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        // Since we can't use FFmpeg directly in iOS anymore, we'll use a different approach
        // to generate a thumbnail from the video
        
        DispatchQueue.global(qos: .background).async {
            // Use AVFoundation to generate a thumbnail from the first frame
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Get a frame at 1 second
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnailImage = UIImage(cgImage: cgImage)
                
                // Scale the image to 150x150
                let size = CGSize(width: 150, height: 150)
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                thumbnailImage.draw(in: CGRect(origin: .zero, size: size))
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                DispatchQueue.main.async {
                    completion(scaledImage)
                }
            } catch {
                print("Error generating thumbnail: \(error.localizedDescription)")
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
            print("DEBUG: ThumbnailGridVC - Failed to load thumbnail: \(error)")
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
        
        let alert = UIAlertController(
            title: "Delete File",
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
                    print("DEBUG: ThumbnailGridVC - Deleted thumbnail for: \(fileURL.lastPathComponent)")
                }
            }
            
            // Delete the main file
            try fileManager.removeItem(at: fileURL)
            
            // Update the data source
            files.remove(at: indexPath.row)
            
            // Update the collection view
            collectionView.deleteItems(at: [indexPath])
            
            print("DEBUG: ThumbnailGridVC - Successfully deleted: \(fileURL.lastPathComponent)")
            
        } catch {
            print("ERROR: ThumbnailGridVC - Failed to delete file: \(error.localizedDescription)")
            
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
