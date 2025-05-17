import UIKit
import SwiftyJSON

class NotificationsViewController: UITableViewController {
    
    private var notifications: [ReplyNotification] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Notifications"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Configure table view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
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
        notifications = NotificationManager.shared.getNotifications()
        tableView.reloadData()
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if notifications.isEmpty {
            showEmptyState()
            return 0
        } else {
            hideEmptyState()
            return notifications.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath)
        
        let notification = notifications[indexPath.row]
        
        // Configure cell
        cell.backgroundColor = ThemeManager.shared.backgroundColor
        cell.contentView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Create custom content
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(containerView)
        
        // Board and thread info
        let headerLabel = UILabel()
        headerLabel.text = "/\(notification.boardAbv)/ - Thread \(notification.threadNo)"
        headerLabel.font = .systemFont(ofSize: 14, weight: .medium)
        headerLabel.textColor = notification.isRead ? .systemGray : ThemeManager.shared.primaryTextColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Reply text
        let textLabel = UILabel()
        textLabel.text = notification.replyText
        textLabel.font = .systemFont(ofSize: 15)
        textLabel.textColor = notification.isRead ? .systemGray2 : ThemeManager.shared.primaryTextColor
        textLabel.numberOfLines = 2
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Timestamp
        let timeLabel = UILabel()
        timeLabel.text = formatTimestamp(notification.timestamp)
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .systemGray
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Reply info
        let replyInfoLabel = UILabel()
        replyInfoLabel.text = "Reply to >>\(notification.replyToNo)"
        replyInfoLabel.font = .systemFont(ofSize: 13)
        replyInfoLabel.textColor = .systemBlue
        replyInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Unread indicator
        if !notification.isRead {
            let unreadIndicator = UIView()
            unreadIndicator.backgroundColor = .systemBlue
            unreadIndicator.layer.cornerRadius = 4
            unreadIndicator.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(unreadIndicator)
            
            NSLayoutConstraint.activate([
                unreadIndicator.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 8),
                unreadIndicator.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                unreadIndicator.widthAnchor.constraint(equalToConstant: 8),
                unreadIndicator.heightAnchor.constraint(equalToConstant: 8)
            ])
        }
        
        // Add subviews
        containerView.addSubview(headerLabel)
        containerView.addSubview(textLabel)
        containerView.addSubview(timeLabel)
        containerView.addSubview(replyInfoLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: notification.isRead ? 16 : 24),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            
            replyInfoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            replyInfoLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            
            textLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textLabel.topAnchor.constraint(equalTo: replyInfoLabel.bottomAnchor, constant: 4),
            textLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Remove accessory type for custom layout
        cell.accessoryType = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
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
            let notification = notifications[indexPath.row]
            NotificationManager.shared.removeNotification(notification.id)
        }
    }
    
    // MARK: - Helper Methods
    
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