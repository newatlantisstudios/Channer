import UIKit
import ffmpegkit

class FilesListVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var files: [URL] = []
    var currentDirectory: URL
    let tableView = UITableView()
    
    init(directory: URL? = nil) {
        self.currentDirectory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        self.navigationItem.title = "Files"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "fileCell")
        tableView.frame = view.bounds
        view.addSubview(tableView)
        
        loadFiles()
    }
    
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCell", for: indexPath)
        let fileURL = files[indexPath.row]
        
        cell.textLabel?.text = fileURL.lastPathComponent
        cell.accessoryType = fileURL.hasDirectoryPath ? .disclosureIndicator : .none
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedURL = files[indexPath.row]
        
        if selectedURL.hasDirectoryPath {
            if selectedURL.lastPathComponent.lowercased() == "images" {
                // Push a thumbnail grid for image files
                let imageGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["jpg", "jpeg", "png"])
                navigationController?.pushViewController(imageGalleryVC, animated: true)
            } else if selectedURL.lastPathComponent.lowercased() == "webm" {
                // Push a thumbnail grid for webm files
                let webmGalleryVC = ThumbnailGridVC(directory: selectedURL, fileTypes: ["webm"])
                navigationController?.pushViewController(webmGalleryVC, animated: true)
            } else {
                // For other directories, push FilesListVC to continue exploring
                let filesListVC = FilesListVC(directory: selectedURL)
                navigationController?.pushViewController(filesListVC, animated: true)
            }
        }
    }
}
