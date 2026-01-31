import UIKit
import UserNotifications

class DebugViewController: UIViewController {

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Notifications Section
    private let notificationsSectionLabel = UILabel()
    private let addNotificationView = UIView()
    private let addNotificationLabel = UILabel()
    private let addNotificationButton = UIButton(type: .system)

    private let clearNotificationsView = UIView()
    private let clearNotificationsLabel = UILabel()
    private let clearNotificationsButton = UIButton(type: .system)

    private let testDuplicateView = UIView()
    private let testDuplicateLabel = UILabel()
    private let testDuplicateButton = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() {
        title = "Debug"
        view.backgroundColor = UIColor.systemGroupedBackground

        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // Section Label
        notificationsSectionLabel.text = "Notifications"
        notificationsSectionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        notificationsSectionLabel.textColor = .secondaryLabel
        notificationsSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notificationsSectionLabel)

        // Add Notification View
        addNotificationView.backgroundColor = UIColor.secondarySystemGroupedBackground
        addNotificationView.layer.cornerRadius = 10
        addNotificationView.clipsToBounds = true
        addNotificationView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addNotificationView)

        addNotificationLabel.text = "Add Test Notification"
        addNotificationLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        addNotificationLabel.translatesAutoresizingMaskIntoConstraints = false
        addNotificationView.addSubview(addNotificationLabel)

        addNotificationButton.setTitle("Add", for: .normal)
        addNotificationButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        addNotificationButton.translatesAutoresizingMaskIntoConstraints = false
        addNotificationButton.addTarget(self, action: #selector(addNotificationTapped), for: .touchUpInside)
        addNotificationView.addSubview(addNotificationButton)

        // Clear Notifications View
        clearNotificationsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        clearNotificationsView.layer.cornerRadius = 10
        clearNotificationsView.clipsToBounds = true
        clearNotificationsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearNotificationsView)

        clearNotificationsLabel.text = "Clear All Notifications"
        clearNotificationsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        clearNotificationsLabel.translatesAutoresizingMaskIntoConstraints = false
        clearNotificationsView.addSubview(clearNotificationsLabel)

        clearNotificationsButton.setTitle("Clear", for: .normal)
        clearNotificationsButton.setTitleColor(.systemRed, for: .normal)
        clearNotificationsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        clearNotificationsButton.translatesAutoresizingMaskIntoConstraints = false
        clearNotificationsButton.addTarget(self, action: #selector(clearNotificationsTapped), for: .touchUpInside)
        clearNotificationsView.addSubview(clearNotificationsButton)

        // Test Duplicate Notifications View (PR #38 test)
        testDuplicateView.backgroundColor = UIColor.secondarySystemGroupedBackground
        testDuplicateView.layer.cornerRadius = 10
        testDuplicateView.clipsToBounds = true
        testDuplicateView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testDuplicateView)

        testDuplicateLabel.text = "Test Duplicate Push (PR #38)"
        testDuplicateLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        testDuplicateLabel.translatesAutoresizingMaskIntoConstraints = false
        testDuplicateView.addSubview(testDuplicateLabel)

        testDuplicateButton.setTitle("Send 3x", for: .normal)
        testDuplicateButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        testDuplicateButton.translatesAutoresizingMaskIntoConstraints = false
        testDuplicateButton.addTarget(self, action: #selector(testDuplicateNotificationsTapped), for: .touchUpInside)
        testDuplicateView.addSubview(testDuplicateButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Section Label
            notificationsSectionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            notificationsSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),

            // Add Notification View
            addNotificationView.topAnchor.constraint(equalTo: notificationsSectionLabel.bottomAnchor, constant: 8),
            addNotificationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            addNotificationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addNotificationView.heightAnchor.constraint(equalToConstant: 44),

            addNotificationLabel.leadingAnchor.constraint(equalTo: addNotificationView.leadingAnchor, constant: 16),
            addNotificationLabel.centerYAnchor.constraint(equalTo: addNotificationView.centerYAnchor),

            addNotificationButton.trailingAnchor.constraint(equalTo: addNotificationView.trailingAnchor, constant: -16),
            addNotificationButton.centerYAnchor.constraint(equalTo: addNotificationView.centerYAnchor),

            // Clear Notifications View
            clearNotificationsView.topAnchor.constraint(equalTo: addNotificationView.bottomAnchor, constant: 2),
            clearNotificationsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            clearNotificationsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            clearNotificationsView.heightAnchor.constraint(equalToConstant: 44),

            clearNotificationsLabel.leadingAnchor.constraint(equalTo: clearNotificationsView.leadingAnchor, constant: 16),
            clearNotificationsLabel.centerYAnchor.constraint(equalTo: clearNotificationsView.centerYAnchor),

            clearNotificationsButton.trailingAnchor.constraint(equalTo: clearNotificationsView.trailingAnchor, constant: -16),
            clearNotificationsButton.centerYAnchor.constraint(equalTo: clearNotificationsView.centerYAnchor),

            // Test Duplicate View
            testDuplicateView.topAnchor.constraint(equalTo: clearNotificationsView.bottomAnchor, constant: 2),
            testDuplicateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            testDuplicateView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            testDuplicateView.heightAnchor.constraint(equalToConstant: 44),

            testDuplicateLabel.leadingAnchor.constraint(equalTo: testDuplicateView.leadingAnchor, constant: 16),
            testDuplicateLabel.centerYAnchor.constraint(equalTo: testDuplicateView.centerYAnchor),

            testDuplicateButton.trailingAnchor.constraint(equalTo: testDuplicateView.trailingAnchor, constant: -16),
            testDuplicateButton.centerYAnchor.constraint(equalTo: testDuplicateView.centerYAnchor),

            // Bottom constraint for scroll content size
            testDuplicateView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions
    @objc private func addNotificationTapped() {
        let types: [NotificationType] = [.threadUpdate, .savedSearchAlert, .watchedPostReply, .myPostReply]
        let randomType = types.randomElement() ?? .threadUpdate

        let notification = ReplyNotification(
            boardAbv: "g",
            threadNo: "\(Int.random(in: 10000000...99999999))",
            replyNo: "\(Int.random(in: 10000000...99999999))",
            replyToNo: "\(Int.random(in: 10000000...99999999))",
            replyText: "This is a test debug notification created at \(Date())",
            notificationType: randomType,
            threadTitle: "Test Thread Title",
            newReplyCount: randomType == .threadUpdate ? Int.random(in: 1...10) : nil
        )

        NotificationManager.shared.addNotification(notification)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show brief confirmation
        let alert = UIAlertController(
            title: "Notification Added",
            message: "Type: \(randomType.rawValue)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func clearNotificationsTapped() {
        let alert = UIAlertController(
            title: "Clear All Notifications",
            message: "Are you sure you want to clear all notifications?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            NotificationManager.shared.clearAllNotifications()

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            let confirmAlert = UIAlertController(
                title: "Cleared",
                message: "All notifications have been cleared",
                preferredStyle: .alert
            )
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(confirmAlert, animated: true)
        })

        present(alert, animated: true)
    }

    @objc private func testDuplicateNotificationsTapped() {
        // Test PR #38: Send 3 iOS push notifications with the same stable identifier
        // If the fix works, only 1 notification should appear in notification center

        // Use stable identifier (same format as the fix in PR #38)
        let testBoard = "g"
        let testThread = "12345678"
        let identifier = "thread-\(testBoard)-\(testThread)"

        // First, remove any existing notification with this identifier
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        // Send 3 notifications with delays to ensure proper deduplication test
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 0.5) { [weak self] in
                let content = UNMutableNotificationContent()
                content.title = "Test Thread Update"
                content.body = "Notification #\(i) - Only the last one should remain in notification center"
                content.sound = .default

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Debug: Failed to send test notification #\(i): \(error)")
                    } else {
                        print("Debug: Sent test notification #\(i) with identifier: \(identifier)")
                    }
                }

                // After the last notification, check the notification center count
                if i == 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.checkNotificationCount(identifier: identifier)
                    }
                }
            }
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show explanation
        let alert = UIAlertController(
            title: "Sending 3 Notifications",
            message: "Sending 3 notifications with 0.5s delays using identifier:\n\(identifier)\n\nYou may see 3 banners, but check the notification center - there should be only 1.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func checkNotificationCount(identifier: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            let matchingCount = notifications.filter { $0.request.identifier == identifier }.count
            let totalCount = notifications.count

            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Notification Center Check",
                    message: "Notifications with identifier '\(identifier)': \(matchingCount)\nTotal notifications: \(totalCount)\n\nExpected: 1 (deduplication working)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
}
