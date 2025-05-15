import UIKit
import AVFoundation

class ThumbnailGridVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var files: [URL] = []
    var collectionView: UICollectionView!
    let fileTypes: [String]
    let directory: URL

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
        
        setupCollectionView()
        loadFiles()
    }
    
    // MARK: - Setup Methods
    // Configures UI components and layouts.
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(WebMThumbnailCell.self, forCellWithReuseIdentifier: WebMThumbnailCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true // Enable vertical bounce
        view.addSubview(collectionView)
        
        // Set up constraints for full screen
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    // Loads files from the specified directory.
    
    func loadFiles() {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            files = fileURLs.filter { fileTypes.contains($0.pathExtension.lowercased()) }
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
        
        if fileURL.pathExtension.lowercased() == "webm" {
            generateThumbnail(for: fileURL) { image in
                DispatchQueue.main.async {
                    cell.configure(with: image)
                }
            }
        } else if ["jpg", "jpeg", "png"].contains(fileURL.pathExtension.lowercased()) {
            let image = UIImage(contentsOfFile: fileURL.path)
            cell.configure(with: image)
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    // Handles user interactions with the collection view.
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedURL = files[indexPath.row]
        var vc: UIViewController

        if selectedURL.pathExtension.lowercased() == "webm" {
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

        // Adapt behavior based on device type
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Push the view controller directly onto the existing navigation stack
            if let detailNavController = self.splitViewController?.viewController(for: .secondary) as? UINavigationController {
                detailNavController.pushViewController(vc, animated: true)
            } else {
                print("Detail view controller is not a UINavigationController.")
            }
        } else {
            // iPhone behavior: push to the navigation stack
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    // Defines the layout of the collection view cells.
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the width for three items across, with 10 points of spacing between them
        let padding: CGFloat = 10
        let availableWidth = collectionView.frame.width - (padding * 2) // Space for 3 items and 2 paddings between them
        let widthPerItem = availableWidth / 3
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
}
