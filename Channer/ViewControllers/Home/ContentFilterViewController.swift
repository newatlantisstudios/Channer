import UIKit

class ContentFilterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    private let tableView = UITableView(style: .grouped)
    private let emptyStateLabel = UILabel()
    private let headerView = UIView()
    private let filterEnabledSwitch = UISwitch()
    
    private var keywordFilters: [String] = []
    private var posterFilters: [String] = []
    private var imageFilters: [String] = []
    
    // ContentFilterManager instance
    private let contentFilterManager = ContentFilterManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Content Filtering"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Setup UI
        setupTableView()
        setupEmptyStateLabel()
        loadFilters()
        
        // Add button to add new filter
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, 
            target: self, 
            action: #selector(addFilterTapped)
        )
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FilterCell")
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
        emptyStateLabel.text = "No filters added yet.\nTap + to add content filters."
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
    
    // MARK: - Data Management
    private func loadFilters() {
        // Get all filters from ContentFilterManager
        let filters = contentFilterManager.getAllFilters()
        
        // Update local filter arrays
        keywordFilters = filters.keywords
        posterFilters = filters.posters
        imageFilters = filters.images
        
        updateEmptyState()
        tableView.reloadData()
    }
    
    private func saveFilters() {
        // No need to manually save to UserDefaults, the ContentFilterManager 
        // methods will handle saving when we add/remove filters
    }
    
    private func updateEmptyState() {
        let hasAnyFilters = !keywordFilters.isEmpty || !posterFilters.isEmpty || !imageFilters.isEmpty
        emptyStateLabel.isHidden = hasAnyFilters
    }
    
    // MARK: - Actions
    @objc private func addFilterTapped() {
        let alertController = UIAlertController(
            title: "Add Filter",
            message: "Choose filter type to add",
            preferredStyle: .actionSheet
        )
        
        // Action for content keyword filter
        alertController.addAction(UIAlertAction(title: "Content Keyword", style: .default) { [weak self] _ in
            self?.showAddFilterAlert(type: "Content Keyword")
        })
        
        // Action for poster ID filter
        alertController.addAction(UIAlertAction(title: "Poster ID", style: .default) { [weak self] _ in
            self?.showAddFilterAlert(type: "Poster ID")
        })
        
        // Action for image name filter
        alertController.addAction(UIAlertAction(title: "Image Name", style: .default) { [weak self] _ in
            self?.showAddFilterAlert(type: "Image Name")
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    private func showAddFilterAlert(type: String) {
        let alertController = UIAlertController(
            title: "Add \(type) Filter",
            message: "Enter the text to filter. Posts containing this text will be hidden.",
            preferredStyle: .alert
        )
        
        // Add text field
        alertController.addTextField { textField in
            textField.placeholder = "Filter text..."
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        // Add action
        alertController.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let filterText = alertController.textFields?.first?.text,
                  !filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            self.addFilter(type: type, text: filterText.trimmingCharacters(in: .whitespacesAndNewlines))
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    private func addFilter(type: String, text: String) {
        var success = false
        
        switch type {
        case "Content Keyword":
            success = contentFilterManager.addKeywordFilter(text)
        case "Poster ID":
            success = contentFilterManager.addPosterFilter(text)
        case "Image Name":
            success = contentFilterManager.addImageFilter(text)
        default:
            return
        }
        
        if success {
            // Reload the filters from the manager to ensure UI is in sync
            loadFilters()
        }
    }
    
    @objc private func toggleFilteringEnabled(_ sender: UISwitch) {
        // Use ContentFilterManager to set filter enabled state
        contentFilterManager.setFilteringEnabled(sender.isOn)
        
        // Show confirmation
        let message = sender.isOn ? "Content filtering enabled" : "Content filtering disabled"
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Dismiss the alert after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5 // Master switch section + Advanced filters + 3 filter types
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2 // Master switch row + Advanced filters link
        case 1:
            return keywordFilters.count
        case 2:
            return posterFilters.count
        case 3:
            return imageFilters.count
        case 4:
            return 1 // Statistics row
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterCell", for: indexPath)

        cell.accessoryType = .none
        cell.accessoryView = nil
        cell.selectionStyle = .default
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                // Master filter switch
                cell.textLabel?.text = "Enable Content Filtering"
                cell.selectionStyle = .none

                // Create switch for the cell
                let filterSwitch = UISwitch()
                filterSwitch.isOn = contentFilterManager.isFilteringEnabled()
                filterSwitch.addTarget(self, action: #selector(toggleFilteringEnabled(_:)), for: .valueChanged)
                cell.accessoryView = filterSwitch
            } else {
                // Advanced Filters link
                cell.textLabel?.text = "Advanced Filters"
                cell.accessoryType = .disclosureIndicator

                // Show count of advanced filters
                let advancedCount = contentFilterManager.getAdvancedFilters().count
                if advancedCount > 0 {
                    let badge = UILabel()
                    badge.text = "\(advancedCount)"
                    badge.font = UIFont.systemFont(ofSize: 14)
                    badge.textColor = .white
                    badge.backgroundColor = .systemBlue
                    badge.textAlignment = .center
                    badge.layer.cornerRadius = 10
                    badge.clipsToBounds = true
                    badge.frame = CGSize(width: 24, height: 20).applying(.identity) as! CGRect
                    badge.sizeToFit()
                    badge.frame.size.width = max(badge.frame.size.width + 12, 24)
                    badge.frame.size.height = 20
                }
            }

        case 1:
            // Keyword filters
            if indexPath.row < keywordFilters.count {
                cell.textLabel?.text = keywordFilters[indexPath.row]
            }
            cell.accessoryType = .detailDisclosureButton

        case 2:
            // Poster ID filters
            if indexPath.row < posterFilters.count {
                cell.textLabel?.text = posterFilters[indexPath.row]
            }
            cell.accessoryType = .detailDisclosureButton

        case 3:
            // Image name filters
            if indexPath.row < imageFilters.count {
                cell.textLabel?.text = imageFilters[indexPath.row]
            }
            cell.accessoryType = .detailDisclosureButton

        case 4:
            // Statistics
            let stats = contentFilterManager.getFilterStatistics()
            let legacyFilters = contentFilterManager.getAllFilters()
            let legacyCount = legacyFilters.keywords.count + legacyFilters.posters.count + legacyFilters.images.count

            cell.textLabel?.text = "Total Filters: \(legacyCount + stats.total) (\(stats.enabled) enabled)"
            cell.textLabel?.textColor = ThemeManager.shared.secondaryTextColor
            cell.selectionStyle = .none

        default:
            break
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Global Settings"
        case 1:
            return "Content Keyword Filters"
        case 2:
            return "Poster ID Filters"
        case 3:
            return "Image Name Filters"
        case 4:
            return "Statistics"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Toggle to enable or disable all content filtering globally. Use Advanced Filters for regex, file type, country, trip code, and time-based filtering."
        case 1:
            return "Filters posts containing specific text or keywords."
        case 2:
            return "Filters posts from specific poster IDs."
        case 3:
            return "Filters posts containing images with specific filenames."
        case 4:
            return nil
        default:
            return nil
        }
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Handle global settings section
        if indexPath.section == 0 {
            if indexPath.row == 1 {
                // Navigate to Advanced Filters
                let advancedVC = AdvancedFilterViewController()
                navigationController?.pushViewController(advancedVC, animated: true)
            }
            return
        }

        // Skip statistics section
        if indexPath.section == 4 {
            return
        }
        
        // Get filter based on section and row
        var filterType = ""
        var filterText = ""
        var filterArray: [String] = []
        
        switch indexPath.section {
        case 1:
            filterType = "Content Keyword"
            if indexPath.row < keywordFilters.count {
                filterText = keywordFilters[indexPath.row]
                filterArray = keywordFilters
            }
        case 2:
            filterType = "Poster ID"
            if indexPath.row < posterFilters.count {
                filterText = posterFilters[indexPath.row]
                filterArray = posterFilters
            }
        case 3:
            filterType = "Image Name"
            if indexPath.row < imageFilters.count {
                filterText = imageFilters[indexPath.row]
                filterArray = imageFilters
            }
        default:
            return
        }
        
        // Show edit/delete options
        let alertController = UIAlertController(
            title: "Manage Filter",
            message: "\"\(filterText)\"",
            preferredStyle: .actionSheet
        )
        
        // Edit action
        alertController.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.showEditFilterAlert(type: filterType, text: filterText, indexPath: indexPath)
        })
        
        // Delete action
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.showDeleteFilterConfirmation(type: filterType, text: filterText, indexPath: indexPath)
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Called when the detail disclosure button is tapped
        // Reuse the selection handler for simplicity
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    // MARK: - Filter Management
    private func showEditFilterAlert(type: String, text: String, indexPath: IndexPath) {
        let alertController = UIAlertController(
            title: "Edit \(type) Filter",
            message: "Update the filter text",
            preferredStyle: .alert
        )
        
        // Add text field with current value
        alertController.addTextField { textField in
            textField.text = text
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        // Update action
        alertController.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            guard let self = self,
                  let newText = alertController.textFields?.first?.text,
                  !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            self.updateFilter(type: type, oldText: text, newText: newText.trimmingCharacters(in: .whitespacesAndNewlines), indexPath: indexPath)
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    private func updateFilter(type: String, oldText: String, newText: String, indexPath: IndexPath) {
        // Since ContentFilterManager doesn't have direct update methods,
        // we'll need to remove the old filter and add the new one
        
        switch type {
        case "Content Keyword":
            contentFilterManager.removeKeywordFilter(oldText)
            contentFilterManager.addKeywordFilter(newText)
        case "Poster ID":
            contentFilterManager.removePosterFilter(oldText)
            contentFilterManager.addPosterFilter(newText)
        case "Image Name":
            contentFilterManager.removeImageFilter(oldText)
            contentFilterManager.addImageFilter(newText)
        default:
            return
        }
        
        // Reload the filters from the manager to ensure UI is in sync
        loadFilters()
    }
    
    private func showDeleteFilterConfirmation(type: String, text: String, indexPath: IndexPath) {
        let alertController = UIAlertController(
            title: "Delete Filter",
            message: "Are you sure you want to delete this filter?\n\"\(text)\"",
            preferredStyle: .alert
        )
        
        // Delete action
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteFilter(type: type, text: text, indexPath: indexPath)
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        present(alertController, animated: true)
    }
    
    private func deleteFilter(type: String, text: String, indexPath: IndexPath) {
        var success = false
        
        switch type {
        case "Content Keyword":
            success = contentFilterManager.removeKeywordFilter(text)
        case "Poster ID":
            success = contentFilterManager.removePosterFilter(text)
        case "Image Name":
            success = contentFilterManager.removeImageFilter(text)
        default:
            return
        }
        
        if success {
            // Reload the filters from the manager to ensure UI is in sync
            loadFilters()
            
            // Update UI
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Reload section if there are no more rows
            switch indexPath.section {
            case 1:
                if keywordFilters.isEmpty {
                    tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                }
            case 2:
                if posterFilters.isEmpty {
                    tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
                }
            case 3:
                if imageFilters.isEmpty {
                    tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
                }
            default:
                break
            }
        }
    }
}