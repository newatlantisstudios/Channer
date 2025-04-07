import UIKit

/// A custom `UICollectionViewCell` subclass representing a board cell with an image and labels.
class boardCVCell: UICollectionViewCell {

    // MARK: - UI Components
    // Define UI elements for the cell's content.

    /// Image view displaying the board's image.
    let boardImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill // Set the image to scale aspect fill.
        imageView.clipsToBounds = true // Ensure the image doesn't overflow its bounds.
        return imageView
    }()

    /// Label displaying the board's name.
    let boardName: UILabel = {
        let label = UILabel()
        
        // Get device type to set appropriate font size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Smaller font size for iPad to match smaller cells
        label.font = UIFont.boldSystemFont(ofSize: isPad ? 12 : 14)
        label.textAlignment = .center // Center the text.
        label.textColor = UIColor.black
        label.numberOfLines = 2 // Allow up to 2 lines.
        label.lineBreakMode = .byTruncatingTail // Truncate with ellipsis if it exceeds the width.
        label.adjustsFontSizeToFitWidth = true // Adjust font size if needed
        label.minimumScaleFactor = 0.7 // Allow scaling down more for smaller cells
        return label
    }()

    /// Label displaying the board's abbreviation.
    let boardNameAbv: UILabel = {
        let label = UILabel()
        
        // Get device type to set appropriate font size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Smaller font size for iPad to match smaller cells
        label.font = UIFont.systemFont(ofSize: isPad ? 10 : 12)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7 // Allow scaling down more for smaller cells
        return label
    }()

    // MARK: - Initializers
    // Initialize the cell and set up its views and constraints.

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods
    // Private methods to set up views and constraints.

    /// Sets up the views by adding subviews and configuring their properties.
    private func setupViews() {
        contentView.addSubview(boardImage)
        boardImage.addSubview(boardName)
        boardImage.addSubview(boardNameAbv)
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

    /// Sets up the Auto Layout constraints for the subviews.
    private func setupConstraints() {
        boardImage.translatesAutoresizingMaskIntoConstraints = false
        boardName.translatesAutoresizingMaskIntoConstraints = false
        boardNameAbv.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // boardImage constraints: fill the entire contentView
            boardImage.topAnchor.constraint(equalTo: contentView.topAnchor),
            boardImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            boardImage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            boardImage.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // boardName constraints
            boardName.centerXAnchor.constraint(equalTo: boardImage.centerXAnchor),
            boardName.centerYAnchor.constraint(equalTo: boardImage.centerYAnchor, constant: -8),
            boardName.leadingAnchor.constraint(greaterThanOrEqualTo: boardImage.leadingAnchor, constant: 4),
            boardName.trailingAnchor.constraint(lessThanOrEqualTo: boardImage.trailingAnchor, constant: -4),

            // boardNameAbv constraints
            boardNameAbv.centerXAnchor.constraint(equalTo: boardImage.centerXAnchor),
            boardNameAbv.topAnchor.constraint(equalTo: boardName.bottomAnchor, constant: 4)
        ])
    }
}
