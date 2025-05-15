import UIKit
import UserNotifications

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
    private let themeSettingsView = UIView()
    private let themeSettingsLabel = UILabel()
    private let themeSettingsButton = UIButton(type: .system)
    
    // Constants
    private let cellIdentifier = "BoardCell"
    private let userDefaultsKey = "defaultBoard"
    private let faceIDEnabledKey = "channer_faceID_authentication_enabled"
    private let notificationsEnabledKey = "channer_notifications_enabled"
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
        
        // Set default value for FaceID toggle if it doesn't exist yet
        if UserDefaults.standard.object(forKey: faceIDEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: faceIDEnabledKey)
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
                ThemeManager.shared.setTheme(id: theme.id)
                
                // For OLED Black theme, ensure we update the UI Style immediately
                if theme.id == "oled_black" {
                    // Force dark mode for any windows when using OLED Black
                    UIApplication.shared.windows.forEach { window in
                        window.overrideUserInterfaceStyle = .dark
                    }
                    
                    // Force background color update
                    self?.view.backgroundColor = UIColor.black
                }
                
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
            
            // Theme Settings View
            themeSettingsView.topAnchor.constraint(equalTo: notificationsView.bottomAnchor, constant: 16),
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
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: themeSettingsView.bottomAnchor, constant: 16),
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
