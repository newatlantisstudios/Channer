import UIKit

class FilesListVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    /// An array to hold file URLs.
    var files: [URL] = []
    
    /// The current directory being displayed.
    var currentDirectory: URL
    
    /// The table view to display the list of files.
    let tableView = UITableView()
    
    // MARK: - Initializers
    /// Initializes the view controller with an optional directory.
    /// - Parameter directory: The directory to display. Defaults to the documents directory.
    init(directory: URL? = nil) {
        self.currentDirectory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Required initializer with coder. Not implemented.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad - FilesListVC")
        view.backgroundColor = .systemBackground
        self.navigationItem.title = "Files"
        
        // Remove custom back/home button to use navigation controller's default back button
        // The navigation controller will automatically show a back button with an arrow
        
        // Set up the table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "fileCell")
        tableView.frame = view.bounds
        view.addSubview(tableView)
        
        // Load files from the current directory
        loadFiles()
    }
    
    
    // MARK: - Data Loading
    /// Loads files from the current directory into the files array.
    func loadFiles() {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: nil)
            files = fileURLs.filter { !$0.lastPathComponent.hasPrefix(".") } // Filter out hidden files
            tableView.reloadData()
        } catch {
            print("Error loading files from directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UITableViewDataSource
    /// Returns the number of rows in the table view section.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    /// Configures and returns the cell for the given index path.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { 
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCell", for: indexPath)
        let fileURL = files[indexPath.row]
        
        cell.textLabel?.text = fileURL.lastPathComponent
        cell.accessoryType = fileURL.hasDirectoryPath ? .disclosureIndicator : .none
        return cell
    }
    
    // MARK: - UITableViewDelegate
    /// Handles the selection of a row in the table view.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            let selectedURL = files[indexPath.row]
            
            if selectedURL.hasDirectoryPath {
                if selectedURL.lastPathComponent.lowercased() == "images" {
                    // Push a thumbnail grid for image files
                    let imageGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["jpg", "jpeg", "png"])
                    let splitVC = self.splitViewController
                    splitVC?.showDetailViewController(imageGalleryVC, sender: self)
                } else if selectedURL.lastPathComponent.lowercased() == "webm" {
                    // Push a thumbnail grid for webm files
                    let webmGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["webm"])
                    let splitVC = self.splitViewController
                    splitVC?.showDetailViewController(webmGalleryVC, sender: self)
                } else {
                    // For other directories, push FilesListVC to continue exploring
                    let filesListVC = FilesListVC(directory: selectedURL)
                    let splitVC = self.splitViewController
                    splitVC?.showDetailViewController(filesListVC, sender: self)
                }
            }
        }
}
