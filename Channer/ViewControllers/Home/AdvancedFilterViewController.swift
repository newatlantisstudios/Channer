import UIKit

/// View controller for managing advanced content filters
/// Supports regex, file type, country flag, trip code, and time-based filters
class AdvancedFilterViewController: UIViewController {

    // MARK: - Properties
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateLabel = UILabel()
    private let contentFilterManager = ContentFilterManager.shared

    private var advancedFilters: [AdvancedFilter] = []

    // Section indices
    private enum Section: Int, CaseIterable {
        case globalSettings = 0
        case regexFilters
        case fileTypeFilters
        case countryFilters
        case tripCodeFilters
        case timeBasedFilters

        var title: String {
            switch self {
            case .globalSettings: return "Global Settings"
            case .regexFilters: return "Regex Filters"
            case .fileTypeFilters: return "File Type Filters"
            case .countryFilters: return "Country Flag Filters"
            case .tripCodeFilters: return "Trip Code Filters"
            case .timeBasedFilters: return "Time-Based Filters"
            }
        }

        var footer: String {
            switch self {
            case .globalSettings: return "Enable or disable all advanced filtering globally."
            case .regexFilters: return "Filter posts matching regular expression patterns."
            case .fileTypeFilters: return "Filter posts based on attachment type (videos, images, GIFs)."
            case .countryFilters: return "Filter posts by country flag. Use whitelist to only show specific countries."
            case .tripCodeFilters: return "Filter posts by trip code. Use whitelist to only show specific tripcodes."
            case .timeBasedFilters: return "Hide posts older than the specified time."
            }
        }

        var filterType: FilterType? {
            switch self {
            case .globalSettings: return nil
            case .regexFilters: return .regex
            case .fileTypeFilters: return .fileType
            case .countryFilters: return .countryFlag
            case .tripCodeFilters: return .tripCode
            case .timeBasedFilters: return .timeBased
            }
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Advanced Filters"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        setupTableView()
        setupEmptyStateLabel()
        setupNavigationItems()
        loadFilters()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(filtersDidChange),
            name: .advancedFiltersDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FilterCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
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
        emptyStateLabel.text = "No advanced filters added yet.\nTap + to add filters."
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

    private func setupNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addFilterTapped)
        )
    }

    // MARK: - Data

    private func loadFilters() {
        advancedFilters = contentFilterManager.getAdvancedFilters()
        updateEmptyState()
        tableView.reloadData()
    }

    @objc private func filtersDidChange() {
        loadFilters()
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !advancedFilters.isEmpty
    }

    private func filters(for section: Section) -> [AdvancedFilter] {
        guard let type = section.filterType else { return [] }
        return advancedFilters.filter { $0.filterType == type }
    }

    // MARK: - Actions

    @objc private func addFilterTapped() {
        let alert = UIAlertController(
            title: "Add Advanced Filter",
            message: "Choose the type of filter to add",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Regex Pattern", style: .default) { [weak self] _ in
            self?.showAddRegexFilter()
        })

        alert.addAction(UIAlertAction(title: "File Type", style: .default) { [weak self] _ in
            self?.showAddFileTypeFilter()
        })

        alert.addAction(UIAlertAction(title: "Country Flag", style: .default) { [weak self] _ in
            self?.showAddCountryFilter()
        })

        alert.addAction(UIAlertAction(title: "Trip Code", style: .default) { [weak self] _ in
            self?.showAddTripCodeFilter()
        })

        alert.addAction(UIAlertAction(title: "Time-Based", style: .default) { [weak self] _ in
            self?.showAddTimeBasedFilter()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    // MARK: - Add Filter Dialogs

    private func showAddRegexFilter() {
        let alert = UIAlertController(
            title: "Add Regex Filter",
            message: "Enter a regular expression pattern to filter",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Pattern (e.g., \\bword\\b)"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let pattern = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !pattern.isEmpty else { return }

            // Validate regex
            if !ContentFilterManager.shared.isValidRegex(pattern) {
                self?.showError("Invalid regex pattern")
                return
            }

            let filter = AdvancedFilter.regex(pattern)
            ContentFilterManager.shared.addAdvancedFilter(filter)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAddFileTypeFilter() {
        let alert = UIAlertController(
            title: "Add File Type Filter",
            message: "Choose which file types to filter",
            preferredStyle: .actionSheet
        )

        for filterType in FileTypeFilter.allCases {
            alert.addAction(UIAlertAction(title: filterType.displayName, style: .default) { _ in
                let filter = AdvancedFilter.fileType(filterType)
                ContentFilterManager.shared.addAdvancedFilter(filter)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func showAddCountryFilter() {
        let vc = CountryPickerViewController { [weak self] countryCode, mode in
            let filter = AdvancedFilter.countryFlag(countryCode, mode: mode)
            ContentFilterManager.shared.addAdvancedFilter(filter)
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAddTripCodeFilter() {
        let alert = UIAlertController(
            title: "Add Trip Code Filter",
            message: "Enter the trip code to filter",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Trip code (e.g., !abc123)"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        // Add mode selection
        let modeAlert = UIAlertController(
            title: "Filter Mode",
            message: "Choose how to apply this filter",
            preferredStyle: .actionSheet
        )

        modeAlert.addAction(UIAlertAction(title: "Hide Matching (Blacklist)", style: .default) { [weak self] _ in
            guard let tripCode = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !tripCode.isEmpty else { return }
            let filter = AdvancedFilter.tripCode(tripCode, mode: .blacklist)
            ContentFilterManager.shared.addAdvancedFilter(filter)
            self?.dismiss(animated: true)
        })

        modeAlert.addAction(UIAlertAction(title: "Show Only Matching (Whitelist)", style: .default) { [weak self] _ in
            guard let tripCode = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !tripCode.isEmpty else { return }
            let filter = AdvancedFilter.tripCode(tripCode, mode: .whitelist)
            ContentFilterManager.shared.addAdvancedFilter(filter)
            self?.dismiss(animated: true)
        })

        modeAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Next", style: .default) { [weak self] _ in
            if let popover = modeAlert.popoverPresentationController {
                popover.sourceView = self?.view
                popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            self?.present(modeAlert, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAddTimeBasedFilter() {
        let alert = UIAlertController(
            title: "Add Time-Based Filter",
            message: "Hide posts older than:",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Value (e.g., 24)"
            textField.keyboardType = .numberPad
        }

        // Unit selection
        let unitAlert = UIAlertController(
            title: "Select Time Unit",
            message: nil,
            preferredStyle: .actionSheet
        )

        for unit in TimeUnit.allCases {
            unitAlert.addAction(UIAlertAction(title: unit.displayName, style: .default) { [weak self] _ in
                guard let valueText = alert.textFields?.first?.text,
                      let value = Int(valueText), value > 0 else {
                    self?.showError("Please enter a valid number")
                    return
                }
                let filter = AdvancedFilter.timeBased(value: value, unit: unit)
                ContentFilterManager.shared.addAdvancedFilter(filter)
            })
        }

        unitAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Next", style: .default) { [weak self] _ in
            if let popover = unitAlert.popoverPresentationController {
                popover.sourceView = self?.view
                popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            self?.present(unitAlert, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Toggle Actions

    @objc private func toggleAdvancedFiltering(_ sender: UISwitch) {
        contentFilterManager.setAdvancedFilteringEnabled(sender.isOn)

        let message = sender.isOn ? "Advanced filtering enabled" : "Advanced filtering disabled"
        showBriefMessage(message)
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showBriefMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }

    private func deleteFilter(at indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section),
              section != .globalSettings else { return }

        let sectionFilters = filters(for: section)
        guard indexPath.row < sectionFilters.count else { return }

        let filter = sectionFilters[indexPath.row]
        contentFilterManager.removeAdvancedFilter(id: filter.id)
    }
}

// MARK: - UITableViewDataSource

extension AdvancedFilterViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        if sectionType == .globalSettings {
            return 1
        }

        return filters(for: sectionType).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        if section == .globalSettings {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Enable Advanced Filtering"
            cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
            cell.switchControl.isOn = contentFilterManager.isAdvancedFilteringEnabled()
            cell.switchControl.removeTarget(nil, action: nil, for: .valueChanged)
            cell.switchControl.addTarget(self, action: #selector(toggleAdvancedFiltering(_:)), for: .valueChanged)
            cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
            return cell
        }

        // Use subtitle style to show hit count in detailTextLabel
        let cell: UITableViewCell
        if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: "FilterCell") {
            cell = dequeuedCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "FilterCell")
        }

        let sectionFilters = filters(for: section)

        guard indexPath.row < sectionFilters.count else {
            return cell
        }

        let filter = sectionFilters[indexPath.row]

        cell.textLabel?.text = filter.displayName
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        cell.textLabel?.numberOfLines = 0

        // Show enabled/disabled state
        if filter.isEnabled {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
            cell.textLabel?.textColor = ThemeManager.shared.secondaryTextColor
        }

        // Add hit count detail
        if filter.hitCount > 0 {
            cell.detailTextLabel?.text = "Matched \(filter.hitCount) times"
            cell.detailTextLabel?.textColor = ThemeManager.shared.secondaryTextColor
        } else {
            cell.detailTextLabel?.text = nil
        }

        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        // Don't show header for empty sections (except global settings)
        if sectionType != .globalSettings && filters(for: sectionType).isEmpty {
            return nil
        }

        return sectionType.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        // Don't show footer for empty sections (except global settings)
        if sectionType != .globalSettings && filters(for: sectionType).isEmpty {
            return nil
        }

        return sectionType.footer
    }
}

// MARK: - UITableViewDelegate

extension AdvancedFilterViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section),
              section != .globalSettings else { return }

        let sectionFilters = filters(for: section)
        guard indexPath.row < sectionFilters.count else { return }

        let filter = sectionFilters[indexPath.row]

        let alert = UIAlertController(
            title: "Manage Filter",
            message: filter.displayName,
            preferredStyle: .actionSheet
        )

        let toggleTitle = filter.isEnabled ? "Disable" : "Enable"
        alert.addAction(UIAlertAction(title: toggleTitle, style: .default) { _ in
            ContentFilterManager.shared.toggleAdvancedFilter(id: filter.id)
        })

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDelete(filter: filter, at: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView.cellForRow(at: indexPath)
            popover.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    private func confirmDelete(filter: AdvancedFilter, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Filter",
            message: "Are you sure you want to delete this filter?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteFilter(at: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteFilter(at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else { return false }
        return section != .globalSettings
    }
}

// MARK: - Switch Cell

class SwitchTableViewCell: UITableViewCell {
    let switchControl = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryView = switchControl
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Country Picker View Controller

class CountryPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()
    private var filteredCountries: [(code: String, name: String)] = CountryCodes.common
    private var selectedMode: FilterMode = .blacklist
    private let onSelection: (String, FilterMode) -> Void

    init(onSelection: @escaping (String, FilterMode) -> Void) {
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Select Country"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        setupSearchBar()
        setupTableView()
        setupModeSelector()
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search countries..."
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
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CountryCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupModeSelector() {
        let segmentedControl = UISegmentedControl(items: ["Blacklist", "Whitelist"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        selectedMode = sender.selectedSegmentIndex == 0 ? .blacklist : .whitelist
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredCountries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CountryCell", for: indexPath)
        let country = filteredCountries[indexPath.row]

        let flag = CountryCodes.flag(for: country.code)
        cell.textLabel?.text = "\(flag) \(country.name) (\(country.code))"
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let country = filteredCountries[indexPath.row]
        onSelection(country.code, selectedMode)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredCountries = CountryCodes.common
        } else {
            filteredCountries = CountryCodes.common.filter { country in
                country.name.lowercased().contains(searchText.lowercased()) ||
                country.code.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
