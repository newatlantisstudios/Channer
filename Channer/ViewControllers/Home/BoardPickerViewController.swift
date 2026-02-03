import UIKit

protocol BoardPickerViewControllerDelegate: AnyObject {
    func boardPickerViewController(_ controller: BoardPickerViewController, didSelect boardAbv: String?)
}

final class BoardPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    private let boards: [BoardInfo]
    private var filteredBoards: [BoardInfo]
    private var isSearching = false
    private var selectedBoard: String?

    weak var delegate: BoardPickerViewControllerDelegate?

    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(boards: [BoardInfo], selectedBoard: String?) {
        self.boards = boards
        self.filteredBoards = boards
        self.selectedBoard = selectedBoard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Board"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        setupSearchBar()
        setupTableView()
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func setupSearchBar() {
        searchBar.placeholder = "Search boards..."
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
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
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applySearchText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            filteredBoards = boards
            isSearching = false
        } else {
            let lower = trimmed.lowercased()
            filteredBoards = boards.filter { board in
                board.title.lowercased().contains(lower) || board.code.lowercased().contains(lower)
            }
            isSearching = true
        }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return filteredBoards.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BoardPickerCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "BoardPickerCell")
        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        cell.detailTextLabel?.textColor = .secondaryLabel

        if indexPath.section == 0 {
            cell.textLabel?.text = "All Boards"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = selectedBoard == nil ? .checkmark : .none
            return cell
        }

        let board = filteredBoards[indexPath.row]
        cell.textLabel?.text = board.title
        cell.detailTextLabel?.text = "/\(board.code)/"
        cell.accessoryType = (board.code == selectedBoard) ? .checkmark : .none
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            selectedBoard = nil
            delegate?.boardPickerViewController(self, didSelect: nil)
            dismiss(animated: true)
            return
        }

        let board = filteredBoards[indexPath.row]
        selectedBoard = board.code
        delegate?.boardPickerViewController(self, didSelect: board.code)
        dismiss(animated: true)
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applySearchText(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        applySearchText("")
    }
}
