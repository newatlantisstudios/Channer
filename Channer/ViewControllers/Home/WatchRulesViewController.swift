import UIKit

class WatchRulesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private enum Section: Int, CaseIterable {
        case global
        case keyword
        case posterId
        case fileHash

        var title: String {
            switch self {
            case .global:
                return "Global Settings"
            case .keyword:
                return "Keyword Watches"
            case .posterId:
                return "Poster ID Watches"
            case .fileHash:
                return "File Hash Watches"
            }
        }
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let emptyStateLabel = UILabel()

    private var rules: [WatchRule] = []
    private let watchRulesManager = WatchRulesManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Watch Rules"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        setupTableView()
        setupEmptyStateLabel()
        loadRules()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRuleTapped)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(watchRulesDidChange),
            name: .watchRulesDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyStateLabel() {
        emptyStateLabel.text = "No watch rules yet.\nTap + to add one."
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .gray
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16)
        emptyStateLabel.numberOfLines = 0
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

    // MARK: - Data

    private func loadRules() {
        rules = watchRulesManager.getRules()
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !rules.isEmpty
    }

    private func rules(for section: Section) -> [WatchRule] {
        switch section {
        case .global:
            return []
        case .keyword:
            return rules.filter { $0.type == .keyword }
        case .posterId:
            return rules.filter { $0.type == .posterId }
        case .fileHash:
            return rules.filter { $0.type == .fileHash }
        }
    }

    // MARK: - Actions

    @objc private func watchRulesDidChange() {
        loadRules()
    }

    @objc private func addRuleTapped() {
        let alert = UIAlertController(title: "Add Watch Rule", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Keyword", style: .default, handler: { _ in
            self.showAddRulePrompt(type: .keyword)
        }))

        alert.addAction(UIAlertAction(title: "Poster ID", style: .default, handler: { _ in
            self.showAddRulePrompt(type: .posterId)
        }))

        alert.addAction(UIAlertAction(title: "File Hash", style: .default, handler: { _ in
            self.showAddRulePrompt(type: .fileHash)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func showAddRulePrompt(type: WatchRuleType) {
        let alert = UIAlertController(
            title: "Add \(type.displayName) Watch",
            message: type.description,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Enter \(type.displayName.lowercased())"
            textField.autocapitalizationType = .none
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            guard let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                return
            }

            let isCaseSensitive = type == .fileHash
            let added = self.watchRulesManager.addRule(type: type, value: value, isCaseSensitive: isCaseSensitive)
            if !added {
                self.showInfoAlert(title: "Already Watching", message: "That rule already exists.")
            }
        }))

        present(alert, animated: true)
    }

    private func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentRuleActions(for rule: WatchRule, from cell: UITableViewCell) {
        let alert = UIAlertController(title: rule.displayName, message: nil, preferredStyle: .actionSheet)

        let toggleTitle = rule.isEnabled ? "Disable" : "Enable"
        alert.addAction(UIAlertAction(title: toggleTitle, style: .default, handler: { _ in
            self.watchRulesManager.toggleRuleEnabled(id: rule.id)
        }))

        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            self.showEditRulePrompt(rule: rule)
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.watchRulesManager.removeRule(id: rule.id)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }

    private func showEditRulePrompt(rule: WatchRule) {
        let alert = UIAlertController(
            title: "Edit \(rule.type.displayName)",
            message: nil,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.text = rule.value
            textField.autocapitalizationType = .none
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            guard let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                return
            }

            let updated = self.watchRulesManager.updateRuleValue(id: rule.id, newValue: value)
            if !updated {
                self.showInfoAlert(title: "Update Failed", message: "That value already exists.")
            }
        }))

        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .global:
            return 1
        case .keyword, .posterId, .fileHash:
            return rules(for: sectionType).count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sectionType {
        case .global:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "WatchRuleGlobalCell")
            cell.textLabel?.text = "Enable Watch Rules"
            cell.backgroundColor = .clear
            cell.selectionStyle = .none

            let toggle = UISwitch()
            toggle.isOn = watchRulesManager.isWatchRulesEnabled()
            toggle.addTarget(self, action: #selector(toggleGlobalEnabled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            return cell

        case .keyword, .posterId, .fileHash:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "WatchRuleCell")
            let sectionRules = rules(for: sectionType)
            guard indexPath.row < sectionRules.count else { return cell }
            let rule = sectionRules[indexPath.row]

            cell.textLabel?.text = rule.displayName
            cell.textLabel?.textColor = rule.isEnabled ? ThemeManager.shared.primaryTextColor : .systemGray
            cell.detailTextLabel?.text = rule.isEnabled ? "Enabled" : "Disabled"
            cell.detailTextLabel?.textColor = .systemGray
            cell.backgroundColor = .clear
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    @objc private func toggleGlobalEnabled(_ sender: UISwitch) {
        watchRulesManager.setWatchRulesEnabled(sender.isOn)
        loadRules()
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .global:
            return "Notifications are throttled to once every \(WatchRulesManager.defaultThrottleMinutes) minutes per rule."
        case .keyword:
            return "Matches check post text within threads you visit or favorite."
        case .posterId:
            return "Use poster IDs from post info or long-press actions."
        case .fileHash:
            return "File hashes are sourced from image posts (md5)."
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        switch sectionType {
        case .global:
            return
        case .keyword, .posterId, .fileHash:
            let sectionRules = rules(for: sectionType)
            guard indexPath.row < sectionRules.count,
                  let cell = tableView.cellForRow(at: indexPath) else { return }
            presentRuleActions(for: sectionRules[indexPath.row], from: cell)
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        guard let sectionType = Section(rawValue: indexPath.section), sectionType != .global else { return }
        let sectionRules = rules(for: sectionType)
        guard indexPath.row < sectionRules.count else { return }
        watchRulesManager.removeRule(id: sectionRules[indexPath.row].id)
    }
}
