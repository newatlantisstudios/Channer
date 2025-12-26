//
//  DownloadItemCell.swift
//  Channer
//
//  Table view cell for displaying a single download item
//

import UIKit

protocol DownloadItemCellDelegate: AnyObject {
    func downloadCellDidTapAction(_ cell: DownloadItemCell, item: DownloadItem)
}

/// Table view cell for displaying a single download item with progress
class DownloadItemCell: UITableViewCell {

    static let reuseIdentifier = "DownloadItemCell"

    // MARK: - UI Components
    private let containerView = UIView()
    private let thumbnailImageView = UIImageView()
    private let filenameLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let actionButton = UIButton(type: .system)
    private let sizeLabel = UILabel()

    // MARK: - Properties
    weak var delegate: DownloadItemCellDelegate?
    private var currentItem: DownloadItem?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Container
        containerView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Thumbnail
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = ThemeManager.shared.backgroundColor
        thumbnailImageView.tintColor = ThemeManager.shared.secondaryTextColor
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(thumbnailImageView)

        // Filename
        filenameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        filenameLabel.textColor = ThemeManager.shared.primaryTextColor
        filenameLabel.numberOfLines = 1
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(filenameLabel)

        // Status
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = ThemeManager.shared.secondaryTextColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)

        // Progress
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = ThemeManager.shared.backgroundColor
        progressView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(progressView)

        // Size label
        sizeLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = ThemeManager.shared.secondaryTextColor
        sizeLabel.textAlignment = .right
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sizeLabel)

        // Action button
        actionButton.tintColor = .systemBlue
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(actionButton)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            thumbnailImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 44),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 44),

            actionButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            actionButton.widthAnchor.constraint(equalToConstant: 44),
            actionButton.heightAnchor.constraint(equalToConstant: 44),

            filenameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            filenameLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            filenameLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),

            statusLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: filenameLabel.leadingAnchor),

            sizeLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 4),
            sizeLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8),

            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: filenameLabel.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            progressView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
    }

    // MARK: - Configuration

    func configure(with item: DownloadItem) {
        currentItem = item
        filenameLabel.text = item.filename
        progressView.progress = Float(item.progress)

        // Set thumbnail icon based on media type
        thumbnailImageView.image = UIImage(systemName: item.mediaType.iconName)

        // Update colors based on current theme
        containerView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        containerView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        thumbnailImageView.backgroundColor = ThemeManager.shared.backgroundColor
        thumbnailImageView.tintColor = ThemeManager.shared.secondaryTextColor
        filenameLabel.textColor = ThemeManager.shared.primaryTextColor
        progressView.trackTintColor = ThemeManager.shared.backgroundColor

        // Update based on status
        switch item.status {
        case .pending:
            statusLabel.text = "Waiting..."
            statusLabel.textColor = ThemeManager.shared.secondaryTextColor
            progressView.isHidden = true
            actionButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            actionButton.tintColor = .systemGray
            sizeLabel.isHidden = true

        case .downloading:
            let progressPercent = Int(item.progress * 100)
            statusLabel.text = "Downloading... \(progressPercent)%"
            statusLabel.textColor = .systemBlue
            progressView.isHidden = false
            actionButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            actionButton.tintColor = .systemOrange
            sizeLabel.text = formatBytes(item.bytesDownloaded) + " / " + formatBytes(item.totalBytes)
            sizeLabel.isHidden = false

        case .paused:
            statusLabel.text = "Paused"
            statusLabel.textColor = .systemOrange
            progressView.isHidden = false
            actionButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            actionButton.tintColor = .systemBlue
            sizeLabel.text = formatBytes(item.bytesDownloaded) + " / " + formatBytes(item.totalBytes)
            sizeLabel.isHidden = false

        case .completed:
            statusLabel.text = "Completed"
            statusLabel.textColor = .systemGreen
            progressView.isHidden = true
            actionButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            actionButton.tintColor = .systemGreen
            sizeLabel.text = formatBytes(item.totalBytes)
            sizeLabel.isHidden = item.totalBytes <= 0

        case .failed:
            let errorText = item.errorMessage ?? "Failed"
            statusLabel.text = errorText.count > 30 ? String(errorText.prefix(30)) + "..." : errorText
            statusLabel.textColor = .systemRed
            progressView.isHidden = true
            actionButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
            actionButton.tintColor = .systemBlue
            sizeLabel.isHidden = true

        case .cancelled:
            statusLabel.text = "Cancelled"
            statusLabel.textColor = ThemeManager.shared.secondaryTextColor
            progressView.isHidden = true
            actionButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
            actionButton.tintColor = .systemBlue
            sizeLabel.isHidden = true
        }
    }

    func updateProgress(_ progress: Double, bytesDownloaded: Int64, totalBytes: Int64) {
        progressView.progress = Float(progress)
        let progressPercent = Int(progress * 100)
        statusLabel.text = "Downloading... \(progressPercent)%"
        sizeLabel.text = formatBytes(bytesDownloaded) + " / " + formatBytes(totalBytes)
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        guard let item = currentItem else { return }
        delegate?.downloadCellDidTapAction(self, item: item)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentItem = nil
        thumbnailImageView.image = nil
        progressView.progress = 0
        sizeLabel.text = nil
        statusLabel.text = nil
    }
}
