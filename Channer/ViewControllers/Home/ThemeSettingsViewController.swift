import UIKit

/// View controller for managing app themes and appearance settings
/// Allows users to select from built-in themes or create custom themes
class ThemeSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerLabel = UILabel()
    private var themes: [Theme] = []
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadThemes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload themes to ensure we have the latest data
        loadThemes()
        tableView.reloadData()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Theme Settings"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Navigation bar buttons
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addThemeTapped)
        )
        
        // Header Label
        headerLabel.text = "Select a Theme"
        headerLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ThemeCell.self, forCellReuseIdentifier: "ThemeCell")
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Header Label
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Table View
            tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }
    
    // MARK: - Data Loading
    private func loadThemes() {
        themes = ThemeManager.shared.availableThemes
    }
    
    // MARK: - Action Handlers
    @objc private func addThemeTapped() {
        let themeEditor = ThemeEditorViewController(theme: nil)
        navigationController?.pushViewController(themeEditor, animated: true)
    }
    
    @objc private func themeDidChange() {
        // Update UI colors
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCell", for: indexPath) as? ThemeCell else {
            return UITableViewCell()
        }
        
        let theme = themes[indexPath.row]
        let isSelected = theme.id == ThemeManager.shared.currentTheme.id
        
        cell.configure(with: theme, isSelected: isSelected)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Available Themes"
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let theme = themes[indexPath.row]
        ThemeManager.shared.setTheme(id: theme.id)
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let theme = themes[indexPath.row]
        
        // Don't allow editing/deleting built-in themes
        if theme.isBuiltIn {
            return nil
        }
        
        // Edit action
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
            self?.editTheme(at: indexPath)
            completion(true)
        }
        editAction.backgroundColor = .systemBlue
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            self?.deleteTheme(at: indexPath)
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
    // MARK: - Helper Methods
    private func editTheme(at indexPath: IndexPath) {
        let theme = themes[indexPath.row]
        let themeEditor = ThemeEditorViewController(theme: theme)
        navigationController?.pushViewController(themeEditor, animated: true)
    }
    
    private func deleteTheme(at indexPath: IndexPath) {
        let theme = themes[indexPath.row]
        
        let alert = UIAlertController(
            title: "Delete Theme",
            message: "Are you sure you want to delete the theme '\(theme.name)'?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            ThemeManager.shared.deleteCustomTheme(id: theme.id)
            self?.loadThemes()
            self?.tableView.reloadData()
        })
        
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ThemeCell
class ThemeCell: UITableViewCell {
    
    private let nameLabel = UILabel()
    private let typeLabel = UILabel()
    private let previewContainer = UIView()
    private let checkmarkImageView = UIImageView()
    
    // Preview elements
    private let backgroundPreview = UIView()
    private let cellPreview = UIView()
    private let textPreview = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Cell appearance
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Name Label
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // Type Label
        typeLabel.font = UIFont.systemFont(ofSize: 12)
        typeLabel.textColor = .secondaryLabel
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)
        
        // Preview Container
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.layer.cornerRadius = 8
        previewContainer.clipsToBounds = true
        contentView.addSubview(previewContainer)
        
        // Background Preview
        backgroundPreview.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(backgroundPreview)
        
        // Cell Preview
        cellPreview.translatesAutoresizingMaskIntoConstraints = false
        cellPreview.layer.cornerRadius = 4
        cellPreview.clipsToBounds = true
        previewContainer.addSubview(cellPreview)
        
        // Text Preview
        textPreview.text = "Aa"
        textPreview.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        textPreview.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(textPreview)
        
        // Checkmark
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = .systemBlue
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.isHidden = true
        contentView.addSubview(checkmarkImageView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Name Label
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Type Label
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            // Checkmark
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Preview Container
            previewContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            previewContainer.widthAnchor.constraint(equalToConstant: 60),
            previewContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // Background Preview
            backgroundPreview.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            backgroundPreview.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            backgroundPreview.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            backgroundPreview.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            
            // Cell Preview
            cellPreview.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor, constant: 4),
            cellPreview.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 4),
            cellPreview.widthAnchor.constraint(equalToConstant: 30),
            cellPreview.heightAnchor.constraint(equalToConstant: 20),
            
            // Text Preview
            textPreview.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            textPreview.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -10)
        ])
    }
    
    func configure(with theme: Theme, isSelected: Bool) {
        nameLabel.text = theme.name
        typeLabel.text = theme.isBuiltIn ? "Built-in" : "Custom"
        checkmarkImageView.isHidden = !isSelected
        
        let traitCollection = UITraitCollection.current
        
        // Set preview colors
        backgroundPreview.backgroundColor = theme.backgroundColor.color(for: traitCollection)
        cellPreview.backgroundColor = theme.cellBackgroundColor.color(for: traitCollection)
        textPreview.textColor = theme.primaryTextColor.color(for: traitCollection)
        
        // Add a border to the cell preview
        cellPreview.layer.borderWidth = 1
        cellPreview.layer.borderColor = theme.cellBorderColor.color(for: traitCollection).cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        typeLabel.text = nil
        checkmarkImageView.isHidden = true
    }
}