import UIKit

/// A custom `UICollectionViewCell` subclass representing a board cell with labels.
class boardCVCell: UICollectionViewCell {

    // MARK: - UI Components
    // Background container for content
    private let containerView = UIView()

    /// Label displaying the board's name.
    let boardName: UILabel = {
        let label = UILabel()
        
        // Get device type to set appropriate font size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Adjusted font sizes
        label.font = UIFont.systemFont(ofSize: isPad ? 13 : 15, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label // Use system label color for automatic light/dark support
        label.numberOfLines = 2 // Allow up to 2 lines
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }()

    /// Label displaying the board's abbreviation.
    let boardNameAbv: UILabel = {
        let label = UILabel()
        
        // Get device type to set appropriate font size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Adjusted font sizes
        label.font = UIFont.systemFont(ofSize: isPad ? 11 : 13)
        label.textAlignment = .center
        label.textColor = .secondaryLabel // Use system secondary label color for automatic light/dark support
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let pinImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "pin.fill"))
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods
    /// Sets up the views by adding subviews and configuring their properties.
    private func setupViews() {
        // Configure container view
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        
        // Add shadow to the cell
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.masksToBounds = false
        
        // Add subviews
        contentView.addSubview(containerView)
        containerView.addSubview(pinImageView)
        containerView.addSubview(boardName)
        containerView.addSubview(boardNameAbv)
    }

    /// Sets up the Auto Layout constraints for the subviews.
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        boardName.translatesAutoresizingMaskIntoConstraints = false
        boardNameAbv.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container view constraints - smaller than contentView to allow for shadow
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            pinImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            pinImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            pinImageView.widthAnchor.constraint(equalToConstant: 14),
            pinImageView.heightAnchor.constraint(equalToConstant: 14),

            // Board name constraints - top portion of cell
            boardName.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            boardName.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            boardName.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            
            // Board abbreviation constraints - bottom portion of cell
            boardNameAbv.topAnchor.constraint(equalTo: boardName.bottomAnchor, constant: 4),
            boardNameAbv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            boardNameAbv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            boardNameAbv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }

    func configure(name: String, abbreviation: String, isPinned: Bool) {
        boardName.text = name
        boardNameAbv.text = "/\(abbreviation)/"
        pinImageView.isHidden = !isPinned
        accessibilityLabel = isPinned ? "\(name), /\(abbreviation)/, pinned" : "\(name), /\(abbreviation)/"
    }
    
    // MARK: - Theme Updates
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors for theme changes (light/dark mode)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.backgroundColor = .secondarySystemBackground
            boardName.textColor = .label
            boardNameAbv.textColor = .secondaryLabel
            pinImageView.tintColor = .systemYellow
        }
    }
    
    // MARK: - Cell Selection
    override var isSelected: Bool {
        didSet {
            // Add visual feedback when cell is selected
            UIView.animate(withDuration: 0.2) {
                self.containerView.backgroundColor = self.isSelected ? 
                    .systemGray4 : 
                    .secondarySystemBackground
                
                // Scale the cell slightly when selected
                self.transform = self.isSelected ? 
                    CGAffineTransform(scaleX: 0.95, y: 0.95) : 
                    CGAffineTransform.identity
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset any properties that might have been changed
        transform = CGAffineTransform.identity
        containerView.backgroundColor = .secondarySystemBackground
        boardName.text = nil
        boardNameAbv.text = nil
        pinImageView.isHidden = true
        accessibilityLabel = nil
    }
}
