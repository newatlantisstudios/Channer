import UIKit

class boardTVCell: UITableViewCell {
    
    // Existing IBOutlets
    @IBOutlet weak var topicImage: UIImageView!
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
    @IBOutlet weak var topicCell: UIImageView?
    
    // New UIImageView for new thread data indicator
    private let newThreadDataImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "newthreadData"))
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true // Initially hidden
        return imageView
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
        setupConstraints()
        
        // Add the newThreadDataImageView to contentView
        contentView.addSubview(newThreadDataImageView)
        
        // Set up constraints for newThreadDataImageView
        setupNewThreadDataImageViewConstraints()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        topicImage.kf.cancelDownloadTask()
        topicImage.image = UIImage(named: "loadingBoardImage")
        topicStats.text = nil
        topicTextTitle.text = nil
        topicTextNoTitle.text = nil
        topicTitle.text = nil
        newThreadDataImageView.isHidden = true // Hide the indicator on reuse
    }
    
    // Function to toggle visibility of the new thread data indicator
    func showNewThreadDataIndicator(_ show: Bool) {
        newThreadDataImageView.isHidden = !show
    }
    
    private func setupCell() {
        // Configure image view
        topicImage.layer.cornerRadius = 8
        topicImage.layer.masksToBounds = true
        topicImage.clipsToBounds = true
        topicImage.contentMode = .scaleAspectFill
        
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
        // Enable auto layout
        [topicCell, topicImage, topicStats, topicTitle, topicTextTitle, topicTextNoTitle].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }
        
        guard let topicCell = topicCell else { return }
        
        NSLayoutConstraint.activate([
            // Topic Cell Background
            topicCell.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 7),
            topicCell.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            topicCell.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
            topicCell.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -1),
            topicCell.heightAnchor.constraint(equalToConstant: 170),
            
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
    
    private func setupNewThreadDataImageViewConstraints() {
        newThreadDataImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newThreadDataImageView.widthAnchor.constraint(equalToConstant: 24),
            newThreadDataImageView.heightAnchor.constraint(equalToConstant: 24),
            newThreadDataImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            newThreadDataImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
}
