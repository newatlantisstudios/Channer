import UIKit
import VLCKit
import AVFoundation

class WebMViewController: UIViewController {
    var videoURL: String = ""
        var hideDownloadButton: Bool = false // New property to control download button visibility
        
        private lazy var videoView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .black
            return view
        }()
    
    private lazy var mediaPlayer: VLCMediaPlayer = {
        let player = VLCMediaPlayer()
        player.delegate = self
        player.drawable = videoView
        return player
    }()
    
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
    
    private func setupVideo() {
        guard let url = URL(string: videoURL) else { return }
        let media = VLCMedia(url: url)
        mediaPlayer.media = media
        mediaPlayer.play()
    }
    
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
    
    private func getWebMDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("webm", isDirectory: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - VLCMediaPlayerDelegate
extension WebMViewController: VLCMediaPlayerDelegate {
    
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
