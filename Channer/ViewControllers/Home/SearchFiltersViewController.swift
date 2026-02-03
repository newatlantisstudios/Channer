import UIKit

protocol SearchFiltersViewControllerDelegate: AnyObject {
    func searchFiltersViewController(_ controller: SearchFiltersViewController, didUpdate filters: SearchFilters)
}

final class SearchFiltersViewController: UITableViewController, UITextFieldDelegate {

    private enum Section: Int, CaseIterable {
        case images
        case replies
        case types
    }

    private var filters: SearchFilters
    private let originalFilters: SearchFilters

    weak var delegate: SearchFiltersViewControllerDelegate?

    private let requiresImagesSwitch = UISwitch()
    private let minRepliesField = UITextField()
    private let fileTypesField = UITextField()

    init(filters: SearchFilters) {
        self.filters = filters
        self.originalFilters = filters
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filters"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )

        requiresImagesSwitch.isOn = filters.requiresImages
        requiresImagesSwitch.addTarget(self, action: #selector(requiresImagesChanged), for: .valueChanged)

        minRepliesField.keyboardType = .numberPad
        minRepliesField.placeholder = "e.g. 10"
        minRepliesField.textAlignment = .right
        minRepliesField.delegate = self
        minRepliesField.addTarget(self, action: #selector(minRepliesChanged), for: .editingChanged)
        if let minReplies = filters.minReplies {
            minRepliesField.text = String(minReplies)
        }

        fileTypesField.autocapitalizationType = .none
        fileTypesField.autocorrectionType = .no
        fileTypesField.placeholder = "jpg,png,gif"
        fileTypesField.textAlignment = .right
        fileTypesField.delegate = self
        fileTypesField.addTarget(self, action: #selector(fileTypesChanged), for: .editingChanged)
        if !filters.fileTypes.isEmpty {
            fileTypesField.text = filters.fileTypes.joined(separator: ",")
        }

        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.register(SearchFiltersTextFieldCell.self, forCellReuseIdentifier: "SearchFiltersTextFieldCell")
    }

    @objc private func cancelTapped() {
        filters = originalFilters
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        delegate?.searchFiltersViewController(self, didUpdate: filters.normalized())
        dismiss(animated: true)
    }

    @objc private func requiresImagesChanged() {
        filters.requiresImages = requiresImagesSwitch.isOn
    }

    @objc private func minRepliesChanged() {
        let trimmed = minRepliesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            filters.minReplies = nil
            return
        }
        if let value = Int(trimmed), value > 0 {
            filters.minReplies = value
        } else {
            filters.minReplies = nil
        }
    }

    @objc private func fileTypesChanged() {
        let raw = fileTypesField.text ?? ""
        let parts = raw.split(separator: ",").map { String($0) }
        filters.fileTypes = parts
    }

    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .images:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
            cell.textLabel?.text = "Require Image"
            cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
            cell.selectionStyle = .none
            cell.accessoryView = requiresImagesSwitch
            return cell
        case .replies:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchFiltersTextFieldCell", for: indexPath) as! SearchFiltersTextFieldCell
            cell.configure(title: "Min Replies", placeholder: minRepliesField.placeholder ?? "", textField: minRepliesField)
            return cell
        case .types:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchFiltersTextFieldCell", for: indexPath) as! SearchFiltersTextFieldCell
            cell.configure(title: "File Types", placeholder: fileTypesField.placeholder ?? "", textField: fileTypesField)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .images:
            return nil
        case .replies:
            return "Filters threads by minimum reply count."
        case .types:
            return "Comma-separated extensions (e.g. jpg,png,gif,webm)."
        }
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

final class SearchFiltersTextFieldCell: UITableViewCell {

    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = ThemeManager.shared.cellBackgroundColor
        selectionStyle = .none

        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = ThemeManager.shared.primaryTextColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, placeholder: String, textField: UITextField) {
        titleLabel.text = title
        textField.placeholder = placeholder
        textField.textColor = ThemeManager.shared.primaryTextColor
        textField.translatesAutoresizingMaskIntoConstraints = false

        if textField.superview !== contentView {
            textField.removeFromSuperview()
            contentView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                textField.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
                textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                textField.heightAnchor.constraint(equalToConstant: 32)
            ])
            textField.setContentHuggingPriority(.required, for: .horizontal)
            textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }
}
