import UIKit
import UserNotifications
import SwiftyJSON
import Foundation

class settings: UIViewController, UISearchBarDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties
    var boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    var boardAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
    
    // Filtered arrays for search functionality
    private var filteredBoardNames: [String] = []
    private var filteredBoardAbv: [String] = []
    
    // UI Components
    private let headerLabel = UILabel()
    private let searchBar = UISearchBar()
    private let collectionView: UICollectionView
    private let selectedBoardView = UIView()
    private let selectedBoardLabel = UILabel()
    private let faceIDView = UIView()
    private let faceIDLabel = UILabel()
    private let faceIDToggle = UISwitch()
    private let notificationsView = UIView()
    private let notificationsLabel = UILabel()
    private let notificationsToggle = UISwitch()
    private let offlineReadingView = UIView()
    private let offlineReadingLabel = UILabel()
    private let offlineReadingToggle = UISwitch()
    private let launchWithStartupBoardView = UIView()
    private let launchWithStartupBoardLabel = UILabel()
    private let launchWithStartupBoardToggle = UISwitch()
    private let themeSettingsView = UIView()
    private let themeSettingsLabel = UILabel()
    private let themeSettingsButton = UIButton(type: .system)
    private let contentFilteringView = UIView()
    private let contentFilteringLabel = UILabel()
    private let contentFilteringButton = UIButton(type: .system)
    private let autoRefreshView = UIView()
    private let autoRefreshLabel = UILabel()
    private let autoRefreshButton = UIButton(type: .system)
    
    // Constants
    private let cellIdentifier = "BoardCell"
    private let userDefaultsKey = "defaultBoard"
    private let faceIDEnabledKey = "channer_faceID_authentication_enabled"
    private let notificationsEnabledKey = "channer_notifications_enabled"
    private let offlineReadingEnabledKey = "channer_offline_reading_enabled"
    private let launchWithStartupBoardKey = "channer_launch_with_startup_board"
    private let boardsAutoRefreshIntervalKey = "channer_boards_auto_refresh_interval"
    private let threadsAutoRefreshIntervalKey = "channer_threads_auto_refresh_interval"
    private let sectionInset: CGFloat = 16
    private let interItemSpacing: CGFloat = 10
    private let lineSpacing: CGFloat = 10
    
    // MARK: - Initialization
    init() {
        let layout = UICollectionViewFlowLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set default values for toggles if they don't exist yet
        if UserDefaults.standard.object(forKey: faceIDEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: faceIDEnabledKey)
        }
        
        if UserDefaults.standard.object(forKey: offlineReadingEnabledKey) == nil {
            UserDefaults.standard.set(false, forKey: offlineReadingEnabledKey)
            // Initialize the ThreadCacheManager's setting as well
            ThreadCacheManager.shared.setOfflineReadingEnabled(false)
        }
        
        sortBoardsAlphabetically()
        setupUI()
        filteredBoardNames = boardNames
        filteredBoardAbv = boardAbv
    }
    
    private func sortBoardsAlphabetically() {
        // Create array of tuples containing both board name and abbreviation
        let combinedBoards = zip(boardNames, boardAbv).map { ($0, $1) }
        
        // Sort the combined array by board name
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        
        // Update the original arrays with sorted values
        boardNames = sortedBoards.map { $0.0 }
        boardAbv = sortedBoards.map { $0.1 }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Header Label
        headerLabel.text = "Choose Your Start Up Board"
        headerLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // Search Bar
        searchBar.placeholder = "Search Boards"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        view.addSubview(searchBar)
        
        // Selected Board View
        selectedBoardView.backgroundColor = UIColor.systemGray5
        selectedBoardView.layer.cornerRadius = 12
        selectedBoardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedBoardView)
        
        // Selected Board Label
        selectedBoardLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        selectedBoardLabel.textAlignment = .center
        selectedBoardLabel.translatesAutoresizingMaskIntoConstraints = false
        updateSelectedBoardLabel()
        selectedBoardView.addSubview(selectedBoardLabel)
        
        // FaceID View
        faceIDView.backgroundColor = UIColor.secondarySystemGroupedBackground
        faceIDView.layer.cornerRadius = 10
        faceIDView.clipsToBounds = true
        faceIDView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(faceIDView)
        
        // FaceID Label
        faceIDLabel.text = "Require FaceID/TouchID for History & Favorites"
        faceIDLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        faceIDLabel.textAlignment = .left
        faceIDLabel.numberOfLines = 1
        faceIDLabel.adjustsFontSizeToFitWidth = true
        faceIDLabel.minimumScaleFactor = 0.8
        faceIDLabel.translatesAutoresizingMaskIntoConstraints = false
        faceIDView.addSubview(faceIDLabel)
        
        // FaceID Toggle
        let isFaceIDEnabled = UserDefaults.standard.bool(forKey: faceIDEnabledKey)
        faceIDToggle.isOn = isFaceIDEnabled
        print("Initializing FaceID toggle with value: \(isFaceIDEnabled)")
        faceIDToggle.translatesAutoresizingMaskIntoConstraints = false
        // Fix toggle size to standard iOS toggle dimensions
        faceIDToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85) // Make toggle slightly smaller
        faceIDToggle.addTarget(self, action: #selector(faceIDToggleChanged), for: .valueChanged)
        faceIDView.addSubview(faceIDToggle)
        
        // Notifications View
        notificationsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        notificationsView.layer.cornerRadius = 10
        notificationsView.clipsToBounds = true
        notificationsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(notificationsView)
        
        // Notifications Label
        notificationsLabel.text = "Enable Thread Update Notifications"
        notificationsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        notificationsLabel.textAlignment = .left
        notificationsLabel.numberOfLines = 1
        notificationsLabel.adjustsFontSizeToFitWidth = true
        notificationsLabel.minimumScaleFactor = 0.8
        notificationsLabel.translatesAutoresizingMaskIntoConstraints = false
        notificationsView.addSubview(notificationsLabel)
        
        // Notifications Toggle
        let isNotificationsEnabled = UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        notificationsToggle.isOn = isNotificationsEnabled
        print("Initializing Notifications toggle with value: \(isNotificationsEnabled)")
        notificationsToggle.translatesAutoresizingMaskIntoConstraints = false
        notificationsToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85) // Make toggle slightly smaller
        notificationsToggle.addTarget(self, action: #selector(notificationsToggleChanged), for: .valueChanged)
        notificationsView.addSubview(notificationsToggle)
        
        // Offline Reading View
        offlineReadingView.backgroundColor = UIColor.secondarySystemGroupedBackground
        offlineReadingView.layer.cornerRadius = 10
        offlineReadingView.clipsToBounds = true
        offlineReadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(offlineReadingView)
        
        // Offline Reading Label
        offlineReadingLabel.text = "Enable Offline Reading Mode"
        offlineReadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        offlineReadingLabel.textAlignment = .left
        offlineReadingLabel.numberOfLines = 1
        offlineReadingLabel.adjustsFontSizeToFitWidth = true
        offlineReadingLabel.minimumScaleFactor = 0.8
        offlineReadingLabel.translatesAutoresizingMaskIntoConstraints = false
        offlineReadingView.addSubview(offlineReadingLabel)
        
        // Offline Reading Toggle
        let isOfflineReadingEnabled = UserDefaults.standard.bool(forKey: offlineReadingEnabledKey)
        offlineReadingToggle.isOn = isOfflineReadingEnabled
        print("Initializing Offline Reading toggle with value: \(isOfflineReadingEnabled)")
        offlineReadingToggle.translatesAutoresizingMaskIntoConstraints = false
        offlineReadingToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85) // Make toggle slightly smaller
        offlineReadingToggle.addTarget(self, action: #selector(offlineReadingToggleChanged), for: .valueChanged)
        offlineReadingView.addSubview(offlineReadingToggle)
        
        // Add 'Manage' button for offline threads
        let manageButton = UIButton(type: .system)
        manageButton.setTitle("Manage", for: .normal)
        manageButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        manageButton.translatesAutoresizingMaskIntoConstraints = false
        manageButton.addTarget(self, action: #selector(manageOfflineThreads), for: .touchUpInside)
        offlineReadingView.addSubview(manageButton)
        
        // Set constraints for the manage button
        NSLayoutConstraint.activate([
            manageButton.centerYAnchor.constraint(equalTo: offlineReadingView.centerYAnchor),
            manageButton.trailingAnchor.constraint(equalTo: offlineReadingToggle.leadingAnchor, constant: -15)
        ])
        
        // Launch With Startup Board View
        launchWithStartupBoardView.backgroundColor = UIColor.secondarySystemGroupedBackground
        launchWithStartupBoardView.layer.cornerRadius = 10
        launchWithStartupBoardView.clipsToBounds = true
        launchWithStartupBoardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(launchWithStartupBoardView)
        
        // Launch With Startup Board Label
        launchWithStartupBoardLabel.text = "Launch With Startup Board"
        launchWithStartupBoardLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        launchWithStartupBoardLabel.textAlignment = .left
        launchWithStartupBoardLabel.numberOfLines = 1
        launchWithStartupBoardLabel.adjustsFontSizeToFitWidth = true
        launchWithStartupBoardLabel.minimumScaleFactor = 0.8
        launchWithStartupBoardLabel.translatesAutoresizingMaskIntoConstraints = false
        launchWithStartupBoardView.addSubview(launchWithStartupBoardLabel)
        
        // Launch With Startup Board Toggle
        let isLaunchWithStartupBoardEnabled = UserDefaults.standard.bool(forKey: launchWithStartupBoardKey)
        launchWithStartupBoardToggle.isOn = isLaunchWithStartupBoardEnabled
        launchWithStartupBoardToggle.translatesAutoresizingMaskIntoConstraints = false
        launchWithStartupBoardToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85) // Make toggle slightly smaller
        launchWithStartupBoardToggle.addTarget(self, action: #selector(launchWithStartupBoardToggleChanged), for: .valueChanged)
        launchWithStartupBoardView.addSubview(launchWithStartupBoardToggle)
        
        // Theme Settings View
        themeSettingsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        themeSettingsView.layer.cornerRadius = 10
        themeSettingsView.clipsToBounds = true
        themeSettingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeSettingsView)
        
        // Theme Settings Label
        themeSettingsLabel.text = "App Theme Settings"
        themeSettingsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        themeSettingsLabel.textAlignment = .left
        themeSettingsLabel.numberOfLines = 1
        themeSettingsLabel.adjustsFontSizeToFitWidth = true
        themeSettingsLabel.minimumScaleFactor = 0.8
        themeSettingsLabel.translatesAutoresizingMaskIntoConstraints = false
        themeSettingsView.addSubview(themeSettingsLabel)
        
        // Theme Settings Button
        themeSettingsButton.setTitle("Customize", for: .normal)
        themeSettingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        themeSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        themeSettingsButton.addTarget(self, action: #selector(themeSettingsButtonTapped), for: .touchUpInside)
        themeSettingsView.addSubview(themeSettingsButton)
        
        // Content Filtering View
        contentFilteringView.backgroundColor = UIColor.secondarySystemGroupedBackground
        contentFilteringView.layer.cornerRadius = 10
        contentFilteringView.clipsToBounds = true
        contentFilteringView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentFilteringView)
        
        // Content Filtering Label
        contentFilteringLabel.text = "Content Filtering"
        contentFilteringLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        contentFilteringLabel.textAlignment = .left
        contentFilteringLabel.numberOfLines = 1
        contentFilteringLabel.adjustsFontSizeToFitWidth = true
        contentFilteringLabel.minimumScaleFactor = 0.8
        contentFilteringLabel.translatesAutoresizingMaskIntoConstraints = false
        contentFilteringView.addSubview(contentFilteringLabel)
        
        // Content Filtering Button
        contentFilteringButton.setTitle("Manage", for: .normal)
        contentFilteringButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        contentFilteringButton.translatesAutoresizingMaskIntoConstraints = false
        contentFilteringButton.addTarget(self, action: #selector(contentFilteringButtonTapped), for: .touchUpInside)
        contentFilteringView.addSubview(contentFilteringButton)
        
        // Auto-refresh View
        autoRefreshView.backgroundColor = UIColor.secondarySystemGroupedBackground
        autoRefreshView.layer.cornerRadius = 10
        autoRefreshView.clipsToBounds = true
        autoRefreshView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoRefreshView)
        
        // Auto-refresh Label
        autoRefreshLabel.text = "Auto-refresh Settings"
        autoRefreshLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        autoRefreshLabel.textAlignment = .left
        autoRefreshLabel.numberOfLines = 1
        autoRefreshLabel.adjustsFontSizeToFitWidth = true
        autoRefreshLabel.minimumScaleFactor = 0.8
        autoRefreshLabel.translatesAutoresizingMaskIntoConstraints = false
        autoRefreshView.addSubview(autoRefreshLabel)
        
        // Auto-refresh Button
        autoRefreshButton.setTitle("Configure", for: .normal)
        autoRefreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        autoRefreshButton.translatesAutoresizingMaskIntoConstraints = false
        autoRefreshButton.addTarget(self, action: #selector(autoRefreshButtonTapped), for: .touchUpInside)
        autoRefreshView.addSubview(autoRefreshButton)
        
        // Collection View
        collectionView.register(BoardCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsVerticalScrollIndicator = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        
        setupConstraints()
    }
    
    @objc private func faceIDToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: faceIDEnabledKey)
        UserDefaults.standard.synchronize() // Force save immediately
        print("FaceID toggle changed to: \(sender.isOn), UserDefaults synchronized")
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func notificationsToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: notificationsEnabledKey)
        UserDefaults.standard.synchronize() // Force save immediately
        print("Notifications toggle changed to: \(sender.isOn), UserDefaults synchronized")
        
        // Request notification permission if being turned on
        if sender.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if !granted {
                        // If permission denied, update the toggle
                        sender.isOn = false
                        UserDefaults.standard.set(false, forKey: self.notificationsEnabledKey)
                        
                        // Show an alert explaining how to enable notifications
                        let alert = UIAlertController(
                            title: "Notifications Disabled",
                            message: "Please enable notifications for Channer in Settings to receive thread updates.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func offlineReadingToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: offlineReadingEnabledKey)
        UserDefaults.standard.synchronize() // Force save immediately
        
        // Update ThreadCacheManager's setting as well
        ThreadCacheManager.shared.setOfflineReadingEnabled(sender.isOn)
        
        print("Offline Reading toggle changed to: \(sender.isOn), UserDefaults synchronized")
        
        if sender.isOn {
            // Show loading alert
            let loadingAlert = UIAlertController(
                title: "Offline Reading Enabled",
                message: "Caching all favorites for offline access...",
                preferredStyle: .alert
            )
            
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.startAnimating()
            
            loadingAlert.view.addSubview(activityIndicator)
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
                activityIndicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -20)
            ])
            
            self.present(loadingAlert, animated: true)
            
            // Cache all favorites
            FavoritesManager.shared.cacheAllFavorites { successCount, failureCount in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        // Show completion alert
                        let message: String
                        if failureCount == 0 {
                            message = "All \(successCount) favorites have been cached for offline reading."
                        } else {
                            message = "\(successCount) favorites cached successfully. \(failureCount) failed to cache."
                        }
                        
                        let completionAlert = UIAlertController(
                            title: "Offline Reading Enabled",
                            message: message,
                            preferredStyle: .alert
                        )
                        completionAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(completionAlert, animated: true)
                    }
                }
            }
        }
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func launchWithStartupBoardToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: launchWithStartupBoardKey)
        UserDefaults.standard.synchronize() // Force save immediately
        print("Launch with startup board toggle changed to: \(sender.isOn), UserDefaults synchronized")
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func manageOfflineThreads() {
        // Only proceed if offline reading is enabled
        if !UserDefaults.standard.bool(forKey: offlineReadingEnabledKey) {
            let alert = UIAlertController(
                title: "Offline Reading Disabled",
                message: "Please enable offline reading mode first.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Navigate to offline threads manager
        let offlineThreadsVC = OfflineThreadsVC()
        navigationController?.pushViewController(offlineThreadsVC, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func themeSettingsButtonTapped() {
        // Create an alert controller with all available themes
        let alertController = UIAlertController(
            title: "Select Theme",
            message: "Choose an app theme to apply",
            preferredStyle: .actionSheet
        )
        
        // Get built-in themes
        let themes = ThemeManager.shared.availableThemes.filter { $0.isBuiltIn }
        
        // Add an action for each theme
        for theme in themes {
            let action = UIAlertAction(title: theme.name, style: .default) { [weak self] _ in
                // Apply theme immediately
                ThemeManager.shared.setTheme(id: theme.id)
                
                // Show a confirmation
                let confirmToast = UIAlertController(
                    title: nil,
                    message: "Theme applied: \(theme.name)",
                    preferredStyle: .alert
                )
                self?.present(confirmToast, animated: true)
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    confirmToast.dismiss(animated: true)
                }
            }
            
            // Add a checkmark to the currently selected theme
            if theme.id == ThemeManager.shared.currentTheme.id {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func contentFilteringButtonTapped() {
        // Show content filtering options inline
        let alertController = UIAlertController(
            title: "Content Filtering",
            message: "Manage content filters to hide unwanted posts",
            preferredStyle: .actionSheet
        )
        
        // Add toggle for overall filtering
        var isFilteringEnabled = false
        var keywordCount = 0
        var posterCount = 0
        var imageCount = 0
        
        // Get current state from ContentFilterManager
        isFilteringEnabled = ContentFilterManager.shared.isFilteringEnabled()
        let filters = ContentFilterManager.shared.getAllFilters()
        keywordCount = filters.keywords.count
        posterCount = filters.posters.count
        imageCount = filters.images.count
        
        // Show current status
        let statusMessage = """
        Status: \(isFilteringEnabled ? "Enabled" : "Disabled")
        Keyword Filters: \(keywordCount)
        Poster ID Filters: \(posterCount)
        Image Name Filters: \(imageCount)
        """
        
        alertController.message = statusMessage
        
        // Add toggle action
        let toggleTitle = isFilteringEnabled ? "Disable Content Filtering" : "Enable Content Filtering"
        alertController.addAction(UIAlertAction(title: toggleTitle, style: .default) { _ in
            let newState = !isFilteringEnabled
            ContentFilterManager.shared.setFilteringEnabled(newState)
            
            // Show confirmation - we toggled from the original state
            let message = isFilteringEnabled ? "Content filtering disabled" : "Content filtering enabled"
            let confirmToast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            self.present(confirmToast, animated: true)
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confirmToast.dismiss(animated: true)
            }
        })
        
        // Add option to add keyword filter
        alertController.addAction(UIAlertAction(title: "Add Keyword Filter", style: .default) { _ in
            self.showAddKeywordFilterAlert()
        })
        
        // Add option to add poster filter
        alertController.addAction(UIAlertAction(title: "Add Poster ID Filter", style: .default) { _ in
            self.showAddPosterFilterAlert()
        })
        
        // Add option to clear all filters
        if keywordCount > 0 || posterCount > 0 || imageCount > 0 {
            alertController.addAction(UIAlertAction(title: "Clear All Filters", style: .destructive) { _ in
                self.showClearAllFiltersConfirmation()
            })
        }
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // MARK: - Content Filtering Helper Methods
    
    private func showAddKeywordFilterAlert() {
        let alert = UIAlertController(
            title: "Add Keyword Filter",
            message: "Enter a keyword to filter. Posts containing this text will be hidden.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Enter keyword..."
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            guard let keyword = alert.textFields?.first?.text,
                  !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            // Show confirmation
            let confirmToast = UIAlertController(title: nil, message: "Filter management not implemented yet", preferredStyle: .alert)
            self.present(confirmToast, animated: true)
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confirmToast.dismiss(animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showAddPosterFilterAlert() {
        let alert = UIAlertController(
            title: "Add Poster ID Filter",
            message: "Enter a poster ID to filter. Posts from this ID will be hidden.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Enter poster ID..."
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            guard let posterID = alert.textFields?.first?.text,
                  !posterID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            // Show confirmation
            let confirmToast = UIAlertController(title: nil, message: "Filter management not implemented yet", preferredStyle: .alert)
            self.present(confirmToast, animated: true)
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confirmToast.dismiss(animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showClearAllFiltersConfirmation() {
        let alert = UIAlertController(
            title: "Clear All Filters",
            message: "Are you sure you want to remove all content filters?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            // Show confirmation
            let confirmToast = UIAlertController(title: nil, message: "Filter management not implemented yet", preferredStyle: .alert)
            self.present(confirmToast, animated: true)
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confirmToast.dismiss(animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func autoRefreshButtonTapped() {
        let alertController = UIAlertController(
            title: "Auto-refresh Settings",
            message: "Configure refresh intervals for boards and threads",
            preferredStyle: .actionSheet
        )
        
        // Get current refresh intervals
        let boardsInterval = UserDefaults.standard.integer(forKey: boardsAutoRefreshIntervalKey)
        let threadsInterval = UserDefaults.standard.integer(forKey: threadsAutoRefreshIntervalKey)
        
        // Add info about current settings
        let currentSettings = """
        Boards: \(boardsInterval == 0 ? "Disabled" : "\(boardsInterval) seconds")
        Threads: \(threadsInterval == 0 ? "Disabled" : "\(threadsInterval) seconds")
        """
        alertController.message = currentSettings
        
        // Configure boards refresh
        alertController.addAction(UIAlertAction(title: "Configure Boards Refresh", style: .default) { [weak self] _ in
            self?.showRefreshIntervalPicker(for: "Boards", currentValue: boardsInterval) { interval in
                UserDefaults.standard.set(interval, forKey: self?.boardsAutoRefreshIntervalKey ?? "")
                
                // Show confirmation
                let message = interval == 0 ? "Boards auto-refresh disabled" : "Boards will refresh every \(interval) seconds"
                let confirmToast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                self?.present(confirmToast, animated: true)
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    confirmToast.dismiss(animated: true)
                }
            }
        })
        
        // Configure threads refresh
        alertController.addAction(UIAlertAction(title: "Configure Threads Refresh", style: .default) { [weak self] _ in
            self?.showRefreshIntervalPicker(for: "Threads", currentValue: threadsInterval) { interval in
                UserDefaults.standard.set(interval, forKey: self?.threadsAutoRefreshIntervalKey ?? "")
                
                // Show confirmation
                let message = interval == 0 ? "Threads auto-refresh disabled" : "Threads will refresh every \(interval) seconds"
                let confirmToast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                self?.present(confirmToast, animated: true)
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    confirmToast.dismiss(animated: true)
                }
            }
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad-specific popover configuration
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = autoRefreshButton
            popoverController.sourceRect = autoRefreshButton.bounds
            popoverController.permittedArrowDirections = .up
        }
        
        // Present the alert
        present(alertController, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func showRefreshIntervalPicker(for type: String, currentValue: Int, completion: @escaping (Int) -> Void) {
        let alertController = UIAlertController(
            title: "\(type) Refresh Interval",
            message: "Select refresh interval for \(type.lowercased())",
            preferredStyle: .actionSheet
        )
        
        // Refresh interval options
        let intervals = [
            (0, "Disabled"),
            (30, "30 seconds"),
            (60, "1 minute"),
            (120, "2 minutes"),
            (300, "5 minutes"),
            (600, "10 minutes")
        ]
        
        for (value, title) in intervals {
            let action = UIAlertAction(title: title, style: .default) { _ in
                completion(value)
            }
            
            // Add checkmark to current selection
            if value == currentValue {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad-specific popover configuration
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = autoRefreshButton
            popoverController.sourceRect = autoRefreshButton.bounds
            popoverController.permittedArrowDirections = .up
        }
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header Label
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            
            // Selected Board View
            selectedBoardView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 16),
            selectedBoardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectedBoardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectedBoardView.heightAnchor.constraint(equalToConstant: 50),
            
            // Selected Board Label
            selectedBoardLabel.centerYAnchor.constraint(equalTo: selectedBoardView.centerYAnchor),
            selectedBoardLabel.leadingAnchor.constraint(equalTo: selectedBoardView.leadingAnchor, constant: 16),
            selectedBoardLabel.trailingAnchor.constraint(equalTo: selectedBoardView.trailingAnchor, constant: -16),
            
            // FaceID View
            faceIDView.topAnchor.constraint(equalTo: selectedBoardView.bottomAnchor, constant: 16),
            faceIDView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            faceIDView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            faceIDView.heightAnchor.constraint(equalToConstant: 44),
            // Ensure the view is wide enough
            faceIDView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // FaceID Label
            faceIDLabel.centerYAnchor.constraint(equalTo: faceIDView.centerYAnchor),
            faceIDLabel.leadingAnchor.constraint(equalTo: faceIDView.leadingAnchor, constant: 20),
            // Set a fixed maximum width for the label instead
            faceIDLabel.trailingAnchor.constraint(lessThanOrEqualTo: faceIDToggle.leadingAnchor, constant: -15),
            
            // FaceID Toggle
            faceIDToggle.centerYAnchor.constraint(equalTo: faceIDView.centerYAnchor),
            faceIDToggle.trailingAnchor.constraint(equalTo: faceIDView.trailingAnchor, constant: -30),
            
            // Notifications View
            notificationsView.topAnchor.constraint(equalTo: faceIDView.bottomAnchor, constant: 16),
            notificationsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            notificationsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            notificationsView.heightAnchor.constraint(equalToConstant: 44),
            notificationsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Notifications Label
            notificationsLabel.centerYAnchor.constraint(equalTo: notificationsView.centerYAnchor),
            notificationsLabel.leadingAnchor.constraint(equalTo: notificationsView.leadingAnchor, constant: 20),
            notificationsLabel.trailingAnchor.constraint(lessThanOrEqualTo: notificationsToggle.leadingAnchor, constant: -15),
            
            // Notifications Toggle
            notificationsToggle.centerYAnchor.constraint(equalTo: notificationsView.centerYAnchor),
            notificationsToggle.trailingAnchor.constraint(equalTo: notificationsView.trailingAnchor, constant: -30),
            
            // Offline Reading View
            offlineReadingView.topAnchor.constraint(equalTo: notificationsView.bottomAnchor, constant: 16),
            offlineReadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            offlineReadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            offlineReadingView.heightAnchor.constraint(equalToConstant: 44),
            offlineReadingView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Offline Reading Label
            offlineReadingLabel.centerYAnchor.constraint(equalTo: offlineReadingView.centerYAnchor),
            offlineReadingLabel.leadingAnchor.constraint(equalTo: offlineReadingView.leadingAnchor, constant: 20),
            offlineReadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: offlineReadingToggle.leadingAnchor, constant: -15),
            
            // Offline Reading Toggle
            offlineReadingToggle.centerYAnchor.constraint(equalTo: offlineReadingView.centerYAnchor),
            offlineReadingToggle.trailingAnchor.constraint(equalTo: offlineReadingView.trailingAnchor, constant: -30),
            
            // Launch With Startup Board View
            launchWithStartupBoardView.topAnchor.constraint(equalTo: offlineReadingView.bottomAnchor, constant: 16),
            launchWithStartupBoardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            launchWithStartupBoardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            launchWithStartupBoardView.heightAnchor.constraint(equalToConstant: 44),
            launchWithStartupBoardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Launch With Startup Board Label
            launchWithStartupBoardLabel.centerYAnchor.constraint(equalTo: launchWithStartupBoardView.centerYAnchor),
            launchWithStartupBoardLabel.leadingAnchor.constraint(equalTo: launchWithStartupBoardView.leadingAnchor, constant: 20),
            launchWithStartupBoardLabel.trailingAnchor.constraint(lessThanOrEqualTo: launchWithStartupBoardToggle.leadingAnchor, constant: -15),
            
            // Launch With Startup Board Toggle
            launchWithStartupBoardToggle.centerYAnchor.constraint(equalTo: launchWithStartupBoardView.centerYAnchor),
            launchWithStartupBoardToggle.trailingAnchor.constraint(equalTo: launchWithStartupBoardView.trailingAnchor, constant: -30),
            
            // Theme Settings View
            themeSettingsView.topAnchor.constraint(equalTo: launchWithStartupBoardView.bottomAnchor, constant: 16),
            themeSettingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            themeSettingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            themeSettingsView.heightAnchor.constraint(equalToConstant: 44),
            themeSettingsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Theme Settings Label
            themeSettingsLabel.centerYAnchor.constraint(equalTo: themeSettingsView.centerYAnchor),
            themeSettingsLabel.leadingAnchor.constraint(equalTo: themeSettingsView.leadingAnchor, constant: 20),
            themeSettingsLabel.trailingAnchor.constraint(lessThanOrEqualTo: themeSettingsButton.leadingAnchor, constant: -15),
            
            // Theme Settings Button
            themeSettingsButton.centerYAnchor.constraint(equalTo: themeSettingsView.centerYAnchor),
            themeSettingsButton.trailingAnchor.constraint(equalTo: themeSettingsView.trailingAnchor, constant: -20),
            
            // Content Filtering View
            contentFilteringView.topAnchor.constraint(equalTo: themeSettingsView.bottomAnchor, constant: 16),
            contentFilteringView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentFilteringView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentFilteringView.heightAnchor.constraint(equalToConstant: 44),
            contentFilteringView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Content Filtering Label
            contentFilteringLabel.centerYAnchor.constraint(equalTo: contentFilteringView.centerYAnchor),
            contentFilteringLabel.leadingAnchor.constraint(equalTo: contentFilteringView.leadingAnchor, constant: 20),
            contentFilteringLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentFilteringButton.leadingAnchor, constant: -15),
            
            // Content Filtering Button
            contentFilteringButton.centerYAnchor.constraint(equalTo: contentFilteringView.centerYAnchor),
            contentFilteringButton.trailingAnchor.constraint(equalTo: contentFilteringView.trailingAnchor, constant: -20),
            
            // Auto-refresh View
            autoRefreshView.topAnchor.constraint(equalTo: contentFilteringView.bottomAnchor, constant: 16),
            autoRefreshView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            autoRefreshView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            autoRefreshView.heightAnchor.constraint(equalToConstant: 44),
            autoRefreshView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Auto-refresh Label
            autoRefreshLabel.centerYAnchor.constraint(equalTo: autoRefreshView.centerYAnchor),
            autoRefreshLabel.leadingAnchor.constraint(equalTo: autoRefreshView.leadingAnchor, constant: 20),
            autoRefreshLabel.trailingAnchor.constraint(lessThanOrEqualTo: autoRefreshButton.leadingAnchor, constant: -15),
            
            // Auto-refresh Button
            autoRefreshButton.centerYAnchor.constraint(equalTo: autoRefreshView.centerYAnchor),
            autoRefreshButton.trailingAnchor.constraint(equalTo: autoRefreshView.trailingAnchor, constant: -20),
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: autoRefreshView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    private func updateSelectedBoardLabel() {
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey),
           let index = boardAbv.firstIndex(of: savedDefault) {
            selectedBoardLabel.text = "\(boardNames[index]) (/\(savedDefault)/)"
        } else {
            selectedBoardLabel.text = "No default board selected"
        }
    }
    
    private func selectBoard(at indexPath: IndexPath) {
        let selectedBoardAbv = filteredBoardAbv[indexPath.item]
        UserDefaults.standard.set(selectedBoardAbv, forKey: userDefaultsKey)
        updateSelectedBoardLabel()
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Flash the selected board view to indicate change
        UIView.animate(withDuration: 0.2, animations: {
            self.selectedBoardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.selectedBoardView.backgroundColor = UIColor.systemGray5
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredBoardNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? BoardCell else {
            fatalError("Failed to dequeue BoardCell")
        }
        
        let boardName = filteredBoardNames[indexPath.item]
        let boardCode = filteredBoardAbv[indexPath.item]
        cell.configure(boardName: boardName, boardCode: boardCode)
        
        // Highlight the cell if it's the currently selected default board
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey), 
           savedDefault == boardCode {
            cell.isSelected = true
            cell.setSelected(true)
        } else {
            cell.isSelected = false
            cell.setSelected(false)
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectBoard(at: indexPath)
        collectionView.reloadData()
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate width based on number of cells per row
        let cellsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = collectionView.bounds.width - (sectionInset * 2) - (interItemSpacing * (cellsPerRow - 1))
        let cellWidth = availableWidth / cellsPerRow
        
        return CGSize(width: cellWidth, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: sectionInset, bottom: 0, right: sectionInset)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return interItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return lineSpacing
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredBoardNames = boardNames
            filteredBoardAbv = boardAbv
        } else {
            let searchTextLowercased = searchText.lowercased()
            
            // Filter by both board name and abbreviation
            let filteredIndices = boardNames.indices.filter { index in
                boardNames[index].lowercased().contains(searchTextLowercased) || 
                boardAbv[index].lowercased().contains(searchTextLowercased)
            }
            
            filteredBoardNames = filteredIndices.map { boardNames[$0] }
            filteredBoardAbv = filteredIndices.map { boardAbv[$0] }
        }
        
        collectionView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - BoardCell
class BoardCell: UICollectionViewCell {
    private let nameLabel = UILabel()
    private let codeLabel = UILabel()
    private let stackView = UIStackView()
    
    override var isSelected: Bool {
        didSet {
            setSelected(isSelected)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Cell appearance
        contentView.backgroundColor = UIColor.systemGray6
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        
        // Stack View
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Name Label
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        
        // Code Label
        codeLabel.font = UIFont.systemFont(ofSize: 12)
        codeLabel.textAlignment = .center
        codeLabel.textColor = UIColor.systemGray
        
        // Add labels to stack view
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(codeLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(boardName: String, boardCode: String) {
        nameLabel.text = boardName
        codeLabel.text = "/\(boardCode)/"
    }
    
    func setSelected(_ selected: Bool) {
        if selected {
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            contentView.backgroundColor = UIColor.systemGray6
            contentView.layer.borderWidth = 0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        setSelected(false)
    }
}


// MARK: - Offline Threads View Controller
class OfflineThreadsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    private let tableView = UITableView()
    private let emptyStateLabel = UILabel()
    private var cachedThreads: [CachedThread] = []
    private var threadInfo: [ThreadData] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Offline Threads"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        setupTableView()
        setupEmptyStateLabel()
        
        // Add Edit button to enable deletion mode
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditMode))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCachedThreads()
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OfflineThreadCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupEmptyStateLabel() {
        emptyStateLabel.text = "No threads saved for offline reading"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .gray
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16)
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true
        
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCachedThreads() {
        // Get cached threads from manager
        cachedThreads = ThreadCacheManager.shared.getAllCachedThreads()
        
        // Extract ThreadData info for each cached thread
        threadInfo = cachedThreads.compactMap { $0.getThreadInfo() }
        
        // Update UI based on whether we have cached threads
        emptyStateLabel.isHidden = !cachedThreads.isEmpty
        tableView.isHidden = cachedThreads.isEmpty
        
        // Reload table data
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func toggleEditMode() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        navigationItem.rightBarButtonItem?.title = tableView.isEditing ? "Done" : "Edit"
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return threadInfo.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OfflineThreadCell", for: indexPath)
        
        if indexPath.row < threadInfo.count {
            let thread = threadInfo[indexPath.row]
            
            // Configure cell
            var content = cell.defaultContentConfiguration()
            content.text = "/\(thread.boardAbv)/ - Thread #\(thread.number)"
            
            // Get the first line of the comment for a subtitle
            var commentPlainText = thread.comment
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            
            // Truncate to first line only
            if let newlineIndex = commentPlainText.firstIndex(of: "\n") {
                commentPlainText = String(commentPlainText[..<newlineIndex])
            }
            
            // Truncate long comments
            if commentPlainText.count > 100 {
                commentPlainText = String(commentPlainText.prefix(100)) + "..."
            }
            
            content.secondaryText = commentPlainText
            content.secondaryTextProperties.color = .gray
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 14)
            
            cell.contentConfiguration = content
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row < threadInfo.count {
            let thread = threadInfo[indexPath.row]
            
            // Create thread view controller
            let threadVC = threadRepliesTV()
            threadVC.boardAbv = thread.boardAbv
            threadVC.threadNumber = thread.number
            
            // Navigate to thread
            navigationController?.pushViewController(threadVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Get the thread to delete
            let thread = threadInfo[indexPath.row]
            
            // Remove from cache via manager
            ThreadCacheManager.shared.removeFromCache(boardAbv: thread.boardAbv, threadNumber: thread.number)
            
            // Remove from local arrays
            threadInfo.remove(at: indexPath.row)
            cachedThreads.remove(at: indexPath.row)
            
            // Update table
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Show empty state if no more threads
            if cachedThreads.isEmpty {
                emptyStateLabel.isHidden = false
                tableView.isHidden = true
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
}
