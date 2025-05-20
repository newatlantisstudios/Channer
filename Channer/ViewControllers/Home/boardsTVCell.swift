import UIKit

class boardsTVCell: UITableViewCell {
    
    // MARK: - UI Components
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
        backgroundColor = ThemeManager.shared.backgroundColor
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = ThemeManager.shared.cellBorderColor
            return view
        }()
        
        // Board name label
        boardNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        boardNameLabel.textColor = ThemeManager.shared.primaryTextColor
        boardNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(boardNameLabel)
        
        // Board abbreviation label
        boardAbvLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        boardAbvLabel.textColor = ThemeManager.shared.secondaryTextColor
        boardAbvLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(boardAbvLabel)
        
        // Add constraints
        NSLayoutConstraint.activate([
            // Board name label
            boardNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            boardNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            boardNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            // Board abbreviation label
            boardAbvLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            boardAbvLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            boardAbvLabel.topAnchor.constraint(equalTo: boardNameLabel.bottomAnchor, constant: 4),
            boardAbvLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }
    
    // MARK: - Theme Update
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors for theme changes (light/dark mode)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            backgroundColor = ThemeManager.shared.backgroundColor
            boardNameLabel.textColor = ThemeManager.shared.primaryTextColor
            boardAbvLabel.textColor = ThemeManager.shared.secondaryTextColor
            selectedBackgroundView?.backgroundColor = ThemeManager.shared.cellBorderColor
        }
    }
}