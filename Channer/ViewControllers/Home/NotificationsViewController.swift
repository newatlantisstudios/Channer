import UIKit
import SwiftyJSON

class NotificationsViewController: UITableViewController {

    // Section order for display
    private let sectionOrder: [NotificationType] = [.myPostReply, .threadUpdate, .watchedPostReply]
    private var groupedNotifications: [NotificationType: [ReplyNotification]] = [:]
    private var activeSections: [NotificationType] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Notifications"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor

        // Configure table view
        tableView.register(NotificationCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100

        // Add navigation bar buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(close)
        )

        // Add actions button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Actions",
            style: .plain,
            target: self,
            action: #selector(showActions)
        )

        // Listen for notification updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDataChanged),
            name: .notificationAdded,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDataChanged),
            name: .notificationRead,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDataChanged),
            name: .notificationRemoved,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDataChanged),
            name: .notificationDataChanged,
            object: nil
        )

        // Load notifications
        loadNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func showActions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Mark all as read
        let markAllReadAction = UIAlertAction(title: "Mark All as Read", style: .default) { _ in
            NotificationManager.shared.markAllAsRead()
        }

        // Clear all notifications
        let clearAllAction = UIAlertAction(title: "Clear All", style: .destructive) { _ in
            NotificationManager.shared.clearAllNotifications()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(markAllReadAction)
        alert.addAction(clearAllAction)
        alert.addAction(cancelAction)

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    @objc private func notificationDataChanged() {
        loadNotifications()
    }

    private func loadNotifications() {
        groupedNotifications = NotificationManager.shared.getNotificationsGroupedByType()

        // Build active sections in the correct order
        activeSections = sectionOrder.filter { groupedNotifications[$0] != nil }

        tableView.reloadData()

        // Show/hide empty state
        let totalNotifications = groupedNotifications.values.flatMap { $0 }.count
        if totalNotifications == 0 {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }

    // MARK: - Section Configuration

    private func sectionTitle(for type: NotificationType) -> String {
        switch type {
        case .myPostReply:
            return "Replies to Your Posts"
        case .threadUpdate:
            return "Thread Updates"
        case .watchedPostReply:
            return "Watched Post Replies"
        }
    }

    private func sectionIcon(for type: NotificationType) -> UIImage? {
        switch type {
        case .myPostReply:
            return UIImage(systemName: "person.fill")
        case .threadUpdate:
            return UIImage(systemName: "arrow.triangle.2.circlepath")
        case .watchedPostReply:
            return UIImage(systemName: "eye.fill")
        }
    }

    private func sectionColor(for type: NotificationType) -> UIColor {
        switch type {
        case .myPostReply:
            return .systemOrange
        case .threadUpdate:
            return .systemGreen
        case .watchedPostReply:
            return .systemBlue
        }
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return activeSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < activeSections.count else { return 0 }
        let type = activeSections[section]
        return groupedNotifications[type]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < activeSections.count else { return nil }
        let type = activeSections[section]

        let headerView = UIView()
        headerView.backgroundColor = ThemeManager.shared.backgroundColor

        let iconImageView = UIImageView(image: sectionIcon(for: type))
        iconImageView.tintColor = sectionColor(for: type)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = sectionTitle(for: type)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = sectionColor(for: type)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Unread count badge
        let unreadCount = groupedNotifications[type]?.filter { !$0.isRead }.count ?? 0
        let countLabel = UILabel()
        if unreadCount > 0 {
            countLabel.text = "\(unreadCount)"
            countLabel.font = .systemFont(ofSize: 12, weight: .medium)
            countLabel.textColor = .white
            countLabel.backgroundColor = sectionColor(for: type)
            countLabel.textAlignment = .center
            countLabel.layer.cornerRadius = 10
            countLabel.clipsToBounds = true
        }
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            countLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationCell

        guard indexPath.section < activeSections.count else { return cell }
        let type = activeSections[indexPath.section]
        guard let notifications = groupedNotifications[type], indexPath.row < notifications.count else { return cell }

        let notification = notifications[indexPath.row]
        cell.configure(with: notification, color: sectionColor(for: type))

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section < activeSections.count else { return }
        let type = activeSections[indexPath.section]
        guard let notifications = groupedNotifications[type], indexPath.row < notifications.count else { return }

        let notification = notifications[indexPath.row]

        // Mark as read
        NotificationManager.shared.markAsRead(notification.id)

        // Navigate to the thread
        let threadVC = threadRepliesTV()
        threadVC.boardAbv = notification.boardAbv
        threadVC.threadNumber = notification.threadNo
        threadVC.title = "/\(notification.boardAbv)/ - Thread \(notification.threadNo)"

        // Dismiss and navigate
        dismiss(animated: true) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navController = window.rootViewController as? UINavigationController {
                navController.pushViewController(threadVC, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard indexPath.section < activeSections.count else { return }
            let type = activeSections[indexPath.section]
            guard let notifications = groupedNotifications[type], indexPath.row < notifications.count else { return }

            let notification = notifications[indexPath.row]
            NotificationManager.shared.removeNotification(notification.id)
        }
    }

    // MARK: - Helper Methods

    private func showEmptyState() {
        let emptyLabel = UILabel()
        emptyLabel.text = "No notifications"
        emptyLabel.textColor = .systemGray
        emptyLabel.font = .systemFont(ofSize: 17)
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel
    }

    private func hideEmptyState() {
        tableView.backgroundView = nil
    }
}

// MARK: - NotificationCell

class NotificationCell: UITableViewCell {

    private let unreadIndicator = UIView()
    private let iconImageView = UIImageView()
    private let headerLabel = UILabel()
    private let replyInfoLabel = UILabel()
    private let textPreviewLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = ThemeManager.shared.backgroundColor
        contentView.backgroundColor = ThemeManager.shared.backgroundColor

        // Unread indicator
        unreadIndicator.layer.cornerRadius = 4
        unreadIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(unreadIndicator)

        // Icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        // Header label
        headerLabel.font = .systemFont(ofSize: 14, weight: .medium)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        // Reply info label
        replyInfoLabel.font = .systemFont(ofSize: 13)
        replyInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(replyInfoLabel)

        // Text preview label
        textPreviewLabel.font = .systemFont(ofSize: 15)
        textPreviewLabel.numberOfLines = 2
        textPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textPreviewLabel)

        // Time label
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .systemGray
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            unreadIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            unreadIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadIndicator.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicator.heightAnchor.constraint(equalToConstant: 8),

            iconImageView.leadingAnchor.constraint(equalTo: unreadIndicator.trailingAnchor, constant: 8),
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            headerLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),

            replyInfoLabel.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            replyInfoLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            replyInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            textPreviewLabel.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            textPreviewLabel.topAnchor.constraint(equalTo: replyInfoLabel.bottomAnchor, constant: 4),
            textPreviewLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textPreviewLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with notification: ReplyNotification, color: UIColor) {
        // Unread indicator
        unreadIndicator.backgroundColor = notification.isRead ? .clear : color
        unreadIndicator.isHidden = notification.isRead

        // Icon based on notification type
        iconImageView.tintColor = notification.isRead ? .systemGray : color
        switch notification.notificationType {
        case .myPostReply:
            iconImageView.image = UIImage(systemName: "person.fill")
        case .threadUpdate:
            iconImageView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        case .watchedPostReply:
            iconImageView.image = UIImage(systemName: "eye.fill")
        }

        // Header - thread title with board info, or just board/thread info as fallback
        let boardThreadInfo = "/\(notification.boardAbv)/ - No. \(notification.threadNo)"
        if let threadTitle = notification.threadTitle, !threadTitle.isEmpty {
            // Show title with board info prefix for context
            headerLabel.text = "\(boardThreadInfo): \(threadTitle)"
        } else {
            headerLabel.text = boardThreadInfo
        }
        headerLabel.textColor = notification.isRead ? .systemGray : ThemeManager.shared.primaryTextColor

        // Reply info
        switch notification.notificationType {
        case .threadUpdate:
            if let count = notification.newReplyCount {
                replyInfoLabel.text = "\(count) new \(count == 1 ? "reply" : "replies")"
            } else {
                replyInfoLabel.text = "New replies"
            }
            replyInfoLabel.textColor = notification.isRead ? .systemGray : color
        case .myPostReply, .watchedPostReply:
            replyInfoLabel.text = "Reply to >>\(notification.replyToNo)"
            replyInfoLabel.textColor = notification.isRead ? .systemGray : .systemBlue
        }

        // Text preview
        textPreviewLabel.text = notification.replyText
        textPreviewLabel.textColor = notification.isRead ? .systemGray2 : ThemeManager.shared.primaryTextColor

        // Timestamp
        timeLabel.text = formatTimestamp(notification.timestamp)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        unreadIndicator.isHidden = true
        iconImageView.image = nil
        headerLabel.text = nil
        replyInfoLabel.text = nil
        textPreviewLabel.text = nil
        timeLabel.text = nil
    }
}
