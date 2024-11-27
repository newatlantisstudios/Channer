import UIKit
import VLCKit
import AVFoundation

// MARK: - WebMViewController
/// A view controller responsible for playing and optionally downloading WebM videos.
class WebMViewController: UIViewController {
    
    // MARK: - Properties
    /// The URL string of the video to be played.
    var videoURL: String = ""
    /// A flag to control the visibility of the download button.
    var hideDownloadButton: Bool = false
    
    // MARK: - UI Elements
    /// The view that displays the video content.
    private lazy var videoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    /// The media player responsible for playing the video.
    private lazy var mediaPlayer: VLCMediaPlayer = {
        let player = VLCMediaPlayer()
        player.delegate = self
        player.drawable = videoView
        return player
    }()
    
    /// A label that indicates the video is downloading.
    private lazy var downloadingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Downloading..."
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle Methods
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideo()
        createWebMDirectory() // Ensure the directory exists
        
        if !hideDownloadButton {
            setupDownloadButton() // Add download button only if not hidden
        }
        
        // Set navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
    }

    /// Called just before the view controller is dismissed, covered, or otherwise hidden.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Reset navigation bar to default appearance when leaving this view controller
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true
    }
    
    // MARK: - Setup Methods
    /// Sets up the UI elements and layout constraints.
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(videoView)
        view.addSubview(downloadingLabel)
        
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            downloadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            downloadingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            downloadingLabel.widthAnchor.constraint(equalToConstant: 150),
            downloadingLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    /// Initializes the video player with the provided video URL.
    private func setupVideo() {
        guard let url = URL(string: videoURL) else { return }
        let media = VLCMedia(url: url)
        mediaPlayer.media = media
        mediaPlayer.play()
    }
    
    /// Adds the download button to the navigation bar if it's not hidden.
    private func setupDownloadButton() {
        let downloadButton = UIBarButtonItem(
            image: UIImage(named: "downloadWV")?.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(downloadVideo)
        )
        downloadButton.tintColor = .white
        navigationItem.rightBarButtonItem = downloadButton
    }
    
    /// Creates the directory for storing downloaded WebM files if it doesn't exist.
    private func createWebMDirectory() {
        let fileManager = FileManager.default
        let webmDirectory = getWebMDirectory()
        
        if !fileManager.fileExists(atPath: webmDirectory.path) {
            do {
                try fileManager.createDirectory(at: webmDirectory, withIntermediateDirectories: true)
                print("WebM directory created successfully")
            } catch {
                print("Error creating WebM directory: \(error)")
            }
        } else {
            print("WebM directory already exists")
        }
    }
    
    // MARK: - Download Methods
    /// Initiates the download of the video when the download button is tapped.
    @objc private func downloadVideo() {
        guard let sourceURL = URL(string: videoURL) else {
            showAlert(message: "Invalid video URL")
            return
        }
        
        let webmDir = getWebMDirectory()
        let filename = sourceURL.lastPathComponent
        let destinationURL = webmDir.appendingPathComponent(filename)
        
        Task {
            await download(url: sourceURL, to: destinationURL)
        }
    }
    
    /// Downloads the video from the given URL to the specified local URL.
    private func download(url: URL, to localUrl: URL) async {
        let request = URLRequest(url: url)
        
        do {
            let (tempLocalUrl, response) = try await URLSession.shared.download(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                showAlert(message: "Failed to download video")
                return
            }
            
            try FileManager.default.moveItem(at: tempLocalUrl, to: localUrl)
            showAlert(message: "WebM downloaded")
        } catch {
            showAlert(message: "Download failed: \(error.localizedDescription)")
        }
    }
    
    /// Returns the URL of the directory where WebM files are stored.
    private func getWebMDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("webm", isDirectory: true)
    }
    
    // MARK: - Helper Methods
    /// Displays an alert with the specified message.
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - VLCMediaPlayerDelegate
/// Extension to handle VLCMediaPlayer delegate methods.
extension WebMViewController: VLCMediaPlayerDelegate {
    
    /// Handles state changes of the media player.
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if let player = aNotification.object as? VLCMediaPlayer {
            switch player.state {
            case .stopped:
                print("Stopped")
            case .playing:
                print("Playing")
            case .error:
                print("Player error")
            case .opening:
                print("Opening")
            case .buffering:
                print("Buffering")
            case .paused:
                print("Paused")
            @unknown default:
                print("Unknown state")
            }
        }
    }
}
