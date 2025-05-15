import UIKit

class ThemeEditorViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerLabel = UILabel()
    private let nameTextField = UITextField()
    
    private var editingTheme: Theme?
    private var isDirty = false
    
    private var themeName: String = "New Theme"
    private var lightBackgroundColor: UIColor = .systemBackground
    private var darkBackgroundColor: UIColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    private var lightSecondaryBgColor: UIColor = .secondarySystemBackground
    private var darkSecondaryBgColor: UIColor = UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
    private var lightCellBgColor: UIColor = UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
    private var darkCellBgColor: UIColor = UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
    private var lightCellBorderColor: UIColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0)
    private var darkCellBorderColor: UIColor = UIColor(red: 0.25, green: 0.52, blue: 0.28, alpha: 1.0)
    private var lightPrimaryTextColor: UIColor = .black
    private var darkPrimaryTextColor: UIColor = .white
    private var lightSecondaryTextColor: UIColor = .darkGray
    private var darkSecondaryTextColor: UIColor = .lightGray
    private var lightGreentextColor: UIColor = UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
    private var darkGreentextColor: UIColor = UIColor(red: 140/255, green: 183/255, blue: 54/255, alpha: 1.0)
    private var lightAlertColor: UIColor = .systemRed
    private var darkAlertColor: UIColor = .systemRed
    private var lightSpoilerTextColor: UIColor = .black
    private var darkSpoilerTextColor: UIColor = .white
    private var lightSpoilerBgColor: UIColor = .black
    private var darkSpoilerBgColor: UIColor = .darkGray
    
    // Sections and rows
    private enum Section: Int, CaseIterable {
        case themeInfo
        case backgroundColors
        case cellColors
        case textColors
        case specialColors
        case spoilerColors
    }
    
    private enum BackgroundColorRow: Int, CaseIterable {
        case background
        case secondaryBackground
    }
    
    private enum CellColorRow: Int, CaseIterable {
        case cellBackground
        case cellBorder
    }
    
    private enum TextColorRow: Int, CaseIterable {
        case primaryText
        case secondaryText
    }
    
    private enum SpecialColorRow: Int, CaseIterable {
        case greentext
        case alert
    }
    
    private enum SpoilerColorRow: Int, CaseIterable {
        case spoilerText
        case spoilerBackground
    }
    
    // MARK: - Initialization
    init(theme: Theme?) {
        self.editingTheme = theme
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        if let theme = editingTheme {
            loadThemeValues(theme)
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = editingTheme == nil ? "Create Theme" : "Edit Theme"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Navigation bar buttons
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        // Header Label
        headerLabel.text = editingTheme == nil ? "Create a New Theme" : "Edit Theme"
        headerLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(NameCell.self, forCellReuseIdentifier: "NameCell")
        tableView.register(ColorCell.self, forCellReuseIdentifier: "ColorCell")
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
    }
    
    // MARK: - Data Loading
    private func loadThemeValues(_ theme: Theme) {
        themeName = theme.name
        
        lightBackgroundColor = UIColor(hex: theme.backgroundColor.light) ?? .systemBackground
        darkBackgroundColor = UIColor(hex: theme.backgroundColor.dark) ?? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        
        lightSecondaryBgColor = UIColor(hex: theme.secondaryBackgroundColor.light) ?? .secondarySystemBackground
        darkSecondaryBgColor = UIColor(hex: theme.secondaryBackgroundColor.dark) ?? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        
        lightCellBgColor = UIColor(hex: theme.cellBackgroundColor.light) ?? UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
        darkCellBgColor = UIColor(hex: theme.cellBackgroundColor.dark) ?? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
        
        lightCellBorderColor = UIColor(hex: theme.cellBorderColor.light) ?? UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0)
        darkCellBorderColor = UIColor(hex: theme.cellBorderColor.dark) ?? UIColor(red: 0.25, green: 0.52, blue: 0.28, alpha: 1.0)
        
        lightPrimaryTextColor = UIColor(hex: theme.primaryTextColor.light) ?? .black
        darkPrimaryTextColor = UIColor(hex: theme.primaryTextColor.dark) ?? .white
        
        lightSecondaryTextColor = UIColor(hex: theme.secondaryTextColor.light) ?? .darkGray
        darkSecondaryTextColor = UIColor(hex: theme.secondaryTextColor.dark) ?? .lightGray
        
        lightGreentextColor = UIColor(hex: theme.greentextColor.light) ?? UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
        darkGreentextColor = UIColor(hex: theme.greentextColor.dark) ?? UIColor(red: 140/255, green: 183/255, blue: 54/255, alpha: 1.0)
        
        lightAlertColor = UIColor(hex: theme.alertColor.light) ?? .systemRed
        darkAlertColor = UIColor(hex: theme.alertColor.dark) ?? .systemRed
        
        lightSpoilerTextColor = UIColor(hex: theme.spoilerTextColor.light) ?? .black
        darkSpoilerTextColor = UIColor(hex: theme.spoilerTextColor.dark) ?? .white
        
        lightSpoilerBgColor = UIColor(hex: theme.spoilerBackgroundColor.light) ?? .black
        darkSpoilerBgColor = UIColor(hex: theme.spoilerBackgroundColor.dark) ?? .darkGray
    }
    
    // MARK: - Action Handlers
    @objc private func saveTapped() {
        guard !themeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(
                title: "Invalid Name",
                message: "Please enter a valid theme name",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let theme = Theme(
            id: editingTheme?.id ?? ThemeManager.shared.generateUniqueThemeId(),
            name: themeName,
            isBuiltIn: false,
            backgroundColor: ColorSet(
                light: lightBackgroundColor.hexString,
                dark: darkBackgroundColor.hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: lightSecondaryBgColor.hexString,
                dark: darkSecondaryBgColor.hexString
            ),
            cellBackgroundColor: ColorSet(
                light: lightCellBgColor.hexString,
                dark: darkCellBgColor.hexString
            ),
            cellBorderColor: ColorSet(
                light: lightCellBorderColor.hexString,
                dark: darkCellBorderColor.hexString
            ),
            primaryTextColor: ColorSet(
                light: lightPrimaryTextColor.hexString,
                dark: darkPrimaryTextColor.hexString
            ),
            secondaryTextColor: ColorSet(
                light: lightSecondaryTextColor.hexString,
                dark: darkSecondaryTextColor.hexString
            ),
            greentextColor: ColorSet(
                light: lightGreentextColor.hexString,
                dark: darkGreentextColor.hexString
            ),
            alertColor: ColorSet(
                light: lightAlertColor.hexString,
                dark: darkAlertColor.hexString
            ),
            spoilerTextColor: ColorSet(
                light: lightSpoilerTextColor.hexString,
                dark: darkSpoilerTextColor.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: lightSpoilerBgColor.hexString,
                dark: darkSpoilerBgColor.hexString
            )
        )
        
        if editingTheme != nil {
            ThemeManager.shared.updateCustomTheme(theme)
        } else {
            ThemeManager.shared.addCustomTheme(theme)
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .themeInfo:
            return 1
        case .backgroundColors:
            return BackgroundColorRow.allCases.count
        case .cellColors:
            return CellColorRow.allCases.count
        case .textColors:
            return TextColorRow.allCases.count
        case .specialColors:
            return SpecialColorRow.allCases.count
        case .spoilerColors:
            return SpoilerColorRow.allCases.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .themeInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: "NameCell", for: indexPath) as! NameCell
            cell.configure(name: themeName) { [weak self] newName in
                self?.themeName = newName
                self?.isDirty = true
            }
            return cell
            
        case .backgroundColors:
            guard let row = BackgroundColorRow(rawValue: indexPath.row) else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ColorCell", for: indexPath) as! ColorCell
            
            switch row {
            case .background:
                cell.configure(
                    title: "Background",
                    lightColor: lightBackgroundColor,
                    darkColor: darkBackgroundColor
                ) { [weak self] light, dark in
                    self?.lightBackgroundColor = light
                    self?.darkBackgroundColor = dark
                    self?.isDirty = true
                }
            case .secondaryBackground:
                cell.configure(
                    title: "Secondary Background",
                    lightColor: lightSecondaryBgColor,
                    darkColor: darkSecondaryBgColor
                ) { [weak self] light, dark in
                    self?.lightSecondaryBgColor = light
                    self?.darkSecondaryBgColor = dark
                    self?.isDirty = true
                }
            }
            
            return cell
            
        case .cellColors:
            guard let row = CellColorRow(rawValue: indexPath.row) else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ColorCell", for: indexPath) as! ColorCell
            
            switch row {
            case .cellBackground:
                cell.configure(
                    title: "Cell Background",
                    lightColor: lightCellBgColor,
                    darkColor: darkCellBgColor
                ) { [weak self] light, dark in
                    self?.lightCellBgColor = light
                    self?.darkCellBgColor = dark
                    self?.isDirty = true
                }
            case .cellBorder:
                cell.configure(
                    title: "Cell Border",
                    lightColor: lightCellBorderColor,
                    darkColor: darkCellBorderColor
                ) { [weak self] light, dark in
                    self?.lightCellBorderColor = light
                    self?.darkCellBorderColor = dark
                    self?.isDirty = true
                }
            }
            
            return cell
            
        case .textColors:
            guard let row = TextColorRow(rawValue: indexPath.row) else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ColorCell", for: indexPath) as! ColorCell
            
            switch row {
            case .primaryText:
                cell.configure(
                    title: "Primary Text",
                    lightColor: lightPrimaryTextColor,
                    darkColor: darkPrimaryTextColor
                ) { [weak self] light, dark in
                    self?.lightPrimaryTextColor = light
                    self?.darkPrimaryTextColor = dark
                    self?.isDirty = true
                }
            case .secondaryText:
                cell.configure(
                    title: "Secondary Text",
                    lightColor: lightSecondaryTextColor,
                    darkColor: darkSecondaryTextColor
                ) { [weak self] light, dark in
                    self?.lightSecondaryTextColor = light
                    self?.darkSecondaryTextColor = dark
                    self?.isDirty = true
                }
            }
            
            return cell
            
        case .specialColors:
            guard let row = SpecialColorRow(rawValue: indexPath.row) else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ColorCell", for: indexPath) as! ColorCell
            
            switch row {
            case .greentext:
                cell.configure(
                    title: "Greentext",
                    lightColor: lightGreentextColor,
                    darkColor: darkGreentextColor
                ) { [weak self] light, dark in
                    self?.lightGreentextColor = light
                    self?.darkGreentextColor = dark
                    self?.isDirty = true
                }
            case .alert:
                cell.configure(
                    title: "Alert",
                    lightColor: lightAlertColor,
                    darkColor: darkAlertColor
                ) { [weak self] light, dark in
                    self?.lightAlertColor = light
                    self?.darkAlertColor = dark
                    self?.isDirty = true
                }
            }
            
            return cell
            
        case .spoilerColors:
            guard let row = SpoilerColorRow(rawValue: indexPath.row) else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ColorCell", for: indexPath) as! ColorCell
            
            switch row {
            case .spoilerText:
                cell.configure(
                    title: "Spoiler Text",
                    lightColor: lightSpoilerTextColor,
                    darkColor: darkSpoilerTextColor
                ) { [weak self] light, dark in
                    self?.lightSpoilerTextColor = light
                    self?.darkSpoilerTextColor = dark
                    self?.isDirty = true
                }
            case .spoilerBackground:
                cell.configure(
                    title: "Spoiler Background",
                    lightColor: lightSpoilerBgColor,
                    darkColor: darkSpoilerBgColor
                ) { [weak self] light, dark in
                    self?.lightSpoilerBgColor = light
                    self?.darkSpoilerBgColor = dark
                    self?.isDirty = true
                }
            }
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        
        switch section {
        case .themeInfo:
            return "Theme Information"
        case .backgroundColors:
            return "Background Colors"
        case .cellColors:
            return "Cell Colors"
        case .textColors:
            return "Text Colors"
        case .specialColors:
            return "Special Colors"
        case .spoilerColors:
            return "Spoiler Colors"
        }
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 44 }
        
        switch section {
        case .themeInfo:
            return 60
        default:
            return 100
        }
    }
}

// MARK: - NameCell
class NameCell: UITableViewCell {
    
    private let nameLabel = UILabel()
    private let nameTextField = UITextField()
    private var nameChanged: ((String) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Name Label
        nameLabel.text = "Theme Name"
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // Name TextField
        nameTextField.placeholder = "Enter theme name"
        nameTextField.font = UIFont.systemFont(ofSize: 16)
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        contentView.addSubview(nameTextField)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.widthAnchor.constraint(equalToConstant: 120),
            
            nameTextField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameTextField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    func configure(name: String, nameChanged: @escaping (String) -> Void) {
        nameTextField.text = name
        self.nameChanged = nameChanged
    }
    
    @objc private func textFieldDidChange() {
        nameChanged?(nameTextField.text ?? "")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameTextField.text = nil
        nameChanged = nil
    }
}

// MARK: - ColorCell
class ColorCell: UITableViewCell {
    
    private let titleLabel = UILabel()
    private let lightModeLabel = UILabel()
    private let darkModeLabel = UILabel()
    private let lightColorView = UIView()
    private let darkColorView = UIView()
    
    private var lightColor: UIColor = .white
    private var darkColor: UIColor = .black
    private var colorsChanged: ((UIColor, UIColor) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Title Label
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Light Mode Label
        lightModeLabel.text = "Light"
        lightModeLabel.font = UIFont.systemFont(ofSize: 14)
        lightModeLabel.textColor = .secondaryLabel
        lightModeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lightModeLabel)
        
        // Dark Mode Label
        darkModeLabel.text = "Dark"
        darkModeLabel.font = UIFont.systemFont(ofSize: 14)
        darkModeLabel.textColor = .secondaryLabel
        darkModeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(darkModeLabel)
        
        // Light Color View
        lightColorView.translatesAutoresizingMaskIntoConstraints = false
        lightColorView.layer.cornerRadius = 6
        lightColorView.layer.borderWidth = 1
        lightColorView.layer.borderColor = UIColor.lightGray.cgColor
        lightColorView.isUserInteractionEnabled = true
        lightColorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(lightColorViewTapped)))
        contentView.addSubview(lightColorView)
        
        // Dark Color View
        darkColorView.translatesAutoresizingMaskIntoConstraints = false
        darkColorView.layer.cornerRadius = 6
        darkColorView.layer.borderWidth = 1
        darkColorView.layer.borderColor = UIColor.lightGray.cgColor
        darkColorView.isUserInteractionEnabled = true
        darkColorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(darkColorViewTapped)))
        contentView.addSubview(darkColorView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            lightModeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            lightModeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            darkModeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            darkModeLabel.leadingAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            lightColorView.topAnchor.constraint(equalTo: lightModeLabel.bottomAnchor, constant: 4),
            lightColorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            lightColorView.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -16),
            lightColorView.heightAnchor.constraint(equalToConstant: 32),
            
            darkColorView.topAnchor.constraint(equalTo: darkModeLabel.bottomAnchor, constant: 4),
            darkColorView.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 8),
            darkColorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            darkColorView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    func configure(
        title: String,
        lightColor: UIColor,
        darkColor: UIColor,
        colorsChanged: @escaping (UIColor, UIColor) -> Void
    ) {
        titleLabel.text = title
        self.lightColor = lightColor
        self.darkColor = darkColor
        self.colorsChanged = colorsChanged
        
        lightColorView.backgroundColor = lightColor
        darkColorView.backgroundColor = darkColor
    }
    
    @objc private func lightColorViewTapped() {
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = lightColor
        colorPicker.delegate = self
        colorPicker.modalPresentationStyle = .popover
        colorPicker.supportsAlpha = false
        colorPicker.title = "Light Mode Color"
        
        // Store a reference to which color we're editing
        objc_setAssociatedObject(colorPicker, &AssociatedKeys.isLightMode, true, .OBJC_ASSOCIATION_RETAIN)
        
        if let viewController = findViewController() {
            viewController.present(colorPicker, animated: true)
        }
    }
    
    @objc private func darkColorViewTapped() {
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = darkColor
        colorPicker.delegate = self
        colorPicker.modalPresentationStyle = .popover
        colorPicker.supportsAlpha = false
        colorPicker.title = "Dark Mode Color"
        
        // Store a reference to which color we're editing
        objc_setAssociatedObject(colorPicker, &AssociatedKeys.isLightMode, false, .OBJC_ASSOCIATION_RETAIN)
        
        if let viewController = findViewController() {
            viewController.present(colorPicker, animated: true)
        }
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder?.next
            if let viewController = responder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        lightColorView.backgroundColor = .white
        darkColorView.backgroundColor = .black
        colorsChanged = nil
    }
}

// MARK: - UIColorPickerViewControllerDelegate
extension ColorCell: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor
        let isLightMode = objc_getAssociatedObject(viewController, &AssociatedKeys.isLightMode) as? Bool ?? true
        
        if isLightMode {
            lightColor = selectedColor
            lightColorView.backgroundColor = selectedColor
        } else {
            darkColor = selectedColor
            darkColorView.backgroundColor = selectedColor
        }
        
        colorsChanged?(lightColor, darkColor)
    }
    
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        // This is called when the user selects a color, but we'll update when they're done
    }
}

// MARK: - Associated Keys for UIColorPickerViewController
private struct AssociatedKeys {
    static var isLightMode = "isLightMode"
}