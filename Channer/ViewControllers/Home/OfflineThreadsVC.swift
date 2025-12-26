import UIKit
import SwiftyJSON

class OfflineThreadsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    private let tableView = UITableView()
    private let emptyStateLabel = UILabel()
    private var cachedThreads: [CachedThread] = []
    private var threadInfo: [ThreadData] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Offline Threads"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        setupTableView()
        setupEmptyStateLabel()
        
        // Add Edit button to enable deletion mode
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditMode))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCachedThreads()
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OfflineThreadCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupEmptyStateLabel() {
        emptyStateLabel.text = "No threads saved for offline reading"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .gray
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16)
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
    
    // MARK: - Data Loading
    private func loadCachedThreads() {
        // Get cached threads from manager
        cachedThreads = ThreadCacheManager.shared.getAllCachedThreads()
        
        // Extract ThreadData info for each cached thread
        threadInfo = cachedThreads.compactMap { $0.getThreadInfo() }
        
        // Update UI based on whether we have cached threads
        emptyStateLabel.isHidden = !cachedThreads.isEmpty
        tableView.isHidden = cachedThreads.isEmpty
        
        // Reload table data
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func toggleEditMode() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        navigationItem.rightBarButtonItem?.title = tableView.isEditing ? "Done" : "Edit"
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return threadInfo.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OfflineThreadCell", for: indexPath)
        cell.selectionStyle = .none

        if indexPath.row < threadInfo.count {
            let thread = threadInfo[indexPath.row]
            
            // Configure cell
            var content = cell.defaultContentConfiguration()
            content.text = "/\(thread.boardAbv)/ - Thread #\(thread.number)"
            
            // Get the first line of the comment for a subtitle
            var commentPlainText = thread.comment
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            
            // Truncate to first line only
            if let newlineIndex = commentPlainText.firstIndex(of: "\n") {
                commentPlainText = String(commentPlainText[..<newlineIndex])
            }
            
            // Truncate long comments
            if commentPlainText.count > 100 {
                commentPlainText = String(commentPlainText.prefix(100)) + "..."
            }
            
            content.secondaryText = commentPlainText
            content.secondaryTextProperties.color = .gray
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 14)
            
            cell.contentConfiguration = content
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row < threadInfo.count {
            let thread = threadInfo[indexPath.row]
            let cachedThread = cachedThreads[indexPath.row]
            
            // Create thread view controller
            let threadVC = threadRepliesTV()
            threadVC.boardAbv = thread.boardAbv
            threadVC.threadNumber = thread.number
            
            // Navigate to thread
            navigationController?.pushViewController(threadVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Get the thread to delete
            let thread = threadInfo[indexPath.row]
            
            // Remove from cache via manager
            ThreadCacheManager.shared.removeFromCache(boardAbv: thread.boardAbv, threadNumber: thread.number)
            
            // Remove from local arrays
            threadInfo.remove(at: indexPath.row)
            cachedThreads.remove(at: indexPath.row)
            
            // Update table
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Show empty state if no more threads
            if cachedThreads.isEmpty {
                emptyStateLabel.isHidden = false
                tableView.isHidden = true
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
}