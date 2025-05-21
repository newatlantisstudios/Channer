import UIKit
import Kingfisher

/// A view controller that displays a gallery of images using a collection view.
class ImageGalleryVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties
    /// Array of image URLs to display in the gallery.
    var images: [URL] = []
    /// The collection view that displays the images.
    let collectionView: UICollectionView
    /// Optional URL to store the initially selected image.
    var selectedImageURL: URL?

    // MARK: - Initializers
    /// Initializes the view controller with an array of image URLs.
    /// - Parameter images: The array of image URLs to display.
    init(images: [URL]) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "imageCell")
        collectionView.backgroundColor = .systemBackground
        collectionView.frame = view.bounds
        view.addSubview(collectionView)

        // Scroll to the initially selected image if set
        if let selectedURL = selectedImageURL, let index = images.firstIndex(of: selectedURL) {
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }

        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    /// Returns the number of items in the collection view section.
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    /// Configures and returns the cell for the given index path.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath)

        // Remove any existing subviews from the cell's content view
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let imageView = UIImageView(frame: cell.contentView.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let imageURL = images[indexPath.row]
        imageView.kf.setImage(with: imageURL)

        cell.contentView.addSubview(imageView)
        return cell
    }

    // MARK: - UICollectionViewDelegate
    /// Handles selection of a collection view item.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var selectedURL = images[indexPath.row]
        print("ImageGalleryVC - selectedURL - " + selectedURL.absoluteString)
        
        // Create a copy of the original images array
        var correctedURLs = images
        
        // Check if the URL contains "s.jpg" and replace it with ".webm" or ".mp4" as appropriate
        if selectedURL.absoluteString.contains("s.jpg") {
            // First try to convert to .webm
            let webmURLString = selectedURL.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
            
            // Also prepare a .mp4 URL as fallback
            let mp4URLString = selectedURL.absoluteString.replacingOccurrences(of: "s.jpg", with: ".mp4")
            
            if let webmURL = URL(string: webmURLString) {
                correctedURLs[indexPath.row] = webmURL
                selectedURL = webmURL
                print("Converting thumbnail to WebM: \(webmURL.absoluteString)")
            } else if let mp4URL = URL(string: mp4URLString) {
                correctedURLs[indexPath.row] = mp4URL
                selectedURL = mp4URL
                print("Converting thumbnail to MP4: \(mp4URL.absoluteString)")
            }
        }
        
        // Create the urlWeb view controller
        let urlWebVC = urlWeb()
        urlWebVC.images = correctedURLs // Pass the list of images/videos with corrected URL
        urlWebVC.currentIndex = indexPath.row // Set the current index to the selected item
        urlWebVC.enableSwipes = true // Enable swipes to allow navigation between multiple items
        
        // Navigate to the viewer
        if let navController = navigationController {
            print("Pushing urlWebVC onto navigation stack.")
            navController.pushViewController(urlWebVC, animated: true)
        } else {
            print("Navigation controller is nil. Attempting modal presentation.")
            let navController = UINavigationController(rootViewController: urlWebVC)
            present(navController, animated: true)
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    /// Returns the size for the item at the given index path.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 5
        let availableWidth = collectionView.frame.width - padding * 5 // Adjusted for 4 items with 5 paddings
        let widthPerItem = availableWidth / 4 // Changed from 2 to 4 columns
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
}
