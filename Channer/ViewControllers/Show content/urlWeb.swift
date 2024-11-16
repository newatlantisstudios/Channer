import UIKit
import WebKit
import VLCKit

class urlWeb: UIViewController {

    // MARK: - Properties
    var images: [URL] = []
    var currentIndex: Int = 0
    var enableSwipes: Bool = true // Property to enable or disable swipes

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

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

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
        setupNavigationBar()
        
        print("enableSwipes \(enableSwipes)")

        // Set navigation bar appearance to black
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white // Update button colors
        
        // Add swipe gestures only if enabled and there are multiple images
                if enableSwipes && images.count > 1 {
                    let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
                    swipeLeft.direction = .left
                    view.addGestureRecognizer(swipeLeft)

                    let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
                    swipeRight.direction = .right
                    view.addGestureRecognizer(swipeRight)
                }
        
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
        navigationController?.navigationBar.tintColor = nil // Reset button color to default
    }


    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black

        // Add subviews
        view.addSubview(webView)
        view.addSubview(videoView)
        view.addSubview(activityIndicator)

        // Setup constraints for webView
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Initially hide the video view
        videoView.isHidden = true
    }


    private func setupNavigationBar() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        // Add download button to navigation bar
        let downloadButton = UIBarButtonItem(image: UIImage(named: "downloadWV"),
                                             style: .plain,
                                             target: self,
                                             action: #selector(downloadData))
        navigationItem.rightBarButtonItem = downloadButton
    }

    private func loadContent() {
        guard currentIndex >= 0 && currentIndex < images.count else {
            showAlert(title: "Error", message: "Invalid index")
            return
        }

        var url = images[currentIndex]
        print("loadContent url: \(url)")

        // If the URL ends with "s.jpg", replace it with ".webm"
        if url.absoluteString.hasSuffix("s.jpg") {
            let modifiedURLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
            if let modifiedURL = URL(string: modifiedURLString) {
                url = modifiedURL
            }
        }

        if url.pathExtension.lowercased() == "webm" {
            // Hide web view and show video view
            webView.isHidden = true
            videoView.isHidden = false

            // Setup and play video
            let media = VLCMedia(url: url)
            mediaPlayer.media = media
            mediaPlayer.play()

        } else {
            // Hide video view and show web view
            videoView.isHidden = true
            webView.isHidden = false

            let request = URLRequest(url: url)
            webView.load(request)
        }
    }


    // MARK: - Swipe Handling
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            if currentIndex < images.count - 1 {
                currentIndex += 1
                loadContent()
            } else {
                showAlert(title: "End", message: "No more images")
            }
        } else if gesture.direction == .right {
            if currentIndex > 0 {
                currentIndex -= 1
                loadContent()
            } else {
                showAlert(title: "Start", message: "No previous images")
            }
        }
    }

    // MARK: - Actions
    @objc private func downloadData() {
        let folderName: String
        if images[currentIndex].absoluteString.contains("png") || images[currentIndex].absoluteString.contains("jpg") {
            folderName = "images"
        } else if images[currentIndex].absoluteString.contains("gif") || images[currentIndex].absoluteString.contains("webm") {
            folderName = "media"
        } else {
            showAlert(title: "Error", message: "Unsupported file type")
            return
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert(title: "Error", message: "Could not access documents directory")
            return
        }

        let folderURL = documentsDirectory.appendingPathComponent(folderName)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            showAlert(title: "Error", message: "Could not create directory")
            return
        }

        let filename = images[currentIndex].lastPathComponent
        let destinationURL = folderURL.appendingPathComponent(filename)

        Task {
            await download(url: images[currentIndex], to: destinationURL)
        }
    }

    private func download(url: URL, to localUrl: URL) async {
        let request = URLRequest(url: url)

        do {
            let (tempLocalUrl, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                showAlert(title: "Error", message: "Failed to download content")
                return
            }

            try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
            showAlert(title: "Success", message: "Download complete")
        } catch {
            showAlert(title: "Download Failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate
extension urlWeb: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showAlert(title: "Error", message: error.localizedDescription)
    }
}

// MARK: - VLCMediaPlayerDelegate
extension urlWeb: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if let player = aNotification.object as? VLCMediaPlayer {
            switch player.state {
            case .stopped:
                print("Stopped")
                // Automatically move to the next content if video is finished playing
                if currentIndex < images.count - 1 {
                    currentIndex += 1
                    loadContent()
                }
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
