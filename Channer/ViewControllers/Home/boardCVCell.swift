import UIKit

class boardCVCell: UICollectionViewCell {

    let boardImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    let boardName: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12) // Slightly smaller font for narrow width
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 2 // Single line only
        label.lineBreakMode = .byTruncatingTail // Truncate with ellipsis if it exceeds the width
        return label
    }()

    let boardNameAbv: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 1
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(boardImage)
        boardImage.addSubview(boardName)
        boardImage.addSubview(boardNameAbv)
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }

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
