import UIKit

class CategoryManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Properties
    weak var delegate: CategoryManagerDelegate?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var categories: [BookmarkCategory] = []
    private let favoritesManager = FavoritesManager.shared

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
        title = "Manage Categories"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCategory)
        )

        // Setup Table View
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CategoryCell.self, forCellReuseIdentifier: "CategoryCell")
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
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

        // Wrap in navigation controller if presented modally without one
        if navigationController == nil {
            let navController = UINavigationController(rootViewController: self)
            navController.modalPresentationStyle = .formSheet
            navController.navigationBar.prefersLargeTitles = false
        }
    }

    // MARK: - Actions
    @objc private func dismissView() {
        delegate?.categoriesDidUpdate()
        dismiss(animated: true)
    }

    @objc private func addCategory() {
        showCategoryEditor(category: nil)
    }

    private func showCategoryEditor(category: BookmarkCategory?) {
        let isEditing = category != nil
        let alert = UIAlertController(
            title: isEditing ? "Edit Category" : "New Category",
            message: nil,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Category Name"
            textField.text = category?.name
            textField.autocapitalizationType = .words
        }

        // Color options
        let colors: [(name: String, hex: String)] = [
            ("Blue", "#007AFF"),
            ("Green", "#34C759"),
            ("Red", "#FF3B30"),
            ("Orange", "#FF9500"),
            ("Purple", "#AF52DE"),
            ("Pink", "#FF2D55"),
            ("Teal", "#5AC8FA"),
            ("Gray", "#8E8E93")
        ]

        // Icon options
        let icons = ["folder", "bookmark", "heart", "star", "flag", "tag", "bell", "doc"]

        var selectedColorIndex = 0
        var selectedIconIndex = 0

        // Find current selection if editing
        if let category = category {
            if let colorIdx = colors.firstIndex(where: { $0.hex == category.color }) {
                selectedColorIndex = colorIdx
            }
            if let iconIdx = icons.firstIndex(of: category.icon) {
                selectedIconIndex = iconIdx
            }
        }

        // Create color picker
        let colorPickerContainer = UIView()
        colorPickerContainer.translatesAutoresizingMaskIntoConstraints = false

        let colorLabel = UILabel()
        colorLabel.text = "Color"
        colorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        colorLabel.textColor = .secondaryLabel
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        colorPickerContainer.addSubview(colorLabel)

        let colorStackView = UIStackView()
        colorStackView.axis = .horizontal
        colorStackView.distribution = .fillEqually
        colorStackView.spacing = 8
        colorStackView.translatesAutoresizingMaskIntoConstraints = false

        var colorButtons: [UIButton] = []
        for (index, color) in colors.enumerated() {
            let button = UIButton()
            button.backgroundColor = UIColor(hex: color.hex)
            button.layer.cornerRadius = 16
            button.layer.borderWidth = index == selectedColorIndex ? 3 : 0
            button.layer.borderColor = UIColor.label.cgColor
            button.tag = index
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            colorStackView.addArrangedSubview(button)
            colorButtons.append(button)

            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }
        colorPickerContainer.addSubview(colorStackView)

        // Create icon picker
        let iconLabel = UILabel()
        iconLabel.text = "Icon"
        iconLabel.font = .systemFont(ofSize: 13, weight: .medium)
        iconLabel.textColor = .secondaryLabel
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        colorPickerContainer.addSubview(iconLabel)

        let iconStackView = UIStackView()
        iconStackView.axis = .horizontal
        iconStackView.distribution = .fillEqually
        iconStackView.spacing = 8
        iconStackView.translatesAutoresizingMaskIntoConstraints = false

        var iconButtons: [UIButton] = []
        for (index, icon) in icons.enumerated() {
            let button = UIButton()
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = index == selectedIconIndex ? .systemBlue : .secondaryLabel
            button.backgroundColor = index == selectedIconIndex ? .systemBlue.withAlphaComponent(0.15) : .clear
            button.layer.cornerRadius = 16
            button.tag = index
            button.addTarget(self, action: #selector(iconButtonTapped(_:)), for: .touchUpInside)
            iconStackView.addArrangedSubview(button)
            iconButtons.append(button)

            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }
        colorPickerContainer.addSubview(iconStackView)

        NSLayoutConstraint.activate([
            colorLabel.topAnchor.constraint(equalTo: colorPickerContainer.topAnchor, constant: 8),
            colorLabel.leadingAnchor.constraint(equalTo: colorPickerContainer.leadingAnchor),

            colorStackView.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 8),
            colorStackView.centerXAnchor.constraint(equalTo: colorPickerContainer.centerXAnchor),

            iconLabel.topAnchor.constraint(equalTo: colorStackView.bottomAnchor, constant: 16),
            iconLabel.leadingAnchor.constraint(equalTo: colorPickerContainer.leadingAnchor),

            iconStackView.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            iconStackView.centerXAnchor.constraint(equalTo: colorPickerContainer.centerXAnchor),
            iconStackView.bottomAnchor.constraint(equalTo: colorPickerContainer.bottomAnchor, constant: -8)
        ])

        let containerVC = UIViewController()
        containerVC.view.addSubview(colorPickerContainer)
        colorPickerContainer.centerXAnchor.constraint(equalTo: containerVC.view.centerXAnchor).isActive = true
        colorPickerContainer.topAnchor.constraint(equalTo: containerVC.view.topAnchor).isActive = true
        colorPickerContainer.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor).isActive = true
        colorPickerContainer.widthAnchor.constraint(equalToConstant: 280).isActive = true

        containerVC.preferredContentSize = CGSize(width: 300, height: 140)
        alert.setValue(containerVC, forKey: "contentViewController")

        // Store references for button handlers
        objc_setAssociatedObject(alert, "colorButtons", colorButtons, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(alert, "iconButtons", iconButtons, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(alert, "selectedColorIndex", selectedColorIndex, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(alert, "selectedIconIndex", selectedIconIndex, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(alert, "colors", colors.map { $0.hex }, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(alert, "icons", icons, .OBJC_ASSOCIATION_RETAIN)

        let saveAction = UIAlertAction(title: isEditing ? "Save" : "Create", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }

            let finalColorIndex = objc_getAssociatedObject(alert, "selectedColorIndex") as? Int ?? 0
            let finalIconIndex = objc_getAssociatedObject(alert, "selectedIconIndex") as? Int ?? 0
            let colorsArray = objc_getAssociatedObject(alert, "colors") as? [String] ?? []
            let iconsArray = objc_getAssociatedObject(alert, "icons") as? [String] ?? []

            let selectedColor = colorsArray[finalColorIndex]
            let selectedIcon = iconsArray[finalIconIndex]

            if var existingCategory = category {
                existingCategory.name = name
                existingCategory.color = selectedColor
                existingCategory.icon = selectedIcon
                existingCategory.updatedAt = Date()
                self?.favoritesManager.updateCategory(existingCategory)
            } else {
                _ = self?.favoritesManager.createCategory(name: name, color: selectedColor, icon: selectedIcon)
            }
            self?.loadCategories()
        }

        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let alert = presentedViewController as? UIAlertController,
              let colorButtons = objc_getAssociatedObject(alert, "colorButtons") as? [UIButton] else { return }

        // Update selection
        for button in colorButtons {
            button.layer.borderWidth = button.tag == sender.tag ? 3 : 0
        }
        objc_setAssociatedObject(alert, "selectedColorIndex", sender.tag, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc private func iconButtonTapped(_ sender: UIButton) {
        guard let alert = presentedViewController as? UIAlertController,
              let iconButtons = objc_getAssociatedObject(alert, "iconButtons") as? [UIButton] else { return }

        // Update selection
        for button in iconButtons {
            button.tintColor = button.tag == sender.tag ? .systemBlue : .secondaryLabel
            button.backgroundColor = button.tag == sender.tag ? .systemBlue.withAlphaComponent(0.15) : .clear
        }
        objc_setAssociatedObject(alert, "selectedIconIndex", sender.tag, .OBJC_ASSOCIATION_RETAIN)
    }

    private func loadCategories() {
        categories = favoritesManager.getCategories()
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let category = categories[indexPath.row]
        let isDefault = indexPath.row == 0
        cell.configure(with: category, isDefault: isDefault)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Categories"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Tap a category to edit. Swipe left to delete (except the default category)."
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Don't allow deletion of the first (default) category
        return indexPath.row > 0
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.row > 0 {
            let category = categories[indexPath.row]

            let alert = UIAlertController(
                title: "Delete Category",
                message: "Threads in this category will be moved to the default category.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                self?.favoritesManager.deleteCategory(id: category.id)
                self?.loadCategories()
            })
            present(alert, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        showCategoryEditor(category: category)
    }
}

// MARK: - CategoryCell
class CategoryCell: UITableViewCell {
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let countLabel = UILabel()
    private let defaultBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = ThemeManager.shared.cellBackgroundColor
        accessoryType = .disclosureIndicator

        // Icon container (colored background)
        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.layer.cornerRadius = 8
        iconContainerView.clipsToBounds = true
        contentView.addSubview(iconContainerView)

        // Icon image
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconContainerView.addSubview(iconImageView)

        // Name label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 17)
        nameLabel.textColor = ThemeManager.shared.primaryTextColor
        contentView.addSubview(nameLabel)

        // Default badge
        defaultBadge.translatesAutoresizingMaskIntoConstraints = false
        defaultBadge.text = "Default"
        defaultBadge.font = .systemFont(ofSize: 11, weight: .medium)
        defaultBadge.textColor = .secondaryLabel
        defaultBadge.backgroundColor = .systemGray5
        defaultBadge.layer.cornerRadius = 4
        defaultBadge.clipsToBounds = true
        defaultBadge.textAlignment = .center
        defaultBadge.isHidden = true
        contentView.addSubview(defaultBadge)

        // Count label
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 17)
        countLabel.textColor = .secondaryLabel
        contentView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            iconContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 36),
            iconContainerView.heightAnchor.constraint(equalToConstant: 36),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            defaultBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            defaultBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            defaultBadge.widthAnchor.constraint(equalToConstant: 52),
            defaultBadge.heightAnchor.constraint(equalToConstant: 18),

            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with category: BookmarkCategory, isDefault: Bool = false) {
        nameLabel.text = category.name
        iconContainerView.backgroundColor = UIColor(hex: category.color) ?? .systemBlue
        iconImageView.image = UIImage(systemName: category.icon)
        defaultBadge.isHidden = !isDefault

        // Count threads in this category
        let count = FavoritesManager.shared.getFavorites(for: category.id).count
        countLabel.text = "\(count)"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        defaultBadge.isHidden = true
    }
}
