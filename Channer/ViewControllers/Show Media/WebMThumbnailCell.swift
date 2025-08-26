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
    
    /// Selection indicator for multi-selection mode
    let selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Checkmark image view for selection indicator
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initializers
    /// Initializes the cell with a frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)
        
        // Set up constraints to make the image view fill the cell.
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Selection indicator (top-right corner)
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            selectionIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Checkmark inside selection indicator
            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 12)
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
    
    // MARK: - Selection Methods
    /// Shows or hides the selection indicator
    /// - Parameter isSelected: Whether the cell should show as selected
    func setSelected(_ isSelected: Bool) {
        selectionIndicator.isHidden = !isSelected
    }
    
    /// Shows or hides the selection mode UI elements
    /// - Parameters:
    ///   - isSelectionMode: Whether we're in selection mode
    ///   - isSelected: Whether this cell is currently selected
    func setSelectionMode(_ isSelectionMode: Bool, isSelected: Bool = false) {
        // In selection mode, we always show the selection indicator (selected or not)
        // When not selected, show an empty circle
        if isSelectionMode {
            selectionIndicator.isHidden = false
            if !isSelected {
                selectionIndicator.backgroundColor = UIColor.clear
                selectionIndicator.layer.borderWidth = 2
                selectionIndicator.layer.borderColor = UIColor.systemGray4.cgColor
                checkmarkImageView.isHidden = true
            } else {
                selectionIndicator.backgroundColor = UIColor.systemBlue
                selectionIndicator.layer.borderWidth = 0
                checkmarkImageView.isHidden = false
            }
        } else {
            selectionIndicator.isHidden = true
            selectionIndicator.layer.borderWidth = 0
        }
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        selectionIndicator.isHidden = true
        selectionIndicator.layer.borderWidth = 0
        checkmarkImageView.isHidden = false
    }
}

// MARK: - FileThumbnailCell
/// A custom collection view cell that displays a thumbnail image with filename for file browser.
class FileThumbnailCell: UICollectionViewCell {
    
    // MARK: - Reuse Identifier
    /// The reuse identifier for this cell.
    static let reuseIdentifier = "FileThumbnailCell"
    
    // MARK: - UI Components
    /// An image view to display the thumbnail image.
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 8
        return imageView
    }()
    
    /// A label to display the filename.
    let filenameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// A visual indicator for directories.
    let directoryIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Selection indicator for multi-selection mode
    let selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Checkmark image view for selection indicator
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initializers
    /// Initializes the cell with a frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(directoryIndicator)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(filenameLabel)
        contentView.addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Directory indicator (background)
            directoryIndicator.topAnchor.constraint(equalTo: contentView.topAnchor),
            directoryIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            directoryIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            directoryIndicator.heightAnchor.constraint(equalTo: contentView.widthAnchor),
            
            // Thumbnail image view
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            thumbnailImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, constant: -8),
            
            // Filename label
            filenameLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 2),
            filenameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            filenameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            filenameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -2),
            
            // Selection indicator (top-right corner)
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            selectionIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Checkmark inside selection indicator
            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    /// Required initializer for decoding the cell from a storyboard or nib.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    /// Configures the cell with an image, filename, and directory status.
    /// - Parameters:
    ///   - image: The image to display in the thumbnail image view.
    ///   - fileName: The name of the file to display.
    ///   - isDirectory: Whether this item represents a directory.
    func configure(with image: UIImage?, fileName: String, isDirectory: Bool) {
        thumbnailImageView.image = image
        filenameLabel.text = fileName
        directoryIndicator.isHidden = !isDirectory
        
        if isDirectory {
            filenameLabel.textColor = .systemBlue
            filenameLabel.font = UIFont.boldSystemFont(ofSize: 12)
        } else {
            filenameLabel.textColor = .label
            filenameLabel.font = UIFont.systemFont(ofSize: 12)
        }
    }
    
    // MARK: - Selection Methods
    /// Shows or hides the selection indicator
    /// - Parameter isSelected: Whether the cell should show as selected
    func setSelected(_ isSelected: Bool) {
        selectionIndicator.isHidden = !isSelected
    }
    
    /// Shows or hides the selection mode UI elements
    /// - Parameters:
    ///   - isSelectionMode: Whether we're in selection mode
    ///   - isSelected: Whether this cell is currently selected
    func setSelectionMode(_ isSelectionMode: Bool, isSelected: Bool = false) {
        // In selection mode, we always show the selection indicator (selected or not)
        // When not selected, show an empty circle
        if isSelectionMode {
            selectionIndicator.isHidden = false
            if !isSelected {
                selectionIndicator.backgroundColor = UIColor.clear
                selectionIndicator.layer.borderWidth = 2
                selectionIndicator.layer.borderColor = UIColor.systemGray4.cgColor
                checkmarkImageView.isHidden = true
            } else {
                selectionIndicator.backgroundColor = UIColor.systemBlue
                selectionIndicator.layer.borderWidth = 0
                checkmarkImageView.isHidden = false
            }
        } else {
            selectionIndicator.isHidden = true
            selectionIndicator.layer.borderWidth = 0
        }
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        filenameLabel.text = nil
        directoryIndicator.isHidden = true
        selectionIndicator.isHidden = true
        selectionIndicator.layer.borderWidth = 0
        checkmarkImageView.isHidden = false
    }
}
