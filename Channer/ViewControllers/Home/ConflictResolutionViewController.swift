import UIKit

/// UI for manual conflict resolution when iCloud sync conflicts occur
class ConflictResolutionViewController: UIViewController {
    
    // MARK: - Properties
    
    private var conflict: ConflictResolutionManager.SyncConflict?
    private var completionHandler: ((ConflictResolutionManager.ConflictResolution) -> Void)?
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let localDataContainer = UIView()
    private let localDataLabel = UILabel()
    private let localTimestampLabel = UILabel()
    private let remoteDataContainer = UIView()
    private let remoteDataLabel = UILabel()
    private let remoteTimestampLabel = UILabel()
    private let buttonsStackView = UIStackView()
    
    // MARK: - Initialization
    
    init(conflict: ConflictResolutionManager.SyncConflict, completion: @escaping (ConflictResolutionManager.ConflictResolution) -> Void) {
        self.conflict = conflict
        self.completionHandler = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayConflictData()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Setup title
        titleLabel.text = "Sync Conflict Detected"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Setup description
        descriptionLabel.text = getConflictDescription()
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        // Setup data containers
        setupDataContainer(localDataContainer, title: "Local Data", dataLabel: localDataLabel, timestampLabel: localTimestampLabel)
        setupDataContainer(remoteDataContainer, title: "iCloud Data", dataLabel: remoteDataLabel, timestampLabel: remoteTimestampLabel)
        
        // Setup buttons
        setupButtons()
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupDataContainer(_ container: UIView, title: String, dataLabel: UILabel, timestampLabel: UILabel) {
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        dataLabel.font = .systemFont(ofSize: 14)
        dataLabel.numberOfLines = 0
        dataLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dataLabel)
        
        timestampLabel.font = .systemFont(ofSize: 12)
        timestampLabel.textColor = .secondaryLabel
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timestampLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            dataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            dataLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            dataLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            timestampLabel.topAnchor.constraint(equalTo: dataLabel.bottomAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            timestampLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            timestampLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupButtons() {
        buttonsStackView.axis = .vertical
        buttonsStackView.spacing = 12
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonsStackView)
        
        let keepLocalButton = createButton(title: "Keep Local Data", action: #selector(keepLocalTapped))
        let keepRemoteButton = createButton(title: "Keep iCloud Data", action: #selector(keepRemoteTapped))
        let mergeButton = createButton(title: "Merge Both", action: #selector(mergeTapped))
        
        buttonsStackView.addArrangedSubview(keepLocalButton)
        buttonsStackView.addArrangedSubview(keepRemoteButton)
        buttonsStackView.addArrangedSubview(mergeButton)
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            localDataContainer.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            localDataContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            localDataContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            remoteDataContainer.topAnchor.constraint(equalTo: localDataContainer.bottomAnchor, constant: 16),
            remoteDataContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            remoteDataContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            buttonsStackView.topAnchor.constraint(equalTo: remoteDataContainer.bottomAnchor, constant: 24),
            buttonsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Display
    
    private func displayConflictData() {
        guard let conflict = conflict else { return }
        
        // Display local data
        localDataLabel.text = formatDataForDisplay(conflict.localData, type: conflict.type)
        localTimestampLabel.text = formatTimestamp(conflict.localTimestamp)
        
        // Display remote data
        remoteDataLabel.text = formatDataForDisplay(conflict.remoteData, type: conflict.type)
        remoteTimestampLabel.text = formatTimestamp(conflict.remoteTimestamp)
    }
    
    private func formatDataForDisplay(_ data: Any, type: ConflictResolutionManager.ConflictType) -> String {
        switch type {
        case .favorites, .history:
            if let threads = data as? [ThreadData] {
                return "\\(threads.count) items"
            }
        case .categories:
            if let categories = data as? [BookmarkCategory] {
                return categories.map { $0.name }.joined(separator: ", ")
            }
        case .themes:
            if let themes = data as? [Theme] {
                return themes.map { $0.name }.joined(separator: ", ")
            }
        case .settings:
            return "Settings data"
        }
        return "Unknown data"
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Last modified: \\(formatter.string(from: date))"
    }
    
    private func getConflictDescription() -> String {
        guard let conflict = conflict else { return "" }
        
        switch conflict.type {
        case .favorites:
            return "Your favorites differ between this device and iCloud. Choose which version to keep."
        case .history:
            return "Your browsing history differs between this device and iCloud. Choose which version to keep."
        case .categories:
            return "Your bookmark categories differ between this device and iCloud. Choose which version to keep."
        case .themes:
            return "Your custom themes differ between this device and iCloud. Choose which version to keep."
        case .settings:
            return "Your app settings differ between this device and iCloud. Choose which version to keep."
        }
    }
    
    // MARK: - Actions
    
    @objc private func keepLocalTapped() {
        completionHandler?(.takeLocal)
        dismiss(animated: true)
    }
    
    @objc private func keepRemoteTapped() {
        completionHandler?(.takeRemote)
        dismiss(animated: true)
    }
    
    @objc private func mergeTapped() {
        completionHandler?(.merge)
        dismiss(animated: true)
    }
}