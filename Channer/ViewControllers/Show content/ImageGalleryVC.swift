import UIKit
import Kingfisher

class ImageGalleryVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var images: [URL] = []
    let collectionView: UICollectionView
    var selectedImageURL: URL? // Optional to store the initially selected image

    // Initializer for images array
    init(images: [URL]) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    
    // Collection view data source and delegate methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath)
        
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView(frame: cell.contentView.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        let imageURL = images[indexPath.row]
        imageView.kf.setImage(with: imageURL)
        
        cell.contentView.addSubview(imageView)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var selectedURL = images[indexPath.row]
        print("ImageGalleryVC - selectedURL - " + selectedURL.absoluteString)
        
        // Check if the URL contains "s.jpg" and replace it with "webm" if so
        if selectedURL.absoluteString.contains("s.jpg") {
            let modifiedURLString = selectedURL.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
            if let modifiedURL = URL(string: modifiedURLString) {
                selectedURL = modifiedURL
            }
        }

        // Open urlWeb and pass the entire images/videos list and the current index
        let urlWebVC = urlWeb()
        urlWebVC.images = images // Pass the entire list of images/videos
        urlWebVC.currentIndex = indexPath.row // Set the current index to the selected item
        urlWebVC.enableSwipes = true // Enable swipes to allow navigation between multiple items
        navigationController?.pushViewController(urlWebVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 10
        let availableWidth = collectionView.frame.width - padding * 3
        let widthPerItem = availableWidth / 2
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
}
