import UIKit

class CategoryManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    weak var delegate: CategoryManagerDelegate?
    private let tableView = UITableView()
    private var categories: [BookmarkCategory] = []
    private let favoritesManager = FavoritesManager.shared
    private let navigationBar = UINavigationBar()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCategories()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Setup Navigation Bar
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)
        
        let navigationItem = UINavigationItem(title: "Manage Categories")
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCategory))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissView))
        
        navigationItem.rightBarButtonItem = addButton
        navigationItem.leftBarButtonItem = doneButton
        navigationBar.items = [navigationItem]
        
        // Apply theme to navigation bar
        navigationBar.barTintColor = ThemeManager.shared.cellBackgroundColor
        navigationBar.titleTextAttributes = [.foregroundColor: ThemeManager.shared.primaryTextColor]
        navigationBar.isTranslucent = false
        
        // Setup Table View
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CategoryCell.self, forCellReuseIdentifier: "CategoryCell")
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.separatorColor = .systemGray4
        view.addSubview(tableView)
        
        // Setup Constraints
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func dismissView() {
        delegate?.categoriesDidUpdate()
        dismiss(animated: true)
    }
    
    @objc private func addCategory() {
        let alert = UIAlertController(title: "New Category", message: "Enter category details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Category Name"
        }
        
        let colors = ["#007AFF", "#34C759", "#FF3B30", "#FFCC00", "#AF52DE", "#8E8E93"]
        let icons = ["folder", "bookmark", "heart", "star", "flag", "tag"]
        
        let colorPickerVC = UIViewController()
        let colorStackView = UIStackView()
        colorStackView.axis = .horizontal
        colorStackView.distribution = .fillEqually
        colorStackView.spacing = 8
        colorStackView.translatesAutoresizingMaskIntoConstraints = false
        
        var selectedColor = colors[0]
        for color in colors {
            let colorButton = UIButton()
            colorButton.backgroundColor = UIColor(hex: color)
            colorButton.layer.cornerRadius = 20
            colorButton.addAction(UIAction { _ in
                selectedColor = color
            }, for: .touchUpInside)
            colorStackView.addArrangedSubview(colorButton)
        }
        
        colorPickerVC.view.addSubview(colorStackView)
        NSLayoutConstraint.activate([
            colorStackView.centerXAnchor.constraint(equalTo: colorPickerVC.view.centerXAnchor),
            colorStackView.centerYAnchor.constraint(equalTo: colorPickerVC.view.centerYAnchor),
            colorStackView.widthAnchor.constraint(equalToConstant: 280),
            colorStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        colorPickerVC.preferredContentSize = CGSize(width: 300, height: 100)
        alert.setValue(colorPickerVC, forKey: "contentViewController")
        
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            _ = self?.favoritesManager.createCategory(name: name, color: selectedColor, icon: icons.randomElement() ?? "folder")
            self?.loadCategories()
        }
        
        alert.addAction(createAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func loadCategories() {
        categories = favoritesManager.getCategories()
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let category = categories[indexPath.row]
        cell.configure(with: category)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Don't allow deletion of the first (default) category
        return indexPath.row > 0
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.row > 0 {
            let category = categories[indexPath.row]
            favoritesManager.deleteCategory(id: category.id)
            loadCategories()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        editCategory(category)
    }
    
    private func editCategory(_ category: BookmarkCategory) {
        let alert = UIAlertController(title: "Edit Category", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = category.name
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            var updatedCategory = category
            updatedCategory.name = name
            updatedCategory.updatedAt = Date()
            self?.favoritesManager.updateCategory(updatedCategory)
            self?.loadCategories()
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - CategoryCell
class CategoryCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let countLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = ThemeManager.shared.cellBackgroundColor
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true
        contentView.addSubview(iconImageView)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = ThemeManager.shared.primaryTextColor
        contentView.addSubview(nameLabel)
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 14)
        countLabel.textColor = ThemeManager.shared.secondaryTextColor
        contentView.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with category: BookmarkCategory) {
        nameLabel.text = category.name
        iconImageView.backgroundColor = UIColor(hex: category.color) ?? UIColor.systemBlue
        
        // Create icon in center of colored background
        let iconView = UIImageView(image: UIImage(systemName: category.icon))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        iconImageView.subviews.forEach { $0.removeFromSuperview() }
        iconImageView.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Count threads in this category
        let count = FavoritesManager.shared.getFavorites(for: category.id).count
        countLabel.text = "\(count)"
    }
}

// UIColor extension with hex support is already defined in ThemeManager.swift