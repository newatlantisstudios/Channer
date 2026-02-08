import UIKit
import UserNotifications
import Foundation
import LocalAuthentication

class settings: UIViewController {

    // MARK: - Properties
    // Boards (now sourced from BoardsService)
    var boardNames: [String] = []
    var boardAbv: [String] = []
    
    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let selectedBoardView = UIView()
    private let selectedBoardLabel = UILabel()
    private let selectBoardButton = UIButton(type: .system)
    private let faceIDView = UIView()
    private let faceIDLabel = UILabel()
    private let faceIDToggle = UISwitch()
    private let notificationsView = UIView()
    private let notificationsLabel = UILabel()
    private let notificationsToggle = UISwitch()
    private let offlineReadingView = UIView()
    private let offlineReadingLabel = UILabel()
    private let offlineReadingSubtitleLabel = UILabel()
    private let offlineReadingToggle = UISwitch()
    private let iCloudSyncView = UIView()
    private let iCloudSyncLabel = UILabel()
    private let iCloudSyncToggle = UISwitch()
    private let iCloudSyncStatusLabel = UILabel()
    private let iCloudForceSync = UIButton(type: .system)
    private let launchWithStartupBoardView = UIView()
    private let launchWithStartupBoardLabel = UILabel()
    private let launchWithStartupBoardToggle = UISwitch()
    private let themeSettingsView = UIView()
    private let themeSettingsLabel = UILabel()
    private let themeSettingsButton = UIButton(type: .system)
    private let fontSizeView = UIView()
    private let fontSizeLabel = UILabel()
    private let fontSizeStepper = UIStepper()
    private let fontSizeValueLabel = UILabel()
    private let gridItemSizeView = UIView()
    private let gridItemSizeLabel = UILabel()
    private let gridItemSizeSegment = UISegmentedControl(items: ["XS", "S", "M", "L", "XL"])
    private var gridItemSizeHeightConstraint: NSLayoutConstraint!
    private let contentFilteringView = UIView()
    private let contentFilteringLabel = UILabel()
    private let contentFilteringButton = UIButton(type: .system)
    private let watchRulesView = UIView()
    private let watchRulesLabel = UILabel()
    private let watchRulesButton = UIButton(type: .system)
    private let autoRefreshView = UIView()
    private let autoRefreshLabel = UILabel()
    private let autoRefreshButton = UIButton(type: .system)
    private let statisticsView = UIView()
    private let statisticsLabel = UILabel()
    private let statisticsButton = UIButton(type: .system)
    private let newPostBehaviorView = UIView()
    private let newPostBehaviorLabel = UILabel()
    private let newPostBehaviorSegment = UISegmentedControl(items: ["Jump Button", "Auto-scroll", "Do Nothing"])
    private let keyboardShortcutsView = UIView()
    private let keyboardShortcutsLabel = UILabel()
    private let keyboardShortcutsToggle = UISwitch()

    private let passSettingsView = UIView()
    private let passSettingsLabel = UILabel()
    private let passSettingsButton = UIButton(type: .system)
    private let passStatusIndicator = UIView()

    private let highQualityThumbnailsView = UIView()
    private let highQualityThumbnailsLabel = UILabel()
    private let highQualityThumbnailsToggle = UISwitch()

    private let thumbnailSizeView = UIView()
    private let thumbnailSizeLabel = UILabel()
    private let thumbnailSizeSegment = UISegmentedControl(items: ["S", "M", "L", "XL", "2XL", "3XL"])
    
    private var boardsDisplayModeView: UIView!
    private var boardsDisplayModeLabel: UILabel!
    private var boardsDisplayModeSegment: UISegmentedControl!
    private var threadsDisplayModeView: UIView!
    private var threadsDisplayModeLabel: UILabel!
    private var threadsDisplayModeSegment: UISegmentedControl!

    // Hidden Boards UI
    private let hiddenBoardsView = UIView()
    private let hiddenBoardsLabel = UILabel()
    private let hiddenBoardsCountLabel = UILabel()
    private let hiddenBoardsButton = UIButton(type: .system)
    
    // UI for preload videos toggle
    private let preloadVideosView = UIView()
    private let preloadVideosLabel = UILabel()
    private let preloadVideosToggle = UISwitch()

    private let defaultVideoMutedView = UIView()
    private let defaultVideoMutedLabel = UILabel()
    private let defaultVideoMutedToggle = UISwitch()

    private let mediaPrefetchSettingsView = UIView()
    private let mediaPrefetchSettingsLabel = UILabel()
    private let mediaPrefetchSettingsButton = UIButton(type: .system)

    // Debug UI (only in Debug builds)
    #if DEBUG
    private let debugView = UIView()
    private let debugLabel = UILabel()
    private let debugButton = UIButton(type: .system)
    #endif

    // Scaled row heights based on font scale
    private var scaledRowHeight: CGFloat {
        let scale = FontScaleManager.shared.scaleFactor
        return max(44, round(44 * scale))
    }
    private var scaledSubtitleRowHeight: CGFloat {
        let scale = FontScaleManager.shared.scaleFactor
        return max(60, round(60 * scale))
    }
    private var scaledICloudRowHeight: CGFloat {
        let scale = FontScaleManager.shared.scaleFactor
        return max(64, round(64 * scale))
    }
    private var scaledNewPostRowHeight: CGFloat {
        let scale = FontScaleManager.shared.scaleFactor
        return max(70, round(70 * scale))
    }

    // Constants
    private let userDefaultsKey = "defaultBoard"
    private let faceIDEnabledKey = "channer_faceID_authentication_enabled"
    private let notificationsEnabledKey = "channer_notifications_enabled"
    private let offlineReadingEnabledKey = "channer_offline_reading_enabled"
    private let iCloudSyncEnabledKey = "channer_icloud_sync_enabled"
    private let launchWithStartupBoardKey = "channer_launch_with_startup_board"
    private let keyboardShortcutsEnabledKey = "keyboardShortcutsEnabled"
    private let boardsAutoRefreshIntervalKey = "channer_boards_auto_refresh_interval"
    private let threadsAutoRefreshIntervalKey = "channer_threads_auto_refresh_interval"
    private let newPostBehaviorKey = "channer_new_post_behavior"
    private let threadsDisplayModeKey = "channer_threads_display_mode"
    private let highQualityThumbnailsKey = "channer_high_quality_thumbnails_enabled"
    private let preloadVideosKey = "channer_preload_videos_enabled"
    private let defaultVideoMutedKey = MediaSettings.defaultMutedKey
    
    // MARK: - Initialization
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
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
        
        if UserDefaults.standard.object(forKey: iCloudSyncEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: iCloudSyncEnabledKey)
        }
        
        if UserDefaults.standard.object(forKey: highQualityThumbnailsKey) == nil {
            UserDefaults.standard.set(false, forKey: highQualityThumbnailsKey)
        }
        
        if UserDefaults.standard.object(forKey: preloadVideosKey) == nil {
            UserDefaults.standard.set(false, forKey: preloadVideosKey)
        }

        if UserDefaults.standard.object(forKey: defaultVideoMutedKey) == nil {
            UserDefaults.standard.set(true, forKey: defaultVideoMutedKey)
        }
        
        // Load cached boards from shared service, then fetch latest
        boardNames = BoardsService.shared.boardNames
        boardAbv = BoardsService.shared.boardAbv
        sortBoardsAlphabetically()
        setupUI()
        BoardsService.shared.fetchBoards { [weak self] in
            guard let self = self else { return }
            self.boardNames = BoardsService.shared.boardNames
            self.boardAbv = BoardsService.shared.boardAbv
            self.sortBoardsAlphabetically()
            self.updateSelectedBoardLabel()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePassStatusIndicator()
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

    // No local networking: boards now provided by BoardsService
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // Setup content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Selected Board View (Startup Board selector)
        selectedBoardView.backgroundColor = UIColor.secondarySystemGroupedBackground
        selectedBoardView.layer.cornerRadius = 10
        selectedBoardView.clipsToBounds = true
        selectedBoardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectedBoardView)

        // Selected Board Label
        selectedBoardLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        selectedBoardLabel.textAlignment = .left
        selectedBoardLabel.translatesAutoresizingMaskIntoConstraints = false
        updateSelectedBoardLabel()
        selectedBoardView.addSubview(selectedBoardLabel)
        
        // Select Board Button
        selectBoardButton.setTitle("Change", for: .normal)
        selectBoardButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        selectBoardButton.translatesAutoresizingMaskIntoConstraints = false
        selectBoardButton.addTarget(self, action: #selector(selectBoardButtonTapped), for: .touchUpInside)
        selectedBoardView.addSubview(selectBoardButton)
        
        // FaceID View
        faceIDView.backgroundColor = UIColor.secondarySystemGroupedBackground
        faceIDView.layer.cornerRadius = 10
        faceIDView.clipsToBounds = true
        faceIDView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(faceIDView)
        
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
        contentView.addSubview(notificationsView)
        
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
        contentView.addSubview(offlineReadingView)
        
        // Offline Reading Label
        offlineReadingLabel.text = "Enable Offline Reading Mode"
        offlineReadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        offlineReadingLabel.textAlignment = .left
        offlineReadingLabel.numberOfLines = 1
        offlineReadingLabel.adjustsFontSizeToFitWidth = true
        offlineReadingLabel.minimumScaleFactor = 0.8
        offlineReadingLabel.translatesAutoresizingMaskIntoConstraints = false
        offlineReadingView.addSubview(offlineReadingLabel)

        // Offline Reading Subtitle Label
        offlineReadingSubtitleLabel.text = "Caches favorites for offline access"
        offlineReadingSubtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        offlineReadingSubtitleLabel.textColor = .secondaryLabel
        offlineReadingSubtitleLabel.textAlignment = .left
        offlineReadingSubtitleLabel.numberOfLines = 1
        offlineReadingSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        offlineReadingView.addSubview(offlineReadingSubtitleLabel)
        
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
        
        // iCloud Sync View
        iCloudSyncView.backgroundColor = UIColor.secondarySystemGroupedBackground
        iCloudSyncView.layer.cornerRadius = 10
        iCloudSyncView.clipsToBounds = true
        iCloudSyncView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iCloudSyncView)
        
        // iCloud Sync Label
        iCloudSyncLabel.text = "Enable iCloud Sync"
        iCloudSyncLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        iCloudSyncLabel.textAlignment = .left
        iCloudSyncLabel.numberOfLines = 1
        iCloudSyncLabel.adjustsFontSizeToFitWidth = true
        iCloudSyncLabel.minimumScaleFactor = 0.8
        iCloudSyncLabel.translatesAutoresizingMaskIntoConstraints = false
        iCloudSyncView.addSubview(iCloudSyncLabel)
        
        // iCloud Sync Toggle
        let isICloudSyncEnabled = UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
        iCloudSyncToggle.isOn = isICloudSyncEnabled
        print("Initializing iCloud Sync toggle with value: \(isICloudSyncEnabled)")
        iCloudSyncToggle.translatesAutoresizingMaskIntoConstraints = false
        iCloudSyncToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        iCloudSyncToggle.addTarget(self, action: #selector(iCloudSyncToggleChanged), for: .valueChanged)
        iCloudSyncView.addSubview(iCloudSyncToggle)
        
        // iCloud Sync Status Label
        updateiCloudStatusLabel()
        iCloudSyncStatusLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        iCloudSyncStatusLabel.textColor = .secondaryLabel
        iCloudSyncStatusLabel.textAlignment = .left
        iCloudSyncStatusLabel.numberOfLines = 1
        iCloudSyncStatusLabel.adjustsFontSizeToFitWidth = true
        iCloudSyncStatusLabel.minimumScaleFactor = 0.8
        iCloudSyncStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        iCloudSyncView.addSubview(iCloudSyncStatusLabel)
        
        // Force Sync Button
        iCloudForceSync.setTitle("Sync Now", for: .normal)
        iCloudForceSync.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        iCloudForceSync.translatesAutoresizingMaskIntoConstraints = false
        iCloudForceSync.addTarget(self, action: #selector(forceiCloudSync), for: .touchUpInside)
        iCloudSyncView.addSubview(iCloudForceSync)
        
        // Setup iCloud sync observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudSyncStatusChanged),
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudSyncStatusChanged),
            name: ICloudSyncManager.iCloudSyncStatusChangedNotification,
            object: nil
        )
        
        // Launch With Startup Board View
        launchWithStartupBoardView.backgroundColor = UIColor.secondarySystemGroupedBackground
        launchWithStartupBoardView.layer.cornerRadius = 10
        launchWithStartupBoardView.clipsToBounds = true
        launchWithStartupBoardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(launchWithStartupBoardView)
        
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

        // Hidden Boards View
        hiddenBoardsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        hiddenBoardsView.layer.cornerRadius = 10
        hiddenBoardsView.clipsToBounds = true
        hiddenBoardsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hiddenBoardsView)

        // Hidden Boards Label
        hiddenBoardsLabel.text = "Hidden Boards"
        hiddenBoardsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        hiddenBoardsLabel.textAlignment = .left
        hiddenBoardsLabel.numberOfLines = 1
        hiddenBoardsLabel.adjustsFontSizeToFitWidth = true
        hiddenBoardsLabel.minimumScaleFactor = 0.8
        hiddenBoardsLabel.translatesAutoresizingMaskIntoConstraints = false
        hiddenBoardsView.addSubview(hiddenBoardsLabel)

        // Hidden Boards Count Label
        updateHiddenBoardsCountLabel()
        hiddenBoardsCountLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        hiddenBoardsCountLabel.textColor = .secondaryLabel
        hiddenBoardsCountLabel.textAlignment = .right
        hiddenBoardsCountLabel.translatesAutoresizingMaskIntoConstraints = false
        hiddenBoardsView.addSubview(hiddenBoardsCountLabel)

        // Hidden Boards Button
        hiddenBoardsButton.setTitle("Manage", for: .normal)
        hiddenBoardsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        hiddenBoardsButton.translatesAutoresizingMaskIntoConstraints = false
        hiddenBoardsButton.addTarget(self, action: #selector(hiddenBoardsButtonTapped), for: .touchUpInside)
        hiddenBoardsView.addSubview(hiddenBoardsButton)

        // Register for hidden boards changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hiddenBoardsDidChange),
            name: HiddenBoardsManager.hiddenBoardsChangedNotification,
            object: nil
        )

        // Theme Settings View
        themeSettingsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        themeSettingsView.layer.cornerRadius = 10
        themeSettingsView.clipsToBounds = true
        themeSettingsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(themeSettingsView)
        
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

        // Font Size View
        fontSizeView.backgroundColor = UIColor.secondarySystemGroupedBackground
        fontSizeView.layer.cornerRadius = 10
        fontSizeView.clipsToBounds = true
        fontSizeView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fontSizeView)

        // Font Size Label
        fontSizeLabel.text = "Font Size"
        fontSizeLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        fontSizeLabel.textAlignment = .left
        fontSizeLabel.numberOfLines = 1
        fontSizeLabel.adjustsFontSizeToFitWidth = true
        fontSizeLabel.minimumScaleFactor = 0.8
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        fontSizeView.addSubview(fontSizeLabel)

        // Font Size Value Label
        fontSizeValueLabel.text = "\(FontScaleManager.shared.scalePercent)%"
        fontSizeValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        fontSizeValueLabel.textAlignment = .center
        fontSizeValueLabel.translatesAutoresizingMaskIntoConstraints = false
        fontSizeView.addSubview(fontSizeValueLabel)

        // Font Size Stepper
        fontSizeStepper.minimumValue = Double(FontScaleManager.minimumPercent)
        fontSizeStepper.maximumValue = Double(FontScaleManager.maximumPercent)
        fontSizeStepper.stepValue = Double(FontScaleManager.stepPercent)
        fontSizeStepper.value = Double(FontScaleManager.shared.scalePercent)
        fontSizeStepper.wraps = false
        fontSizeStepper.translatesAutoresizingMaskIntoConstraints = false
        fontSizeStepper.addTarget(self, action: #selector(fontSizeStepperChanged), for: .valueChanged)
        fontSizeView.addSubview(fontSizeStepper)
        
        // Content Filtering View
        contentFilteringView.backgroundColor = UIColor.secondarySystemGroupedBackground
        contentFilteringView.layer.cornerRadius = 10
        contentFilteringView.clipsToBounds = true
        contentFilteringView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentFilteringView)
        
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

        // Watch Rules View
        watchRulesView.backgroundColor = UIColor.secondarySystemGroupedBackground
        watchRulesView.layer.cornerRadius = 10
        watchRulesView.clipsToBounds = true
        watchRulesView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(watchRulesView)

        // Watch Rules Label
        watchRulesLabel.text = "Watch Rules"
        watchRulesLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        watchRulesLabel.textAlignment = .left
        watchRulesLabel.numberOfLines = 1
        watchRulesLabel.adjustsFontSizeToFitWidth = true
        watchRulesLabel.minimumScaleFactor = 0.8
        watchRulesLabel.translatesAutoresizingMaskIntoConstraints = false
        watchRulesView.addSubview(watchRulesLabel)

        // Watch Rules Button
        watchRulesButton.setTitle("Manage", for: .normal)
        watchRulesButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        watchRulesButton.translatesAutoresizingMaskIntoConstraints = false
        watchRulesButton.addTarget(self, action: #selector(watchRulesButtonTapped), for: .touchUpInside)
        watchRulesView.addSubview(watchRulesButton)

        // Auto-refresh View
        autoRefreshView.backgroundColor = UIColor.secondarySystemGroupedBackground
        autoRefreshView.layer.cornerRadius = 10
        autoRefreshView.clipsToBounds = true
        autoRefreshView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(autoRefreshView)
        
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

        // Statistics View
        statisticsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        statisticsView.layer.cornerRadius = 10
        statisticsView.clipsToBounds = true
        statisticsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statisticsView)

        // Statistics Label
        statisticsLabel.text = "Statistics & Analytics"
        statisticsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        statisticsLabel.textAlignment = .left
        statisticsLabel.numberOfLines = 1
        statisticsLabel.adjustsFontSizeToFitWidth = true
        statisticsLabel.minimumScaleFactor = 0.8
        statisticsLabel.translatesAutoresizingMaskIntoConstraints = false
        statisticsView.addSubview(statisticsLabel)

        // Statistics Button
        statisticsButton.setTitle("View", for: .normal)
        statisticsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statisticsButton.translatesAutoresizingMaskIntoConstraints = false
        statisticsButton.addTarget(self, action: #selector(statisticsButtonTapped), for: .touchUpInside)
        statisticsView.addSubview(statisticsButton)

        // 4chan Pass Settings View
        passSettingsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        passSettingsView.layer.cornerRadius = 10
        passSettingsView.clipsToBounds = true
        passSettingsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(passSettingsView)

        // Pass Status Indicator (green/red dot)
        passStatusIndicator.layer.cornerRadius = 5
        passStatusIndicator.translatesAutoresizingMaskIntoConstraints = false
        updatePassStatusIndicator()
        passSettingsView.addSubview(passStatusIndicator)

        // Pass Settings Label
        passSettingsLabel.text = "4chan Pass"
        passSettingsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        passSettingsLabel.textAlignment = .left
        passSettingsLabel.numberOfLines = 1
        passSettingsLabel.adjustsFontSizeToFitWidth = true
        passSettingsLabel.minimumScaleFactor = 0.8
        passSettingsLabel.translatesAutoresizingMaskIntoConstraints = false
        passSettingsView.addSubview(passSettingsLabel)

        // Pass Settings Button
        passSettingsButton.setTitle("Configure", for: .normal)
        passSettingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        passSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        passSettingsButton.addTarget(self, action: #selector(passSettingsButtonTapped), for: .touchUpInside)
        passSettingsView.addSubview(passSettingsButton)

        // New Post Behavior View
        newPostBehaviorView.backgroundColor = UIColor.secondarySystemGroupedBackground
        newPostBehaviorView.layer.cornerRadius = 10
        newPostBehaviorView.clipsToBounds = true
        newPostBehaviorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(newPostBehaviorView)

        // New Post Behavior Label
        newPostBehaviorLabel.text = "When New Posts Arrive"
        newPostBehaviorLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        newPostBehaviorLabel.textAlignment = .left
        newPostBehaviorLabel.numberOfLines = 1
        newPostBehaviorLabel.adjustsFontSizeToFitWidth = true
        newPostBehaviorLabel.minimumScaleFactor = 0.8
        newPostBehaviorLabel.translatesAutoresizingMaskIntoConstraints = false
        newPostBehaviorView.addSubview(newPostBehaviorLabel)

        // New Post Behavior Segment Control
        let savedBehavior = UserDefaults.standard.integer(forKey: newPostBehaviorKey)
        newPostBehaviorSegment.selectedSegmentIndex = savedBehavior
        newPostBehaviorSegment.translatesAutoresizingMaskIntoConstraints = false
        newPostBehaviorSegment.addTarget(self, action: #selector(newPostBehaviorChanged), for: .valueChanged)
        // Make segment control smaller on narrow screens
        if UIScreen.main.bounds.width <= 375 {
            newPostBehaviorSegment.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 10)], for: .normal)
        } else {
            newPostBehaviorSegment.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12)], for: .normal)
        }
        newPostBehaviorView.addSubview(newPostBehaviorSegment)

        // Keyboard Shortcuts View (iPad only)
        if UIDevice.current.userInterfaceIdiom == .pad {
            keyboardShortcutsView.backgroundColor = UIColor.secondarySystemGroupedBackground
            keyboardShortcutsView.layer.cornerRadius = 10
            keyboardShortcutsView.clipsToBounds = true
            keyboardShortcutsView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(keyboardShortcutsView)
        }
        
        // Keyboard Shortcuts Label (iPad only)
        if UIDevice.current.userInterfaceIdiom == .pad {
            keyboardShortcutsLabel.text = "iPad Keyboard Shortcuts"
            keyboardShortcutsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            keyboardShortcutsLabel.textAlignment = .left
            keyboardShortcutsLabel.numberOfLines = 1
            keyboardShortcutsLabel.adjustsFontSizeToFitWidth = true
            keyboardShortcutsLabel.minimumScaleFactor = 0.8
            keyboardShortcutsLabel.translatesAutoresizingMaskIntoConstraints = false
            keyboardShortcutsView.addSubview(keyboardShortcutsLabel)
            
            // Keyboard Shortcuts Toggle
            let isKeyboardShortcutsEnabled = UserDefaults.standard.bool(forKey: keyboardShortcutsEnabledKey)
            keyboardShortcutsToggle.isOn = isKeyboardShortcutsEnabled
            keyboardShortcutsToggle.translatesAutoresizingMaskIntoConstraints = false
            keyboardShortcutsToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            keyboardShortcutsToggle.addTarget(self, action: #selector(keyboardShortcutsToggleChanged), for: .valueChanged)
            keyboardShortcutsView.addSubview(keyboardShortcutsToggle)
        }
        
        
        // Setup the Boards Display Mode view
        setupBoardsDisplayModeView()

        // Setup the Grid Item Size view
        setupGridItemSizeView()

        // Setup the Threads Display Mode view
        setupThreadsDisplayModeView()
        
        // Setup High Quality Thumbnails view
        setupHighQualityThumbnailsView()

        // Setup Thumbnail Size view
        setupThumbnailSizeView()

        // Setup Preload Videos view
        setupPreloadVideosView()

        // Setup Default Video Mute view
        setupDefaultVideoMutedView()

        // Setup Media Prefetch Settings view
        setupMediaPrefetchSettingsView()

        #if DEBUG
        // Setup Debug view (only in Debug builds)
        setupDebugView()
        #endif

        setupConstraints()
    }

    @objc private func faceIDToggleChanged(_ sender: UISwitch) {
        // If turning OFF FaceID and it was previously ON, require authentication
        let wasPreviouslyEnabled = UserDefaults.standard.bool(forKey: faceIDEnabledKey)
        
        if wasPreviouslyEnabled && !sender.isOn {
            // Revert the toggle state temporarily
            sender.isOn = true
            
            // Require authentication to turn off FaceID
            authenticateToChangeSetting { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful, allow the change
                        sender.isOn = false
                        UserDefaults.standard.set(false, forKey: self?.faceIDEnabledKey ?? "")
                        print("FaceID toggle changed to: false after authentication")
                    } else {
                        // Authentication failed, keep toggle on
                        sender.isOn = true
                        print("FaceID toggle change denied due to failed authentication")
                    }
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
        } else {
            // Turning ON FaceID or no change needed, proceed normally
            UserDefaults.standard.set(sender.isOn, forKey: faceIDEnabledKey)
            print("FaceID toggle changed to: \(sender.isOn)")
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func authenticateToChangeSetting(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if Face ID/Touch ID is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to disable Face ID/Touch ID requirement."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                completion(success)
            }
        } else {
            // Fall back to device passcode if biometrics not available
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Authenticate to disable Face ID/Touch ID requirement."
                
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                    completion(success)
                }
            } else {
                // No authentication method available
                completion(false)
            }
        }
    }
    
    @objc private func notificationsToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: notificationsEnabledKey)
        print("Notifications toggle changed to: \(sender.isOn)")
        
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

        // Update ThreadCacheManager's setting as well
        ThreadCacheManager.shared.setOfflineReadingEnabled(sender.isOn)

        print("Offline Reading toggle changed to: \(sender.isOn)")
        
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
        print("Launch with startup board toggle changed to: \(sender.isOn)")
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func iCloudSyncToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: iCloudSyncEnabledKey)
        print("iCloud Sync toggle changed to: \(sender.isOn)")
        
        // Update iCloud sync status immediately
        updateiCloudStatusLabel()
        iCloudForceSync.isEnabled = sender.isOn && ICloudSyncManager.shared.isICloudAvailable
        
        // If disabling, show a warning
        if !sender.isOn {
            let alert = UIAlertController(
                title: "Disable iCloud Sync?",
                message: "Your data will no longer sync across devices. Existing local data will remain.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                sender.isOn = true
                UserDefaults.standard.set(true, forKey: self.iCloudSyncEnabledKey)
            })
            alert.addAction(UIAlertAction(title: "Disable", style: .destructive) { _ in
                // Sync disabled, no action needed
            })
            present(alert, animated: true)
        }
        
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

    @objc private func fontSizeStepperChanged(_ sender: UIStepper) {
        let percent = Int(sender.value)
        fontSizeValueLabel.text = "\(percent)%"
        FontScaleManager.shared.setScalePercent(percent)

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @objc private func gridItemSizeSegmentChanged(_ sender: UISegmentedControl) {
        GridItemSizeManager.shared.setSizeIndex(sender.selectedSegmentIndex)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func passSettingsButtonTapped() {
        let passSettingsVC = PassSettingsViewController()
        navigationController?.pushViewController(passSettingsVC, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func hiddenBoardsButtonTapped() {
        let hiddenBoardsVC = HiddenBoardsViewController()
        navigationController?.pushViewController(hiddenBoardsVC, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func hiddenBoardsDidChange() {
        updateHiddenBoardsCountLabel()
    }

    private func updateHiddenBoardsCountLabel() {
        let count = HiddenBoardsManager.shared.hiddenBoardsCount
        if count == 0 {
            hiddenBoardsCountLabel.text = "None"
        } else {
            hiddenBoardsCountLabel.text = "\(count) hidden"
        }
    }

    private func updatePassStatusIndicator() {
        if PassAuthManager.shared.isAuthenticated {
            passStatusIndicator.backgroundColor = .systemGreen
        } else {
            passStatusIndicator.backgroundColor = .systemRed
        }
    }

    @objc private func contentFilteringButtonTapped() {
        // Navigate to ContentFilterViewController
        let contentFilterVC = ContentFilterViewController()
        navigationController?.pushViewController(contentFilterVC, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func watchRulesButtonTapped() {
        let watchRulesVC = WatchRulesViewController()
        navigationController?.pushViewController(watchRulesVC, animated: true)

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

    @objc private func statisticsButtonTapped() {
        let statisticsVC = StatisticsDashboardViewController()
        navigationController?.pushViewController(statisticsVC, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func keyboardShortcutsToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: keyboardShortcutsEnabledKey)
        // Toggle notification for keyboard shortcuts across the app
        NotificationCenter.default.post(name: NSNotification.Name("KeyboardShortcutsToggled"), object: nil, userInfo: ["enabled": sender.isOn])
        
        // Show confirmation alert
        let title = sender.isOn ? "Keyboard Shortcuts Enabled" : "Keyboard Shortcuts Disabled"
        let message = sender.isOn ? "Keyboard shortcuts are now available on iPad." : "Keyboard shortcuts have been disabled."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func highQualityThumbnailsToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: highQualityThumbnailsKey)

        // Show confirmation alert
        let title = sender.isOn ? "High-Quality Thumbnails Enabled" : "High-Quality Thumbnails Disabled"
        let message = sender.isOn ? "Thread thumbnails will now display in high quality. This may use more bandwidth." : "Thread thumbnails will now display in standard quality."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func thumbnailSizeSegmentChanged(_ sender: UISegmentedControl) {
        ThumbnailSizeManager.shared.setSizeIndex(sender.selectedSegmentIndex)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func preloadVideosToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: preloadVideosKey)

        // Show confirmation alert
        let title = sender.isOn ? "Video Preloading Enabled" : "Video Preloading Disabled"
        let message = sender.isOn ? "Videos in galleries will automatically load and play. This may use more data." : "Videos in galleries will not automatically load."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func defaultVideoMutedToggleChanged(_ sender: UISwitch) {
        MediaSettings.defaultMuted = sender.isOn

        let title = sender.isOn ? "Videos Start Muted" : "Videos Start Unmuted"
        let message = sender.isOn ? "New videos will start muted by default." : "New videos will start unmuted by default."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func mediaPrefetchSettingsButtonTapped() {
        let mediaPrefetchVC = MediaPrefetchSettingsViewController()
        navigationController?.pushViewController(mediaPrefetchVC, animated: true)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @objc private func newPostBehaviorChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: newPostBehaviorKey)

        // Show confirmation with description of selected behavior
        let titles = ["Jump Button", "Auto-scroll", "Do Nothing"]
        let descriptions = [
            "A floating button will appear to jump to new posts",
            "The thread will automatically scroll to new posts",
            "New posts will be loaded but scroll position preserved"
        ]

        let title = titles[sender.selectedSegmentIndex]
        let message = descriptions[sender.selectedSegmentIndex]

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

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
    
    private func setupHighQualityThumbnailsView() {
        // Set up the high quality thumbnails view
        highQualityThumbnailsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        highQualityThumbnailsView.layer.cornerRadius = 10
        highQualityThumbnailsView.clipsToBounds = true
        highQualityThumbnailsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the high quality thumbnails label
        highQualityThumbnailsLabel.text = "High-Quality Thread Thumbnails"
        highQualityThumbnailsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        highQualityThumbnailsLabel.textAlignment = .left
        highQualityThumbnailsLabel.numberOfLines = 1
        highQualityThumbnailsLabel.adjustsFontSizeToFitWidth = true
        highQualityThumbnailsLabel.minimumScaleFactor = 0.8
        highQualityThumbnailsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the high quality thumbnails toggle
        let isHighQualityThumbnailsEnabled = UserDefaults.standard.bool(forKey: highQualityThumbnailsKey)
        highQualityThumbnailsToggle.isOn = isHighQualityThumbnailsEnabled
        highQualityThumbnailsToggle.translatesAutoresizingMaskIntoConstraints = false
        highQualityThumbnailsToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        highQualityThumbnailsToggle.addTarget(self, action: #selector(highQualityThumbnailsToggleChanged), for: .valueChanged)
        
        // Add views to view hierarchy
        contentView.addSubview(highQualityThumbnailsView)
        highQualityThumbnailsView.addSubview(highQualityThumbnailsLabel)
        highQualityThumbnailsView.addSubview(highQualityThumbnailsToggle)
        
        // Add constraints for the views
        NSLayoutConstraint.activate([
            // High Quality Thumbnails View
            highQualityThumbnailsView.topAnchor.constraint(equalTo: threadsDisplayModeView.bottomAnchor, constant: 16),
            highQualityThumbnailsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            highQualityThumbnailsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            highQualityThumbnailsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            
            // High Quality Thumbnails Label
            highQualityThumbnailsLabel.centerYAnchor.constraint(equalTo: highQualityThumbnailsView.centerYAnchor),
            highQualityThumbnailsLabel.leadingAnchor.constraint(equalTo: highQualityThumbnailsView.leadingAnchor, constant: 20),
            highQualityThumbnailsLabel.trailingAnchor.constraint(lessThanOrEqualTo: highQualityThumbnailsToggle.leadingAnchor, constant: -15),
            
            // High Quality Thumbnails Toggle
            highQualityThumbnailsToggle.centerYAnchor.constraint(equalTo: highQualityThumbnailsView.centerYAnchor),
            highQualityThumbnailsToggle.trailingAnchor.constraint(equalTo: highQualityThumbnailsView.trailingAnchor, constant: -30),
        ])
    }
    
    private func setupThumbnailSizeView() {
        thumbnailSizeView.backgroundColor = UIColor.secondarySystemGroupedBackground
        thumbnailSizeView.layer.cornerRadius = 10
        thumbnailSizeView.clipsToBounds = true
        thumbnailSizeView.translatesAutoresizingMaskIntoConstraints = false

        thumbnailSizeLabel.text = "Thumbnail Size"
        thumbnailSizeLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        thumbnailSizeLabel.textAlignment = .left
        thumbnailSizeLabel.numberOfLines = 1
        thumbnailSizeLabel.adjustsFontSizeToFitWidth = true
        thumbnailSizeLabel.minimumScaleFactor = 0.8
        thumbnailSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        thumbnailSizeSegment.selectedSegmentIndex = ThumbnailSizeManager.shared.sizeIndex
        thumbnailSizeSegment.translatesAutoresizingMaskIntoConstraints = false
        thumbnailSizeSegment.addTarget(self, action: #selector(thumbnailSizeSegmentChanged), for: .valueChanged)

        let segFont: CGFloat = UIScreen.main.bounds.width <= 375 ? 10 : 12
        thumbnailSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: segFont, weight: .medium)],
            for: .normal)
        thumbnailSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: segFont, weight: .medium)],
            for: .selected)

        contentView.addSubview(thumbnailSizeView)
        thumbnailSizeView.addSubview(thumbnailSizeLabel)
        thumbnailSizeView.addSubview(thumbnailSizeSegment)

        NSLayoutConstraint.activate([
            thumbnailSizeView.topAnchor.constraint(equalTo: highQualityThumbnailsView.bottomAnchor, constant: 16),
            thumbnailSizeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailSizeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            thumbnailSizeView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

            thumbnailSizeLabel.centerYAnchor.constraint(equalTo: thumbnailSizeView.centerYAnchor),
            thumbnailSizeLabel.leadingAnchor.constraint(equalTo: thumbnailSizeView.leadingAnchor, constant: 20),
            thumbnailSizeLabel.trailingAnchor.constraint(lessThanOrEqualTo: thumbnailSizeSegment.leadingAnchor, constant: -15),

            thumbnailSizeSegment.centerYAnchor.constraint(equalTo: thumbnailSizeView.centerYAnchor),
            thumbnailSizeSegment.trailingAnchor.constraint(equalTo: thumbnailSizeView.trailingAnchor, constant: -20),
            thumbnailSizeSegment.widthAnchor.constraint(equalToConstant: 260),
        ])
    }

    private func setupPreloadVideosView() {
        // Set up the preload videos view
        preloadVideosView.backgroundColor = UIColor.secondarySystemGroupedBackground
        preloadVideosView.layer.cornerRadius = 10
        preloadVideosView.clipsToBounds = true
        preloadVideosView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the preload videos label
        preloadVideosLabel.text = "Preload Videos in Gallery"
        preloadVideosLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        preloadVideosLabel.textAlignment = .left
        preloadVideosLabel.numberOfLines = 1
        preloadVideosLabel.adjustsFontSizeToFitWidth = true
        preloadVideosLabel.minimumScaleFactor = 0.8
        preloadVideosLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the preload videos toggle
        let isPreloadVideosEnabled = UserDefaults.standard.bool(forKey: preloadVideosKey)
        preloadVideosToggle.isOn = isPreloadVideosEnabled
        preloadVideosToggle.translatesAutoresizingMaskIntoConstraints = false
        preloadVideosToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        preloadVideosToggle.addTarget(self, action: #selector(preloadVideosToggleChanged), for: .valueChanged)
        
        // Add views to view hierarchy
        contentView.addSubview(preloadVideosView)
        preloadVideosView.addSubview(preloadVideosLabel)
        preloadVideosView.addSubview(preloadVideosToggle)
        
        // Add constraints for the views
        NSLayoutConstraint.activate([
            // Preload Videos View
            preloadVideosView.topAnchor.constraint(equalTo: thumbnailSizeView.bottomAnchor, constant: 16),
            preloadVideosView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            preloadVideosView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            preloadVideosView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            
            // Preload Videos Label
            preloadVideosLabel.centerYAnchor.constraint(equalTo: preloadVideosView.centerYAnchor),
            preloadVideosLabel.leadingAnchor.constraint(equalTo: preloadVideosView.leadingAnchor, constant: 20),
            preloadVideosLabel.trailingAnchor.constraint(lessThanOrEqualTo: preloadVideosToggle.leadingAnchor, constant: -15),
            
            // Preload Videos Toggle
            preloadVideosToggle.centerYAnchor.constraint(equalTo: preloadVideosView.centerYAnchor),
            preloadVideosToggle.trailingAnchor.constraint(equalTo: preloadVideosView.trailingAnchor, constant: -30),
        ])
    }

    private func setupDefaultVideoMutedView() {
        defaultVideoMutedView.backgroundColor = UIColor.secondarySystemGroupedBackground
        defaultVideoMutedView.layer.cornerRadius = 10
        defaultVideoMutedView.clipsToBounds = true
        defaultVideoMutedView.translatesAutoresizingMaskIntoConstraints = false

        defaultVideoMutedLabel.text = "Videos Start Muted"
        defaultVideoMutedLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        defaultVideoMutedLabel.textAlignment = .left
        defaultVideoMutedLabel.numberOfLines = 1
        defaultVideoMutedLabel.adjustsFontSizeToFitWidth = true
        defaultVideoMutedLabel.minimumScaleFactor = 0.8
        defaultVideoMutedLabel.translatesAutoresizingMaskIntoConstraints = false

        let isDefaultMuted = MediaSettings.defaultMuted
        defaultVideoMutedToggle.isOn = isDefaultMuted
        defaultVideoMutedToggle.translatesAutoresizingMaskIntoConstraints = false
        defaultVideoMutedToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        defaultVideoMutedToggle.addTarget(self, action: #selector(defaultVideoMutedToggleChanged), for: .valueChanged)

        contentView.addSubview(defaultVideoMutedView)
        defaultVideoMutedView.addSubview(defaultVideoMutedLabel)
        defaultVideoMutedView.addSubview(defaultVideoMutedToggle)

        NSLayoutConstraint.activate([
            defaultVideoMutedView.topAnchor.constraint(equalTo: preloadVideosView.bottomAnchor, constant: 16),
            defaultVideoMutedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            defaultVideoMutedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            defaultVideoMutedView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

            defaultVideoMutedLabel.centerYAnchor.constraint(equalTo: defaultVideoMutedView.centerYAnchor),
            defaultVideoMutedLabel.leadingAnchor.constraint(equalTo: defaultVideoMutedView.leadingAnchor, constant: 20),
            defaultVideoMutedLabel.trailingAnchor.constraint(lessThanOrEqualTo: defaultVideoMutedToggle.leadingAnchor, constant: -15),

            defaultVideoMutedToggle.centerYAnchor.constraint(equalTo: defaultVideoMutedView.centerYAnchor),
            defaultVideoMutedToggle.trailingAnchor.constraint(equalTo: defaultVideoMutedView.trailingAnchor, constant: -30),
        ])
    }

    private func setupMediaPrefetchSettingsView() {
        mediaPrefetchSettingsView.backgroundColor = UIColor.secondarySystemGroupedBackground
        mediaPrefetchSettingsView.layer.cornerRadius = 10
        mediaPrefetchSettingsView.clipsToBounds = true
        mediaPrefetchSettingsView.translatesAutoresizingMaskIntoConstraints = false

        mediaPrefetchSettingsLabel.text = "Media Prefetching"
        mediaPrefetchSettingsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        mediaPrefetchSettingsLabel.textAlignment = .left
        mediaPrefetchSettingsLabel.numberOfLines = 1
        mediaPrefetchSettingsLabel.adjustsFontSizeToFitWidth = true
        mediaPrefetchSettingsLabel.minimumScaleFactor = 0.8
        mediaPrefetchSettingsLabel.translatesAutoresizingMaskIntoConstraints = false

        mediaPrefetchSettingsButton.setTitle("Configure", for: .normal)
        mediaPrefetchSettingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        mediaPrefetchSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        mediaPrefetchSettingsButton.addTarget(self, action: #selector(mediaPrefetchSettingsButtonTapped), for: .touchUpInside)

        contentView.addSubview(mediaPrefetchSettingsView)
        mediaPrefetchSettingsView.addSubview(mediaPrefetchSettingsLabel)
        mediaPrefetchSettingsView.addSubview(mediaPrefetchSettingsButton)

        NSLayoutConstraint.activate([
            mediaPrefetchSettingsView.topAnchor.constraint(equalTo: defaultVideoMutedView.bottomAnchor, constant: 16),
            mediaPrefetchSettingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mediaPrefetchSettingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mediaPrefetchSettingsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

            mediaPrefetchSettingsLabel.centerYAnchor.constraint(equalTo: mediaPrefetchSettingsView.centerYAnchor),
            mediaPrefetchSettingsLabel.leadingAnchor.constraint(equalTo: mediaPrefetchSettingsView.leadingAnchor, constant: 20),
            mediaPrefetchSettingsLabel.trailingAnchor.constraint(lessThanOrEqualTo: mediaPrefetchSettingsButton.leadingAnchor, constant: -15),

            mediaPrefetchSettingsButton.centerYAnchor.constraint(equalTo: mediaPrefetchSettingsView.centerYAnchor),
            mediaPrefetchSettingsButton.trailingAnchor.constraint(equalTo: mediaPrefetchSettingsView.trailingAnchor, constant: -20),
        ])
    }

    #if DEBUG
    private func setupDebugView() {
        // Set up the debug view
        debugView.backgroundColor = UIColor.secondarySystemGroupedBackground
        debugView.layer.cornerRadius = 10
        debugView.clipsToBounds = true
        debugView.translatesAutoresizingMaskIntoConstraints = false

        // Set up the debug label
        debugLabel.text = "Debug Tools"
        debugLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        debugLabel.textAlignment = .left
        debugLabel.numberOfLines = 1
        debugLabel.translatesAutoresizingMaskIntoConstraints = false

        // Set up the debug button
        debugButton.setTitle("Open", for: .normal)
        debugButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        debugButton.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)

        // Add views to view hierarchy
        contentView.addSubview(debugView)
        debugView.addSubview(debugLabel)
        debugView.addSubview(debugButton)
    }

    @objc private func debugButtonTapped() {
        let debugVC = DebugViewController()
        navigationController?.pushViewController(debugVC, animated: true)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    #endif

    private func setupBoardsDisplayModeView() {
        // Create the boards display mode view
        self.boardsDisplayModeView = {
            let view = UIView()
            view.backgroundColor = UIColor.secondarySystemGroupedBackground
            view.layer.cornerRadius = 10
            view.clipsToBounds = true
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        // Create the boards display mode label
        self.boardsDisplayModeLabel = {
            let label = UILabel()
            label.text = "Boards Display Mode"
            label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            label.textAlignment = .left
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        // Create the boards display mode segment control
        self.boardsDisplayModeSegment = {
            let segment = UISegmentedControl(items: ["Grid", "List"])
            // Set default value if not already set
            if UserDefaults.standard.object(forKey: "channer_boards_display_mode") == nil {
                UserDefaults.standard.set(0, forKey: "channer_boards_display_mode")
            }
            let displayMode = UserDefaults.standard.integer(forKey: "channer_boards_display_mode")
            segment.selectedSegmentIndex = displayMode
            segment.translatesAutoresizingMaskIntoConstraints = false
            segment.addTarget(self, action: #selector(boardsDisplayModeChanged), for: .valueChanged)
            return segment
        }()
        
        // Add views to view hierarchy
        contentView.addSubview(boardsDisplayModeView)
        boardsDisplayModeView.addSubview(boardsDisplayModeLabel)
        boardsDisplayModeView.addSubview(boardsDisplayModeSegment)
        
        // Add constraints for the views
        NSLayoutConstraint.activate([
            // Boards Display Mode View
            boardsDisplayModeView.topAnchor.constraint(equalTo: newPostBehaviorView.bottomAnchor, constant: 16),
            boardsDisplayModeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            boardsDisplayModeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            boardsDisplayModeView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            
            // Boards Display Mode Label
            boardsDisplayModeLabel.centerYAnchor.constraint(equalTo: boardsDisplayModeView.centerYAnchor),
            boardsDisplayModeLabel.leadingAnchor.constraint(equalTo: boardsDisplayModeView.leadingAnchor, constant: 20),
            boardsDisplayModeLabel.trailingAnchor.constraint(lessThanOrEqualTo: boardsDisplayModeSegment.leadingAnchor, constant: -15),
            
            // Boards Display Mode Segment
            boardsDisplayModeSegment.centerYAnchor.constraint(equalTo: boardsDisplayModeView.centerYAnchor),
            boardsDisplayModeSegment.trailingAnchor.constraint(equalTo: boardsDisplayModeView.trailingAnchor, constant: -20),
            boardsDisplayModeSegment.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func setupGridItemSizeView() {
        gridItemSizeView.backgroundColor = UIColor.secondarySystemGroupedBackground
        gridItemSizeView.layer.cornerRadius = 10
        gridItemSizeView.clipsToBounds = true
        gridItemSizeView.translatesAutoresizingMaskIntoConstraints = false

        gridItemSizeLabel.text = "Catalog Grid Size"
        gridItemSizeLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        gridItemSizeLabel.textAlignment = .left
        gridItemSizeLabel.numberOfLines = 1
        gridItemSizeLabel.adjustsFontSizeToFitWidth = true
        gridItemSizeLabel.minimumScaleFactor = 0.8
        gridItemSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        gridItemSizeSegment.selectedSegmentIndex = GridItemSizeManager.shared.sizeIndex
        gridItemSizeSegment.translatesAutoresizingMaskIntoConstraints = false
        gridItemSizeSegment.addTarget(self, action: #selector(gridItemSizeSegmentChanged), for: .valueChanged)

        let gridItemSizeFont: CGFloat = UIScreen.main.bounds.width <= 375 ? 10 : 12
        gridItemSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: gridItemSizeFont, weight: .medium)],
            for: .normal
        )
        gridItemSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: gridItemSizeFont, weight: .medium)],
            for: .selected
        )

        contentView.addSubview(gridItemSizeView)
        gridItemSizeView.addSubview(gridItemSizeLabel)
        gridItemSizeView.addSubview(gridItemSizeSegment)

        gridItemSizeHeightConstraint = gridItemSizeView.heightAnchor.constraint(equalToConstant: scaledRowHeight)

        NSLayoutConstraint.activate([
            gridItemSizeView.topAnchor.constraint(equalTo: boardsDisplayModeView.bottomAnchor, constant: 16),
            gridItemSizeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            gridItemSizeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            gridItemSizeHeightConstraint,

            gridItemSizeLabel.centerYAnchor.constraint(equalTo: gridItemSizeView.centerYAnchor),
            gridItemSizeLabel.leadingAnchor.constraint(equalTo: gridItemSizeView.leadingAnchor, constant: 20),
            gridItemSizeLabel.trailingAnchor.constraint(lessThanOrEqualTo: gridItemSizeSegment.leadingAnchor, constant: -15),

            gridItemSizeSegment.centerYAnchor.constraint(equalTo: gridItemSizeView.centerYAnchor),
            gridItemSizeSegment.trailingAnchor.constraint(equalTo: gridItemSizeView.trailingAnchor, constant: -20),
            gridItemSizeSegment.widthAnchor.constraint(equalToConstant: 220)
        ])

        let isCatalog = UserDefaults.standard.integer(forKey: threadsDisplayModeKey) == ThreadDisplayMode.catalog.rawValue
        updateGridItemSizeVisibility(isVisible: isCatalog)
    }

    private func setupThreadsDisplayModeView() {
        threadsDisplayModeView = {
            let view = UIView()
            view.backgroundColor = UIColor.secondarySystemGroupedBackground
            view.layer.cornerRadius = 10
            view.clipsToBounds = true
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        threadsDisplayModeLabel = {
            let label = UILabel()
            label.text = "Threads Display Mode"
            label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            label.textAlignment = .left
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()

        threadsDisplayModeSegment = {
            let segment = UISegmentedControl(items: ["List", "Catalog"])
            if UserDefaults.standard.object(forKey: threadsDisplayModeKey) == nil {
                UserDefaults.standard.set(ThreadDisplayMode.list.rawValue, forKey: threadsDisplayModeKey)
            }
            let displayMode = UserDefaults.standard.integer(forKey: threadsDisplayModeKey)
            segment.selectedSegmentIndex = displayMode
            segment.translatesAutoresizingMaskIntoConstraints = false
            segment.addTarget(self, action: #selector(threadsDisplayModeChanged), for: .valueChanged)
            return segment
        }()

        contentView.addSubview(threadsDisplayModeView)
        threadsDisplayModeView.addSubview(threadsDisplayModeLabel)
        threadsDisplayModeView.addSubview(threadsDisplayModeSegment)

        NSLayoutConstraint.activate([
            threadsDisplayModeView.topAnchor.constraint(equalTo: gridItemSizeView.bottomAnchor, constant: 16),
            threadsDisplayModeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            threadsDisplayModeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            threadsDisplayModeView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

            threadsDisplayModeLabel.centerYAnchor.constraint(equalTo: threadsDisplayModeView.centerYAnchor),
            threadsDisplayModeLabel.leadingAnchor.constraint(equalTo: threadsDisplayModeView.leadingAnchor, constant: 20),
            threadsDisplayModeLabel.trailingAnchor.constraint(lessThanOrEqualTo: threadsDisplayModeSegment.leadingAnchor, constant: -15),

            threadsDisplayModeSegment.centerYAnchor.constraint(equalTo: threadsDisplayModeView.centerYAnchor),
            threadsDisplayModeSegment.trailingAnchor.constraint(equalTo: threadsDisplayModeView.trailingAnchor, constant: -20),
            threadsDisplayModeSegment.widthAnchor.constraint(equalToConstant: 140)
        ])
    }
    
    @objc private func boardsDisplayModeChanged(_ sender: UISegmentedControl) {
        // Store the user's preference
        let boardsDisplayModeKey = "channer_boards_display_mode"

        print("DEBUG settings: boardsDisplayModeChanged called")
        print("DEBUG settings: Previous value = \(UserDefaults.standard.integer(forKey: boardsDisplayModeKey))")
        print("DEBUG settings: New value = \(sender.selectedSegmentIndex)")

        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: boardsDisplayModeKey)

        // Verify the save
        let savedValue = UserDefaults.standard.integer(forKey: boardsDisplayModeKey)
        print("DEBUG settings: Value after save = \(savedValue)")
        print("DEBUG settings: Save successful = \(savedValue == sender.selectedSegmentIndex)")

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Determine the display mode name
        let modeName = sender.selectedSegmentIndex == 0 ? "Grid" : "List"

        // Show confirmation message
        let alert = UIAlertController(
            title: "Display Mode Applied",
            message: "\(modeName) mode has been applied. The change will take effect when you return to the boards screen.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        present(alert, animated: true)
    }

    @objc private func threadsDisplayModeChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: threadsDisplayModeKey)

        updateGridItemSizeVisibility(isVisible: sender.selectedSegmentIndex == ThreadDisplayMode.catalog.rawValue)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let modeName = sender.selectedSegmentIndex == ThreadDisplayMode.catalog.rawValue ? "Catalog" : "List"
        let alert = UIAlertController(
            title: "Threads Display Mode Applied",
            message: "\(modeName) mode will be used when you return to a board.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func updateGridItemSizeVisibility(isVisible: Bool) {
        gridItemSizeView.isHidden = !isVisible
        gridItemSizeHeightConstraint.constant = isVisible ? scaledRowHeight : 0
        view.layoutIfNeeded()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Selected Board View (Startup Board selector)
            selectedBoardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            selectedBoardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            selectedBoardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            selectedBoardView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            selectedBoardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Selected Board Label
            selectedBoardLabel.centerYAnchor.constraint(equalTo: selectedBoardView.centerYAnchor),
            selectedBoardLabel.leadingAnchor.constraint(equalTo: selectedBoardView.leadingAnchor, constant: 20),
            selectedBoardLabel.trailingAnchor.constraint(lessThanOrEqualTo: selectBoardButton.leadingAnchor, constant: -15),

            // Select Board Button
            selectBoardButton.centerYAnchor.constraint(equalTo: selectedBoardView.centerYAnchor),
            selectBoardButton.trailingAnchor.constraint(equalTo: selectedBoardView.trailingAnchor, constant: -20),

            // Launch With Startup Board View
            launchWithStartupBoardView.topAnchor.constraint(equalTo: selectedBoardView.bottomAnchor, constant: 16),
            launchWithStartupBoardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            launchWithStartupBoardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            launchWithStartupBoardView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            launchWithStartupBoardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Launch With Startup Board Label
            launchWithStartupBoardLabel.centerYAnchor.constraint(equalTo: launchWithStartupBoardView.centerYAnchor),
            launchWithStartupBoardLabel.leadingAnchor.constraint(equalTo: launchWithStartupBoardView.leadingAnchor, constant: 20),
            launchWithStartupBoardLabel.trailingAnchor.constraint(lessThanOrEqualTo: launchWithStartupBoardToggle.leadingAnchor, constant: -15),

            // Launch With Startup Board Toggle
            launchWithStartupBoardToggle.centerYAnchor.constraint(equalTo: launchWithStartupBoardView.centerYAnchor),
            launchWithStartupBoardToggle.trailingAnchor.constraint(equalTo: launchWithStartupBoardView.trailingAnchor, constant: -30),

            // Hidden Boards View
            hiddenBoardsView.topAnchor.constraint(equalTo: launchWithStartupBoardView.bottomAnchor, constant: 16),
            hiddenBoardsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hiddenBoardsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            hiddenBoardsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            hiddenBoardsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Hidden Boards Label
            hiddenBoardsLabel.centerYAnchor.constraint(equalTo: hiddenBoardsView.centerYAnchor),
            hiddenBoardsLabel.leadingAnchor.constraint(equalTo: hiddenBoardsView.leadingAnchor, constant: 20),

            // Hidden Boards Count Label
            hiddenBoardsCountLabel.centerYAnchor.constraint(equalTo: hiddenBoardsView.centerYAnchor),
            hiddenBoardsCountLabel.trailingAnchor.constraint(equalTo: hiddenBoardsButton.leadingAnchor, constant: -10),

            // Hidden Boards Button
            hiddenBoardsButton.centerYAnchor.constraint(equalTo: hiddenBoardsView.centerYAnchor),
            hiddenBoardsButton.trailingAnchor.constraint(equalTo: hiddenBoardsView.trailingAnchor, constant: -20),

            // FaceID View
            faceIDView.topAnchor.constraint(equalTo: hiddenBoardsView.bottomAnchor, constant: 16),
            faceIDView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            faceIDView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            faceIDView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
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
            notificationsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notificationsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notificationsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
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
            offlineReadingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            offlineReadingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            offlineReadingView.heightAnchor.constraint(equalToConstant: scaledSubtitleRowHeight),
            offlineReadingView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Offline Reading Label
            offlineReadingLabel.topAnchor.constraint(equalTo: offlineReadingView.topAnchor, constant: 10),
            offlineReadingLabel.leadingAnchor.constraint(equalTo: offlineReadingView.leadingAnchor, constant: 20),
            offlineReadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: offlineReadingToggle.leadingAnchor, constant: -15),

            // Offline Reading Subtitle Label
            offlineReadingSubtitleLabel.topAnchor.constraint(equalTo: offlineReadingLabel.bottomAnchor, constant: 2),
            offlineReadingSubtitleLabel.leadingAnchor.constraint(equalTo: offlineReadingView.leadingAnchor, constant: 20),
            offlineReadingSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: offlineReadingToggle.leadingAnchor, constant: -15),

            // Offline Reading Toggle
            offlineReadingToggle.centerYAnchor.constraint(equalTo: offlineReadingView.centerYAnchor),
            offlineReadingToggle.trailingAnchor.constraint(equalTo: offlineReadingView.trailingAnchor, constant: -30),
            
            // iCloud Sync View
            iCloudSyncView.topAnchor.constraint(equalTo: offlineReadingView.bottomAnchor, constant: 16),
            iCloudSyncView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iCloudSyncView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            iCloudSyncView.heightAnchor.constraint(equalToConstant: scaledICloudRowHeight),
            iCloudSyncView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // iCloud Sync Label
            iCloudSyncLabel.topAnchor.constraint(equalTo: iCloudSyncView.topAnchor, constant: 10),
            iCloudSyncLabel.leadingAnchor.constraint(equalTo: iCloudSyncView.leadingAnchor, constant: 20),
            iCloudSyncLabel.trailingAnchor.constraint(lessThanOrEqualTo: iCloudSyncToggle.leadingAnchor, constant: -15),
            
            // iCloud Sync Toggle
            iCloudSyncToggle.centerYAnchor.constraint(equalTo: iCloudSyncLabel.centerYAnchor),
            iCloudSyncToggle.trailingAnchor.constraint(equalTo: iCloudSyncView.trailingAnchor, constant: -30),
            
            // iCloud Sync Status Label
            iCloudSyncStatusLabel.topAnchor.constraint(equalTo: iCloudSyncLabel.bottomAnchor, constant: 4),
            iCloudSyncStatusLabel.leadingAnchor.constraint(equalTo: iCloudSyncView.leadingAnchor, constant: 20),
            iCloudSyncStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: iCloudForceSync.leadingAnchor, constant: -10),
            
            // Force Sync Button
            iCloudForceSync.centerYAnchor.constraint(equalTo: iCloudSyncStatusLabel.centerYAnchor),
            iCloudForceSync.trailingAnchor.constraint(equalTo: iCloudSyncView.trailingAnchor, constant: -30),

            // Theme Settings View
            themeSettingsView.topAnchor.constraint(equalTo: iCloudSyncView.bottomAnchor, constant: 16),
            themeSettingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            themeSettingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            themeSettingsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            themeSettingsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Theme Settings Label
            themeSettingsLabel.centerYAnchor.constraint(equalTo: themeSettingsView.centerYAnchor),
            themeSettingsLabel.leadingAnchor.constraint(equalTo: themeSettingsView.leadingAnchor, constant: 20),
            themeSettingsLabel.trailingAnchor.constraint(lessThanOrEqualTo: themeSettingsButton.leadingAnchor, constant: -15),
            
            // Theme Settings Button
            themeSettingsButton.centerYAnchor.constraint(equalTo: themeSettingsView.centerYAnchor),
            themeSettingsButton.trailingAnchor.constraint(equalTo: themeSettingsView.trailingAnchor, constant: -20),

            // Font Size View
            fontSizeView.topAnchor.constraint(equalTo: themeSettingsView.bottomAnchor, constant: 16),
            fontSizeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fontSizeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            fontSizeView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            fontSizeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Font Size Label
            fontSizeLabel.centerYAnchor.constraint(equalTo: fontSizeView.centerYAnchor),
            fontSizeLabel.leadingAnchor.constraint(equalTo: fontSizeView.leadingAnchor, constant: 20),
            fontSizeLabel.trailingAnchor.constraint(lessThanOrEqualTo: fontSizeValueLabel.leadingAnchor, constant: -10),

            // Font Size Value Label
            fontSizeValueLabel.centerYAnchor.constraint(equalTo: fontSizeView.centerYAnchor),
            fontSizeValueLabel.trailingAnchor.constraint(equalTo: fontSizeStepper.leadingAnchor, constant: -10),
            fontSizeValueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

            // Font Size Stepper
            fontSizeStepper.centerYAnchor.constraint(equalTo: fontSizeView.centerYAnchor),
            fontSizeStepper.trailingAnchor.constraint(equalTo: fontSizeView.trailingAnchor, constant: -20),
            
            // Content Filtering View
            contentFilteringView.topAnchor.constraint(equalTo: fontSizeView.bottomAnchor, constant: 16),
            contentFilteringView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentFilteringView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentFilteringView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            contentFilteringView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Content Filtering Label
            contentFilteringLabel.centerYAnchor.constraint(equalTo: contentFilteringView.centerYAnchor),
            contentFilteringLabel.leadingAnchor.constraint(equalTo: contentFilteringView.leadingAnchor, constant: 20),
            contentFilteringLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentFilteringButton.leadingAnchor, constant: -15),
            
            // Content Filtering Button
            contentFilteringButton.centerYAnchor.constraint(equalTo: contentFilteringView.centerYAnchor),
            contentFilteringButton.trailingAnchor.constraint(equalTo: contentFilteringView.trailingAnchor, constant: -20),

            // Watch Rules View
            watchRulesView.topAnchor.constraint(equalTo: contentFilteringView.bottomAnchor, constant: 16),
            watchRulesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            watchRulesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            watchRulesView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            watchRulesView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Watch Rules Label
            watchRulesLabel.centerYAnchor.constraint(equalTo: watchRulesView.centerYAnchor),
            watchRulesLabel.leadingAnchor.constraint(equalTo: watchRulesView.leadingAnchor, constant: 20),
            watchRulesLabel.trailingAnchor.constraint(lessThanOrEqualTo: watchRulesButton.leadingAnchor, constant: -15),

            // Watch Rules Button
            watchRulesButton.centerYAnchor.constraint(equalTo: watchRulesView.centerYAnchor),
            watchRulesButton.trailingAnchor.constraint(equalTo: watchRulesView.trailingAnchor, constant: -20),

            // Auto-refresh View
            autoRefreshView.topAnchor.constraint(equalTo: watchRulesView.bottomAnchor, constant: 16),
            autoRefreshView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            autoRefreshView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            autoRefreshView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            autoRefreshView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            
            // Auto-refresh Label
            autoRefreshLabel.centerYAnchor.constraint(equalTo: autoRefreshView.centerYAnchor),
            autoRefreshLabel.leadingAnchor.constraint(equalTo: autoRefreshView.leadingAnchor, constant: 20),
            autoRefreshLabel.trailingAnchor.constraint(lessThanOrEqualTo: autoRefreshButton.leadingAnchor, constant: -15),

            // Auto-refresh Button
            autoRefreshButton.centerYAnchor.constraint(equalTo: autoRefreshView.centerYAnchor),
            autoRefreshButton.trailingAnchor.constraint(equalTo: autoRefreshView.trailingAnchor, constant: -20),

            // Statistics View
            statisticsView.topAnchor.constraint(equalTo: autoRefreshView.bottomAnchor, constant: 16),
            statisticsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statisticsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statisticsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            statisticsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Statistics Label
            statisticsLabel.centerYAnchor.constraint(equalTo: statisticsView.centerYAnchor),
            statisticsLabel.leadingAnchor.constraint(equalTo: statisticsView.leadingAnchor, constant: 20),
            statisticsLabel.trailingAnchor.constraint(lessThanOrEqualTo: statisticsButton.leadingAnchor, constant: -15),

            // Statistics Button
            statisticsButton.centerYAnchor.constraint(equalTo: statisticsView.centerYAnchor),
            statisticsButton.trailingAnchor.constraint(equalTo: statisticsView.trailingAnchor, constant: -20),

            // Pass Settings View
            passSettingsView.topAnchor.constraint(equalTo: statisticsView.bottomAnchor, constant: 16),
            passSettingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            passSettingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            passSettingsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
            passSettingsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // Pass Status Indicator
            passStatusIndicator.centerYAnchor.constraint(equalTo: passSettingsView.centerYAnchor),
            passStatusIndicator.leadingAnchor.constraint(equalTo: passSettingsView.leadingAnchor, constant: 16),
            passStatusIndicator.widthAnchor.constraint(equalToConstant: 10),
            passStatusIndicator.heightAnchor.constraint(equalToConstant: 10),

            // Pass Settings Label
            passSettingsLabel.centerYAnchor.constraint(equalTo: passSettingsView.centerYAnchor),
            passSettingsLabel.leadingAnchor.constraint(equalTo: passStatusIndicator.trailingAnchor, constant: 10),
            passSettingsLabel.trailingAnchor.constraint(lessThanOrEqualTo: passSettingsButton.leadingAnchor, constant: -15),

            // Pass Settings Button
            passSettingsButton.centerYAnchor.constraint(equalTo: passSettingsView.centerYAnchor),
            passSettingsButton.trailingAnchor.constraint(equalTo: passSettingsView.trailingAnchor, constant: -20),

            // New Post Behavior View
            newPostBehaviorView.topAnchor.constraint(equalTo: passSettingsView.bottomAnchor, constant: 16),
            newPostBehaviorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            newPostBehaviorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            newPostBehaviorView.heightAnchor.constraint(equalToConstant: scaledNewPostRowHeight),
            newPostBehaviorView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

            // New Post Behavior Label
            newPostBehaviorLabel.topAnchor.constraint(equalTo: newPostBehaviorView.topAnchor, constant: 10),
            newPostBehaviorLabel.leadingAnchor.constraint(equalTo: newPostBehaviorView.leadingAnchor, constant: 20),
            newPostBehaviorLabel.trailingAnchor.constraint(equalTo: newPostBehaviorView.trailingAnchor, constant: -20),

            // New Post Behavior Segment Control
            newPostBehaviorSegment.topAnchor.constraint(equalTo: newPostBehaviorLabel.bottomAnchor, constant: 8),
            newPostBehaviorSegment.leadingAnchor.constraint(equalTo: newPostBehaviorView.leadingAnchor, constant: 16),
            newPostBehaviorSegment.trailingAnchor.constraint(equalTo: newPostBehaviorView.trailingAnchor, constant: -16),

        ])
        
        // iPad-only constraints for keyboard shortcuts
        if UIDevice.current.userInterfaceIdiom == .pad {
            NSLayoutConstraint.activate([
                // Keyboard Shortcuts View
                keyboardShortcutsView.topAnchor.constraint(equalTo: mediaPrefetchSettingsView.bottomAnchor, constant: 16),
                keyboardShortcutsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                keyboardShortcutsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                keyboardShortcutsView.heightAnchor.constraint(equalToConstant: scaledRowHeight),
                keyboardShortcutsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),

                // Keyboard Shortcuts Label
                keyboardShortcutsLabel.centerYAnchor.constraint(equalTo: keyboardShortcutsView.centerYAnchor),
                keyboardShortcutsLabel.leadingAnchor.constraint(equalTo: keyboardShortcutsView.leadingAnchor, constant: 20),
                keyboardShortcutsLabel.trailingAnchor.constraint(lessThanOrEqualTo: keyboardShortcutsToggle.leadingAnchor, constant: -15),

                // Keyboard Shortcuts Toggle
                keyboardShortcutsToggle.centerYAnchor.constraint(equalTo: keyboardShortcutsView.centerYAnchor),
                keyboardShortcutsToggle.trailingAnchor.constraint(equalTo: keyboardShortcutsView.trailingAnchor, constant: -20),
            ])

            #if DEBUG
            // Debug View (after keyboard shortcuts on iPad)
            NSLayoutConstraint.activate([
                debugView.topAnchor.constraint(equalTo: keyboardShortcutsView.bottomAnchor, constant: 16),
                debugView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                debugView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                debugView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

                debugLabel.centerYAnchor.constraint(equalTo: debugView.centerYAnchor),
                debugLabel.leadingAnchor.constraint(equalTo: debugView.leadingAnchor, constant: 20),

                debugButton.centerYAnchor.constraint(equalTo: debugView.centerYAnchor),
                debugButton.trailingAnchor.constraint(equalTo: debugView.trailingAnchor, constant: -20),

                // Bottom constraint for scroll content size
                debugView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            ])
            #else
            // Bottom constraint for scroll content size (Release build)
            NSLayoutConstraint.activate([
                keyboardShortcutsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            ])
            #endif
        } else {
            #if DEBUG
            // For iPhone, debug view goes after preload videos view
            NSLayoutConstraint.activate([
                // Debug View
                debugView.topAnchor.constraint(equalTo: mediaPrefetchSettingsView.bottomAnchor, constant: 16),
                debugView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                debugView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                debugView.heightAnchor.constraint(equalToConstant: scaledRowHeight),

                debugLabel.centerYAnchor.constraint(equalTo: debugView.centerYAnchor),
                debugLabel.leadingAnchor.constraint(equalTo: debugView.leadingAnchor, constant: 20),

                debugButton.centerYAnchor.constraint(equalTo: debugView.centerYAnchor),
                debugButton.trailingAnchor.constraint(equalTo: debugView.trailingAnchor, constant: -20),

                // Bottom constraint for scroll content size
                debugView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            ])
            #else
            // Bottom constraint for scroll content size (Release build)
            NSLayoutConstraint.activate([
                mediaPrefetchSettingsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            ])
            #endif
        }
    }
    
    // MARK: - Helper Methods
    private func updateSelectedBoardLabel() {
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey),
           let index = boardAbv.firstIndex(of: savedDefault) {
            selectedBoardLabel.text = "Startup Board: /\(savedDefault)/ - \(boardNames[index])"
        } else {
            selectedBoardLabel.text = "Startup Board: None Selected"
        }
    }
    
    @objc private func selectBoardButtonTapped() {
        // Create a custom board selector view controller
        let boardSelectorVC = BoardSelectorViewController()
        boardSelectorVC.boardNames = self.boardNames
        boardSelectorVC.boardAbv = self.boardAbv
        boardSelectorVC.currentSelection = UserDefaults.standard.string(forKey: userDefaultsKey)
        
        boardSelectorVC.onBoardSelected = { [weak self] selectedBoardCode in
            // Save the selection
            if let selectedBoardCode = selectedBoardCode {
                UserDefaults.standard.set(selectedBoardCode, forKey: self?.userDefaultsKey ?? "")
            } else {
                UserDefaults.standard.removeObject(forKey: self?.userDefaultsKey ?? "")
            }
            self?.updateSelectedBoardLabel()
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Flash the selected board view to indicate change
            UIView.animate(withDuration: 0.2, animations: {
                self?.selectedBoardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            }) { _ in
                UIView.animate(withDuration: 0.3) {
                    self?.selectedBoardView.backgroundColor = UIColor.systemGray5
                }
            }
        }
        
        let navController = UINavigationController(rootViewController: boardSelectorVC)
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(navController, animated: true)
    }
    
    
    // MARK: - iCloud Sync Methods
    @objc private func forceiCloudSync() {
        guard UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey) else {
            let alert = UIAlertController(
                title: "iCloud Sync Disabled",
                message: "Please enable iCloud sync before attempting to sync.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Show loading indicator
        iCloudForceSync.isEnabled = false
        iCloudSyncStatusLabel.text = "Syncing..."
        iCloudSyncStatusLabel.textColor = .secondaryLabel
        
        // Trigger sync
        ICloudSyncManager.shared.forceSync()
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func iCloudSyncStatusChanged() {
        updateiCloudStatusLabel()
        let isEnabled = UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
        iCloudForceSync.isEnabled = isEnabled && ICloudSyncManager.shared.isICloudAvailable
    }
    
    private func updateiCloudStatusLabel() {
        let isEnabled = UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
        
        if !isEnabled {
            iCloudSyncStatusLabel.text = "Disabled"
            iCloudSyncStatusLabel.textColor = .systemGray
            iCloudForceSync.isEnabled = false
        } else if ICloudSyncManager.shared.isICloudAvailable {
            let syncStatus = ICloudSyncManager.shared.syncStatus
            iCloudSyncStatusLabel.text = syncStatus
            
            if syncStatus.contains("synced") {
                iCloudSyncStatusLabel.textColor = .systemGreen
            } else {
                iCloudSyncStatusLabel.textColor = .secondaryLabel
            }
            iCloudForceSync.isEnabled = true
        } else {
            iCloudSyncStatusLabel.text = "Not Available"
            iCloudSyncStatusLabel.textColor = .systemRed
            iCloudForceSync.isEnabled = false
        }
    }
}

// MARK: - Board Selector View Controller
class BoardSelectorViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    // MARK: - Properties
    var boardNames: [String] = []
    var boardAbv: [String] = []
    var currentSelection: String?
    var onBoardSelected: ((String?) -> Void)?
    
    private var filteredBoardNames: [String] = []
    private var filteredBoardAbv: [String] = []
    private var isSearching = false
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Select Default Board"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Setup navigation buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "None", style: .plain, target: self, action: #selector(noneTapped))
        
        setupSearchBar()
        setupTableView()
        
        // Initialize filtered arrays
        filteredBoardNames = boardNames
        filteredBoardAbv = boardAbv
    }
    
    // MARK: - UI Setup
    private func setupSearchBar() {
        searchBar.placeholder = "Search boards..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BoardCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func noneTapped() {
        onBoardSelected?(nil)
        dismiss(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredBoardNames.count : boardNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BoardCell", for: indexPath)
        cell.selectionStyle = .none

        let names = isSearching ? filteredBoardNames : boardNames
        let abvs = isSearching ? filteredBoardAbv : boardAbv

        if indexPath.row < names.count && indexPath.row < abvs.count {
            let boardName = names[indexPath.row]
            let boardCode = abvs[indexPath.row]

            var content = cell.defaultContentConfiguration()
            content.text = "\(boardName) (/\(boardCode)/)"
            cell.contentConfiguration = content

            // Add checkmark for current selection
            if boardCode == currentSelection {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }

        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let abvs = isSearching ? filteredBoardAbv : boardAbv
        if indexPath.row < abvs.count {
            let selectedCode = abvs[indexPath.row]
            onBoardSelected?(selectedCode)
            dismiss(animated: true)
        }
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredBoardNames = boardNames
            filteredBoardAbv = boardAbv
        } else {
            isSearching = true
            let searchTextLowercased = searchText.lowercased()
            
            // Filter by both board name and abbreviation
            let filteredIndices = boardNames.indices.filter { index in
                boardNames[index].lowercased().contains(searchTextLowercased) ||
                boardAbv[index].lowercased().contains(searchTextLowercased)
            }
            
            filteredBoardNames = filteredIndices.map { boardNames[$0] }
            filteredBoardAbv = filteredIndices.map { boardAbv[$0] }
        }
        
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
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
        cell.selectionStyle = .none

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

// MARK: - Media Prefetch Settings

final class MediaPrefetchSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private enum Section: Int, CaseIterable {
        case mode
        case battery
        case perBoard

        var title: String {
            switch self {
            case .mode:
                return "Network"
            case .battery:
                return "Battery"
            case .perBoard:
                return "Per-board Rules"
            }
        }
    }

    private enum BatteryRow: Int, CaseIterable {
        case pauseLowPower
        case minimumBattery
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let manager = MediaPrefetchManager.shared
    private let batteryOptions = [0, 20, 40]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Media Prefetching"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .mode:
            return 1
        case .battery:
            return BatteryRow.allCases.count
        case .perBoard:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .mode:
            return "Prefetches thumbnails to make scrolling smoother."
        case .battery:
            return "Prefetching pauses when Low Power Mode is enabled or the battery is below the selected threshold."
        case .perBoard:
            return "Overrides apply to both board and thread views."
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MediaPrefetchCell") ??
            UITableViewCell(style: .value1, reuseIdentifier: "MediaPrefetchCell")
        cell.backgroundColor = ThemeManager.shared.backgroundColor
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.text = nil
        cell.accessoryView = nil
        cell.accessoryType = .none

        guard let section = Section(rawValue: indexPath.section) else { return cell }
        switch section {
        case .mode:
            cell.textLabel?.text = "Prefetch Mode"
            cell.detailTextLabel?.text = manager.mode.displayName
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .battery:
            guard let row = BatteryRow(rawValue: indexPath.row) else { return cell }
            switch row {
            case .pauseLowPower:
                cell.textLabel?.text = "Pause on Low Power Mode"
                let toggle = UISwitch()
                toggle.isOn = manager.pauseOnLowPowerMode
                toggle.addTarget(self, action: #selector(pauseOnLowPowerChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                cell.selectionStyle = .none
            case .minimumBattery:
                cell.textLabel?.text = "Minimum Battery"
                let value = manager.minimumBatteryPercent
                cell.detailTextLabel?.text = value == 0 ? "Off" : "\(value)%"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
        case .perBoard:
            cell.textLabel?.text = "Manage Per-board Rules"
            let count = manager.boardOverrideCount()
            cell.detailTextLabel?.text = count == 0 ? "None" : "\(count) override\(count == 1 ? "" : "s")"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .mode:
            if let cell = tableView.cellForRow(at: indexPath) {
                presentModePicker(from: cell)
            }
        case .battery:
            if BatteryRow(rawValue: indexPath.row) == .minimumBattery,
               let cell = tableView.cellForRow(at: indexPath) {
                presentBatteryPicker(from: cell)
            }
        case .perBoard:
            let perBoardVC = MediaPrefetchBoardRulesViewController()
            navigationController?.pushViewController(perBoardVC, animated: true)
        }
    }

    @objc private func pauseOnLowPowerChanged(_ sender: UISwitch) {
        manager.pauseOnLowPowerMode = sender.isOn
    }

    private func presentModePicker(from cell: UITableViewCell) {
        let alert = UIAlertController(title: "Prefetch Mode", message: "Choose when to prefetch media", preferredStyle: .actionSheet)

        for mode in MediaPrefetchManager.PrefetchMode.allCases {
            let action = UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.manager.mode = mode
                self?.tableView.reloadSections(IndexSet(integer: Section.mode.rawValue), with: .none)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            if mode == manager.mode {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }

    private func presentBatteryPicker(from cell: UITableViewCell) {
        let alert = UIAlertController(title: "Minimum Battery", message: "Choose a battery threshold", preferredStyle: .actionSheet)

        for value in batteryOptions {
            let title = value == 0 ? "Off" : "\(value)%"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.manager.minimumBatteryPercent = value
                self?.tableView.reloadSections(IndexSet(integer: Section.battery.rawValue), with: .none)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            if value == manager.minimumBatteryPercent {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }
}

final class MediaPrefetchBoardRulesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    private var boardNames: [String] = []
    private var boardCodes: [String] = []
    private var filteredBoardNames: [String] = []
    private var filteredBoardCodes: [String] = []
    private var isSearching = false

    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let headerLabel = UILabel()
    private let manager = MediaPrefetchManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Per-board Prefetch"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        boardNames = BoardsService.shared.boardNames
        boardCodes = BoardsService.shared.boardAbv
        sortBoardsAlphabetically()

        filteredBoardNames = boardNames
        filteredBoardCodes = boardCodes

        setupHeader()
        setupSearchBar()
        setupTableView()

        BoardsService.shared.fetchBoards { [weak self] in
            guard let self = self else { return }
            self.boardNames = BoardsService.shared.boardNames
            self.boardCodes = BoardsService.shared.boardAbv
            self.sortBoardsAlphabetically()
            self.filteredBoardNames = self.boardNames
            self.filteredBoardCodes = self.boardCodes
            self.tableView.reloadData()
            self.updateHeader()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeader()
        tableView.reloadData()
    }

    private func setupHeader() {
        headerLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        headerLabel.textColor = .secondaryLabel
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        updateHeader()

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupSearchBar() {
        searchBar.placeholder = "Search boards..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BoardPrefetchCell")
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateHeader() {
        let overrideCount = manager.boardOverrideCount()
        if overrideCount == 0 {
            headerLabel.text = "No overrides. Boards use the global prefetch mode."
        } else {
            headerLabel.text = "\(overrideCount) board override\(overrideCount == 1 ? "" : "s"). Tap a board to change."
        }
    }

    private func sortBoardsAlphabetically() {
        let combinedBoards = zip(boardNames, boardCodes).map { ($0, $1) }
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        boardNames = sortedBoards.map { $0.0 }
        boardCodes = sortedBoards.map { $0.1 }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredBoardNames.count : boardNames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BoardPrefetchCell", for: indexPath)

        let names = isSearching ? filteredBoardNames : boardNames
        let codes = isSearching ? filteredBoardCodes : boardCodes
        guard indexPath.row < names.count, indexPath.row < codes.count else { return cell }

        let boardName = names[indexPath.row]
        let boardCode = codes[indexPath.row]
        let override = manager.boardOverride(for: boardCode)

        let detail: String
        if let override = override {
            detail = override.displayName
        } else {
            detail = "Use Global (\(manager.mode.displayName))"
        }

        var content = cell.defaultContentConfiguration()
        content.text = boardName
        content.secondaryText = "/\(boardCode)/ • \(detail)"
        content.secondaryTextProperties.color = .secondaryLabel

        cell.contentConfiguration = content
        cell.backgroundColor = ThemeManager.shared.backgroundColor
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let codes = isSearching ? filteredBoardCodes : boardCodes
        guard indexPath.row < codes.count, let cell = tableView.cellForRow(at: indexPath) else { return }

        presentOverridePicker(for: codes[indexPath.row], from: cell, indexPath: indexPath)
    }

    private func presentOverridePicker(for boardCode: String, from cell: UITableViewCell, indexPath: IndexPath) {
        let title = "/\(boardCode)/ Prefetch"
        let alert = UIAlertController(title: title, message: "Set a per-board prefetch rule", preferredStyle: .actionSheet)

        let currentOverride = manager.boardOverride(for: boardCode)
        let globalTitle = "Use Global (\(manager.mode.displayName))"

        let globalAction = UIAlertAction(title: globalTitle, style: .default) { [weak self] _ in
            self?.manager.setBoardOverride(nil, for: boardCode)
            self?.updateRow(at: indexPath)
        }
        if currentOverride == nil {
            globalAction.setValue(true, forKey: "checked")
        }
        alert.addAction(globalAction)

        for mode in MediaPrefetchManager.PrefetchMode.allCases {
            let action = UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.manager.setBoardOverride(mode, for: boardCode)
                self?.updateRow(at: indexPath)
            }
            if mode == currentOverride {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }

    private func updateRow(at indexPath: IndexPath) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateHeader()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredBoardNames = boardNames
            filteredBoardCodes = boardCodes
        } else {
            isSearching = true
            let searchTextLowercased = searchText.lowercased()

            let filteredIndices = boardNames.indices.filter { index in
                boardNames[index].lowercased().contains(searchTextLowercased) ||
                boardCodes[index].lowercased().contains(searchTextLowercased)
            }

            filteredBoardNames = filteredIndices.map { boardNames[$0] }
            filteredBoardCodes = filteredIndices.map { boardCodes[$0] }
        }

        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
