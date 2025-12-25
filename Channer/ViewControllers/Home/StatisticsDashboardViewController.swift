import UIKit

/// View controller displaying comprehensive browsing statistics and analytics
class StatisticsDashboardViewController: UIViewController {

    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statsManager = StatisticsManager.shared

    // Summary Section
    private let summaryCard = UIView()
    private let totalThreadsLabel = UILabel()
    private let totalBoardsLabel = UILabel()
    private let totalTimeLabel = UILabel()
    private let firstRecordedLabel = UILabel()

    // Board Statistics Section
    private let boardsCard = UIView()
    private let boardsChartView = BarChartView()
    private let boardsHeaderLabel = UILabel()

    // Activity Section
    private let activityCard = UIView()
    private let activityChartView = LineChartView()
    private let activityHeaderLabel = UILabel()

    // Hourly Activity Section
    private let hourlyCard = UIView()
    private let hourlyChartView = BarChartView()
    private let hourlyHeaderLabel = UILabel()

    // Storage Section
    private let storageCard = UIView()
    private let storagePieChart = PieChartView()
    private let storageLegend = ChartLegendView()
    private let storageHeaderLabel = UILabel()
    private let storageTotalLabel = UILabel()
    private let storageLoadingIndicator = UIActivityIndicatorView(style: .medium)

    // Colors for charts
    private let chartColors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemOrange,
        .systemPurple,
        .systemPink,
        .systemTeal,
        .systemIndigo,
        .systemRed,
        .systemYellow,
        .systemCyan
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadStatistics()
        observeThemeChanges()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateCharts()
    }

    // MARK: - Setup
    private func setupNavigationBar() {
        title = "Statistics"
        navigationItem.largeTitleDisplayMode = .never

        // Add export button
        let exportButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportStatistics)
        )

        // Add clear button
        let clearButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearStatisticsTapped)
        )
        clearButton.tintColor = .systemRed

        navigationItem.rightBarButtonItems = [exportButton, clearButton]
    }

    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        // Setup content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        setupSummarySection()
        setupBoardsSection()
        setupActivitySection()
        setupHourlySection()
        setupStorageSection()
    }

    private func setupSummarySection() {
        setupCard(summaryCard)
        contentView.addSubview(summaryCard)

        let headerLabel = createHeaderLabel(text: "Overview")
        summaryCard.addSubview(headerLabel)

        // Create stat items
        let statsStack = UIStackView()
        statsStack.axis = .vertical
        statsStack.spacing = 16
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(statsStack)

        // Threads viewed
        let threadsItem = createStatItem(
            icon: "text.bubble",
            title: "Threads Viewed",
            valueLabel: totalThreadsLabel
        )
        statsStack.addArrangedSubview(threadsItem)

        // Boards visited
        let boardsItem = createStatItem(
            icon: "square.grid.2x2",
            title: "Unique Boards",
            valueLabel: totalBoardsLabel
        )
        statsStack.addArrangedSubview(boardsItem)

        // Time spent
        let timeItem = createStatItem(
            icon: "clock",
            title: "Time Spent",
            valueLabel: totalTimeLabel
        )
        statsStack.addArrangedSubview(timeItem)

        // First recorded
        let firstItem = createStatItem(
            icon: "calendar",
            title: "Tracking Since",
            valueLabel: firstRecordedLabel
        )
        statsStack.addArrangedSubview(firstItem)

        NSLayoutConstraint.activate([
            summaryCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            summaryCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            summaryCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            headerLabel.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),

            statsStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16)
        ])
    }

    private func setupBoardsSection() {
        setupCard(boardsCard)
        contentView.addSubview(boardsCard)

        boardsHeaderLabel.text = "Most Visited Boards"
        boardsHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        boardsHeaderLabel.textColor = ThemeManager.shared.primaryTextColor
        boardsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        boardsCard.addSubview(boardsHeaderLabel)

        boardsChartView.translatesAutoresizingMaskIntoConstraints = false
        boardsChartView.barColor = .systemBlue
        boardsCard.addSubview(boardsChartView)

        NSLayoutConstraint.activate([
            boardsCard.topAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: 16),
            boardsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            boardsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            boardsHeaderLabel.topAnchor.constraint(equalTo: boardsCard.topAnchor, constant: 16),
            boardsHeaderLabel.leadingAnchor.constraint(equalTo: boardsCard.leadingAnchor, constant: 16),
            boardsHeaderLabel.trailingAnchor.constraint(equalTo: boardsCard.trailingAnchor, constant: -16),

            boardsChartView.topAnchor.constraint(equalTo: boardsHeaderLabel.bottomAnchor, constant: 16),
            boardsChartView.leadingAnchor.constraint(equalTo: boardsCard.leadingAnchor, constant: 8),
            boardsChartView.trailingAnchor.constraint(equalTo: boardsCard.trailingAnchor, constant: -8),
            boardsChartView.heightAnchor.constraint(equalToConstant: 200),
            boardsChartView.bottomAnchor.constraint(equalTo: boardsCard.bottomAnchor, constant: -16)
        ])
    }

    private func setupActivitySection() {
        setupCard(activityCard)
        contentView.addSubview(activityCard)

        activityHeaderLabel.text = "Daily Activity (Last 7 Days)"
        activityHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        activityHeaderLabel.textColor = ThemeManager.shared.primaryTextColor
        activityHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        activityCard.addSubview(activityHeaderLabel)

        activityChartView.translatesAutoresizingMaskIntoConstraints = false
        activityChartView.lineColor = .systemGreen
        activityChartView.showArea = true
        activityCard.addSubview(activityChartView)

        NSLayoutConstraint.activate([
            activityCard.topAnchor.constraint(equalTo: boardsCard.bottomAnchor, constant: 16),
            activityCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            activityCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            activityHeaderLabel.topAnchor.constraint(equalTo: activityCard.topAnchor, constant: 16),
            activityHeaderLabel.leadingAnchor.constraint(equalTo: activityCard.leadingAnchor, constant: 16),
            activityHeaderLabel.trailingAnchor.constraint(equalTo: activityCard.trailingAnchor, constant: -16),

            activityChartView.topAnchor.constraint(equalTo: activityHeaderLabel.bottomAnchor, constant: 16),
            activityChartView.leadingAnchor.constraint(equalTo: activityCard.leadingAnchor, constant: 8),
            activityChartView.trailingAnchor.constraint(equalTo: activityCard.trailingAnchor, constant: -8),
            activityChartView.heightAnchor.constraint(equalToConstant: 180),
            activityChartView.bottomAnchor.constraint(equalTo: activityCard.bottomAnchor, constant: -16)
        ])
    }

    private func setupHourlySection() {
        setupCard(hourlyCard)
        contentView.addSubview(hourlyCard)

        hourlyHeaderLabel.text = "Most Active Times"
        hourlyHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        hourlyHeaderLabel.textColor = ThemeManager.shared.primaryTextColor
        hourlyHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        hourlyCard.addSubview(hourlyHeaderLabel)

        hourlyChartView.translatesAutoresizingMaskIntoConstraints = false
        hourlyChartView.barColor = .systemOrange
        hourlyChartView.showValues = false
        hourlyCard.addSubview(hourlyChartView)

        NSLayoutConstraint.activate([
            hourlyCard.topAnchor.constraint(equalTo: activityCard.bottomAnchor, constant: 16),
            hourlyCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hourlyCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            hourlyHeaderLabel.topAnchor.constraint(equalTo: hourlyCard.topAnchor, constant: 16),
            hourlyHeaderLabel.leadingAnchor.constraint(equalTo: hourlyCard.leadingAnchor, constant: 16),
            hourlyHeaderLabel.trailingAnchor.constraint(equalTo: hourlyCard.trailingAnchor, constant: -16),

            hourlyChartView.topAnchor.constraint(equalTo: hourlyHeaderLabel.bottomAnchor, constant: 16),
            hourlyChartView.leadingAnchor.constraint(equalTo: hourlyCard.leadingAnchor, constant: 4),
            hourlyChartView.trailingAnchor.constraint(equalTo: hourlyCard.trailingAnchor, constant: -4),
            hourlyChartView.heightAnchor.constraint(equalToConstant: 160),
            hourlyChartView.bottomAnchor.constraint(equalTo: hourlyCard.bottomAnchor, constant: -16)
        ])
    }

    private func setupStorageSection() {
        setupCard(storageCard)
        contentView.addSubview(storageCard)

        storageHeaderLabel.text = "Storage Usage"
        storageHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        storageHeaderLabel.textColor = ThemeManager.shared.primaryTextColor
        storageHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        storageCard.addSubview(storageHeaderLabel)

        storageTotalLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        storageTotalLabel.textColor = ThemeManager.shared.secondaryTextColor
        storageTotalLabel.translatesAutoresizingMaskIntoConstraints = false
        storageCard.addSubview(storageTotalLabel)

        storagePieChart.translatesAutoresizingMaskIntoConstraints = false
        storagePieChart.innerRadiusRatio = 0.5
        storageCard.addSubview(storagePieChart)

        storageLegend.translatesAutoresizingMaskIntoConstraints = false
        storageCard.addSubview(storageLegend)

        storageLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        storageLoadingIndicator.hidesWhenStopped = true
        storageCard.addSubview(storageLoadingIndicator)

        NSLayoutConstraint.activate([
            storageCard.topAnchor.constraint(equalTo: hourlyCard.bottomAnchor, constant: 16),
            storageCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            storageCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            storageCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            storageHeaderLabel.topAnchor.constraint(equalTo: storageCard.topAnchor, constant: 16),
            storageHeaderLabel.leadingAnchor.constraint(equalTo: storageCard.leadingAnchor, constant: 16),

            storageTotalLabel.centerYAnchor.constraint(equalTo: storageHeaderLabel.centerYAnchor),
            storageTotalLabel.trailingAnchor.constraint(equalTo: storageCard.trailingAnchor, constant: -16),

            storagePieChart.topAnchor.constraint(equalTo: storageHeaderLabel.bottomAnchor, constant: 16),
            storagePieChart.leadingAnchor.constraint(equalTo: storageCard.leadingAnchor, constant: 16),
            storagePieChart.widthAnchor.constraint(equalToConstant: 150),
            storagePieChart.heightAnchor.constraint(equalToConstant: 150),

            storageLegend.centerYAnchor.constraint(equalTo: storagePieChart.centerYAnchor),
            storageLegend.leadingAnchor.constraint(equalTo: storagePieChart.trailingAnchor, constant: 16),
            storageLegend.trailingAnchor.constraint(equalTo: storageCard.trailingAnchor, constant: -16),

            storagePieChart.bottomAnchor.constraint(equalTo: storageCard.bottomAnchor, constant: -16),

            storageLoadingIndicator.centerXAnchor.constraint(equalTo: storagePieChart.centerXAnchor),
            storageLoadingIndicator.centerYAnchor.constraint(equalTo: storagePieChart.centerYAnchor)
        ])
    }

    // MARK: - Helper Methods
    private func setupCard(_ card: UIView) {
        card.backgroundColor = ThemeManager.shared.cellBackgroundColor
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
    }

    private func createHeaderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = ThemeManager.shared.primaryTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createStatItem(icon: String, title: String, valueLabel: UILabel) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = ThemeManager.shared.cellBorderColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = ThemeManager.shared.secondaryTextColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = ThemeManager.shared.primaryTextColor
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    // MARK: - Data Loading
    private func loadStatistics() {
        let stats = statsManager.getStatistics()

        // Update summary
        totalThreadsLabel.text = "\(stats.totalThreadsViewed)"
        totalBoardsLabel.text = "\(stats.totalBoardsVisited)"
        totalTimeLabel.text = statsManager.getFormattedTotalTime()

        if let firstDate = stats.firstRecordedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            firstRecordedLabel.text = formatter.string(from: firstDate)
        } else {
            firstRecordedLabel.text = "Today"
        }

        // Load board statistics
        let topBoards = statsManager.getTopBoards(limit: 6)
        if !topBoards.isEmpty {
            boardsChartView.dataPoints = topBoards.enumerated().map { index, board in
                ChartDataPoint(
                    label: "/\(board.boardAbv)/",
                    value: Double(board.visitCount),
                    color: chartColors[index % chartColors.count]
                )
            }
        } else {
            // Show placeholder
            boardsChartView.dataPoints = [
                ChartDataPoint(label: "No data", value: 0)
            ]
        }

        // Load daily activity
        let dailyActivity = statsManager.getDailyActivity(days: 7)
        if !dailyActivity.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            activityChartView.dataPoints = dailyActivity.map { activity in
                ChartDataPoint(
                    label: formatter.string(from: activity.date),
                    value: Double(activity.threadViews)
                )
            }
        } else {
            // Generate placeholder with current week
            var placeholderData: [ChartDataPoint] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            for i in (0..<7).reversed() {
                if let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) {
                    placeholderData.append(ChartDataPoint(
                        label: formatter.string(from: date),
                        value: 0
                    ))
                }
            }
            activityChartView.dataPoints = placeholderData
        }

        // Load hourly activity
        let hourlyActivity = statsManager.getHourlyActivity()
        // Show every 3 hours for better label readability
        hourlyChartView.dataPoints = hourlyActivity.enumerated().compactMap { index, activity in
            let label = index % 3 == 0 ? "\(activity.hour)" : ""
            return ChartDataPoint(
                label: label,
                value: Double(activity.visitCount)
            )
        }

        // Load storage usage
        loadStorageUsage()
    }

    private func loadStorageUsage() {
        storageLoadingIndicator.startAnimating()
        storagePieChart.isHidden = true

        statsManager.calculateStorageUsage { [weak self] usage in
            guard let self = self else { return }

            self.storageLoadingIndicator.stopAnimating()
            self.storagePieChart.isHidden = false

            self.storageTotalLabel.text = "Total: \(self.statsManager.formatBytes(usage.totalSize))"

            if usage.totalSize > 0 {
                self.storagePieChart.dataPoints = [
                    PieChartDataPoint(
                        label: "Threads",
                        value: Double(usage.cachedThreadsSize),
                        color: .systemBlue
                    ),
                    PieChartDataPoint(
                        label: "Images",
                        value: Double(usage.cachedImagesSize),
                        color: .systemGreen
                    ),
                    PieChartDataPoint(
                        label: "Media",
                        value: Double(usage.downloadedMediaSize),
                        color: .systemOrange
                    )
                ]

                self.storageLegend.items = [
                    ("Threads: \(self.statsManager.formatBytes(usage.cachedThreadsSize))", .systemBlue),
                    ("Images: \(self.statsManager.formatBytes(usage.cachedImagesSize))", .systemGreen),
                    ("Media: \(self.statsManager.formatBytes(usage.downloadedMediaSize))", .systemOrange)
                ]
            } else {
                self.storagePieChart.dataPoints = [
                    PieChartDataPoint(label: "No data", value: 1, color: .systemGray)
                ]
                self.storageLegend.items = [("No cached data", .systemGray)]
            }

            self.storagePieChart.animateChart()
        }
    }

    private func animateCharts() {
        boardsChartView.animateChart()
        activityChartView.animateChart()
        hourlyChartView.animateChart()
    }

    // MARK: - Actions
    @objc private func exportStatistics() {
        guard let jsonString = statsManager.exportStatistics() else {
            showAlert(title: "Export Failed", message: "Unable to export statistics.")
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [jsonString],
            applicationActivities: nil
        )

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }

        present(activityVC, animated: true)
    }

    @objc private func clearStatisticsTapped() {
        let alert = UIAlertController(
            title: "Clear Statistics",
            message: "This will permanently delete all browsing statistics. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.statsManager.clearAllStatistics()
            self?.loadStatistics()
            self?.animateCharts()
        })

        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Theme Support
    private func observeThemeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // Update cards
        [summaryCard, boardsCard, activityCard, hourlyCard, storageCard].forEach { card in
            card.backgroundColor = ThemeManager.shared.cellBackgroundColor
            card.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        }

        // Update labels
        [boardsHeaderLabel, activityHeaderLabel, hourlyHeaderLabel, storageHeaderLabel].forEach { label in
            label.textColor = ThemeManager.shared.primaryTextColor
        }

        totalThreadsLabel.textColor = ThemeManager.shared.primaryTextColor
        totalBoardsLabel.textColor = ThemeManager.shared.primaryTextColor
        totalTimeLabel.textColor = ThemeManager.shared.primaryTextColor
        firstRecordedLabel.textColor = ThemeManager.shared.primaryTextColor
        storageTotalLabel.textColor = ThemeManager.shared.secondaryTextColor

        // Update charts
        boardsChartView.updateColors()
        activityChartView.updateColors()
        hourlyChartView.updateColors()
        storagePieChart.updateColors()
        storageLegend.updateColors()

        // Redraw
        view.setNeedsLayout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
