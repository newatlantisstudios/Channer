import UIKit

// MARK: - WebMThumbnailCell
/// A custom collection view cell that displays a thumbnail image.
class WebMThumbnailCell: UICollectionViewCell {
    
    // MARK: - Reuse Identifier
    /// The reuse identifier for this cell.
    static let reuseIdentifier = "WebMThumbnailCell"
    
    // MARK: - UI Components
    /// An image view to display the thumbnail image.
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill  // Scale the image to fill while maintaining aspect ratio.
        imageView.clipsToBounds = true            // Prevent image overflow.
        imageView.translatesAutoresizingMaskIntoConstraints = false  // Enable Auto Layout.
        return imageView
    }()
    
    // MARK: - Initializers
    /// Initializes the cell with a frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(thumbnailImageView)
        
        // Set up constraints to make the image view fill the cell.
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    /// Required initializer for decoding the cell from a storyboard or nib.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    /// Configures the cell with an image.
    /// - Parameter image: The image to display in the thumbnail image view.
    func configure(with image: UIImage?) {
        thumbnailImageView.image = image
    }
}
