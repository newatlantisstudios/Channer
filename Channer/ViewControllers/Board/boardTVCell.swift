import UIKit

class boardTVCell: UITableViewCell {
    
    // Existing IBOutlets
    @IBOutlet weak var topicTextTitle: UILabel! {
        didSet {
            topicTextTitle.numberOfLines = 0
            topicTextTitle.font = UIFont.boldSystemFont(ofSize: 14) // Set bold font with size 14
        }
    }
    @IBOutlet weak var topicTextNoTitle: UILabel! {
        didSet {
            topicTextNoTitle.numberOfLines = 0
        }
    }
    @IBOutlet weak var topicStats: UILabel!
    @IBOutlet weak var topicTitle: UILabel! {
        didSet {
            topicTitle.numberOfLines = 0
        }
    }

    // Custom Background View
    let customBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 6.0
        view.layer.borderColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 3
        return view
    }()
    
    // Topic Image
    @IBOutlet weak var topicImage: UIImageView! {
        didSet {
            topicImage.layer.cornerRadius = 8
            topicImage.layer.masksToBounds = true
            topicImage.clipsToBounds = true
            topicImage.contentMode = .scaleAspectFill
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
        setupConstraints()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        topicImage.image = UIImage(named: "loadingBoardImage")
        topicStats.text = nil
        topicTextTitle.text = nil
        topicTextNoTitle.text = nil
        topicTitle.text = nil
    }

    private func setupCell() {
        // Add customBackgroundView to the cell first, so it sits at the back
        contentView.addSubview(customBackgroundView)
        
        // Add other subviews after customBackgroundView
        contentView.addSubview(topicImage)
        contentView.addSubview(topicStats)
        contentView.addSubview(topicTextTitle)
        contentView.addSubview(topicTextNoTitle)
        contentView.addSubview(topicTitle)
        
        // Configure labels
        [topicTextTitle, topicTextNoTitle, topicTitle].forEach { label in
            label?.numberOfLines = 0
            label?.lineBreakMode = .byWordWrapping
        }
        
        // Set background colors
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    private func setupConstraints() {
        // Enable auto layout for all views
        [customBackgroundView, topicImage, topicStats, topicTitle, topicTextTitle, topicTextNoTitle].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Custom Background View
            customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 7),
            customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
            customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6), // Adjusted for 5px padding
            customBackgroundView.heightAnchor.constraint(equalToConstant: 166), // Fixed height

            // Topic Image
            topicImage.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 7),
            topicImage.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            topicImage.widthAnchor.constraint(equalToConstant: 120),
            topicImage.heightAnchor.constraint(equalToConstant: 120),

            // Topic Stats
            topicStats.centerXAnchor.constraint(equalTo: topicImage.centerXAnchor, constant: 1),
            topicStats.topAnchor.constraint(equalTo: topicImage.bottomAnchor),
            topicStats.widthAnchor.constraint(equalToConstant: 120),
            topicStats.heightAnchor.constraint(equalToConstant: 21),

            // Topic Title (when visible)
            topicTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
            topicTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            topicTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            topicTitle.heightAnchor.constraint(greaterThanOrEqualToConstant: 17),

            // Topic Text Title (when title is present)
            topicTextTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
            topicTextTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            topicTextTitle.topAnchor.constraint(equalTo: topicTitle.bottomAnchor, constant: 8),
            topicTextTitle.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -9),

            // Topic Text No Title (when no title)
            topicTextNoTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
            topicTextNoTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            topicTextNoTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            topicTextNoTitle.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -9)
        ])
    }
    
}
