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
            print("DEBUG: FilesListVC - Loaded \(files.count) files from directory: \(currentDirectory.path)")
            for (index, file) in files.enumerated() {
                print("DEBUG: FilesListVC - File \(index): \(file.lastPathComponent) (extension: \(file.pathExtension), isDirectory: \(file.hasDirectoryPath))")
            }
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
            
            print("DEBUG: FilesListVC - Selected file: \(selectedURL.lastPathComponent)")
            print("DEBUG: FilesListVC - File path: \(selectedURL.path)")
            print("DEBUG: FilesListVC - File extension: \(selectedURL.pathExtension.lowercased())")
            print("DEBUG: FilesListVC - Is directory: \(selectedURL.hasDirectoryPath)")
            print("DEBUG: FilesListVC - File exists: \(FileManager.default.fileExists(atPath: selectedURL.path))")
            
            if selectedURL.hasDirectoryPath {
                print("DEBUG: FilesListVC - Handling directory selection")
                if selectedURL.lastPathComponent.lowercased() == "images" {
                    print("DEBUG: FilesListVC - Opening Images directory with ThumbnailGridVC")
                    // Push a thumbnail grid for image files
                    let imageGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["jpg", "jpeg", "png"])
                    navigationController?.pushViewController(imageGalleryVC, animated: true)
                } else if selectedURL.lastPathComponent.lowercased() == "webm" {
                    print("DEBUG: FilesListVC - Opening WebM directory with ThumbnailGridVC")
                    // Push a thumbnail grid for webm files
                    let webmGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["webm"])
                    navigationController?.pushViewController(webmGalleryVC, animated: true)
                } else {
                    print("DEBUG: FilesListVC - Opening generic directory with FilesListVC")
                    // For other directories, push FilesListVC to continue exploring
                    let filesListVC = FilesListVC(directory: selectedURL)
                    navigationController?.pushViewController(filesListVC, animated: true)
                }
            } else {
                print("DEBUG: FilesListVC - Handling individual file selection")
                // Handle individual file selection
                let fileExtension = selectedURL.pathExtension.lowercased()
                
                if ["jpg", "jpeg", "png"].contains(fileExtension) {
                    print("DEBUG: FilesListVC - Opening image file with ImageViewController")
                    // Open image in ImageViewController
                    let imageViewController = ImageViewController(imageURL: selectedURL)
                    navigationController?.pushViewController(imageViewController, animated: true)
                } else if fileExtension == "gif" {
                    print("DEBUG: FilesListVC - Opening GIF file with urlWeb for animation support")
                    // Open GIF in urlWeb for animation support
                    let urlWebViewController = urlWeb()
                    urlWebViewController.images = [selectedURL]
                    urlWebViewController.currentIndex = 0
                    navigationController?.pushViewController(urlWebViewController, animated: true)
                } else if fileExtension == "webm" || fileExtension == "mp4" {
                    print("DEBUG: FilesListVC - Opening local video with VLCKit (WebMViewController)")
                    print("DEBUG: FilesListVC - Video URL: \(selectedURL.absoluteString)")
                    // Use VLCKit-only player for local video files
                    let vlcVC = WebMViewController()
                    vlcVC.videoURL = selectedURL.absoluteString
                    vlcVC.hideDownloadButton = true
                    navigationController?.pushViewController(vlcVC, animated: true)
                } else {
                    print("DEBUG: FilesListVC - Unsupported file type: \(fileExtension)")
                }
            }
        }
}
