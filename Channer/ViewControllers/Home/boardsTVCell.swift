import UIKit

class boardsTVCell: UITableViewCell {
    
    // MARK: - UI Components
    private let containerView = UIView()
    let boardNameLabel = UILabel()
    let boardAbvLabel = UILabel()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Setup
    private func setupViews() {
        // Cell appearance
        backgroundColor = .clear
        selectionStyle = .none

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        contentView.addSubview(containerView)
        
        // Board name label
        boardNameLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        boardNameLabel.textColor = .label
        boardNameLabel.numberOfLines = 1
        boardNameLabel.lineBreakMode = .byTruncatingTail
        boardNameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(boardNameLabel)
        
        // Board abbreviation label
        boardAbvLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        boardAbvLabel.textColor = .secondaryLabel
        boardAbvLabel.textAlignment = .center
        boardAbvLabel.numberOfLines = 1
        boardAbvLabel.translatesAutoresizingMaskIntoConstraints = false
        boardAbvLabel.backgroundColor = .tertiarySystemFill
        boardAbvLabel.layer.cornerRadius = 6
        boardAbvLabel.clipsToBounds = true
        containerView.addSubview(boardAbvLabel)
        
        // Add constraints
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            // Board name label
            boardNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            boardNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: boardAbvLabel.leadingAnchor, constant: -12),
            boardNameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Board abbreviation label
            boardAbvLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            boardAbvLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            boardAbvLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            boardAbvLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(name: String, abbreviation: String) {
        boardNameLabel.text = name
        boardAbvLabel.text = "/\(abbreviation)/"
    }
    
    // MARK: - Theme Update
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors for theme changes (light/dark mode)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            backgroundColor = .clear
            containerView.backgroundColor = .secondarySystemBackground
            containerView.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
            boardNameLabel.textColor = .label
            boardAbvLabel.textColor = .secondaryLabel
            boardAbvLabel.backgroundColor = .tertiarySystemFill
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        boardNameLabel.text = nil
        boardAbvLabel.text = nil
    }
}
