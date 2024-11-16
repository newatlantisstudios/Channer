import UIKit

class ImageViewController: UIViewController, UIScrollViewDelegate {
    
    private var imageView: UIImageView!
    private var scrollView: UIScrollView!
    var imageURL: URL
    private var hasInitializedZoomScale = false
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        setupScrollView()
        setupImageView()

        if let image = UIImage(contentsOfFile: imageURL.path) {
            imageView.image = image
            imageView.sizeToFit()
            scrollView.contentSize = imageView.bounds.size
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the navigation bar appearance to black for this view
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Revert the navigation bar appearance to the default
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasInitializedZoomScale {
            hasInitializedZoomScale = true
            updateZoomScaleForSize(scrollView.bounds.size)
            alignImageToTop()
        }
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupImageView() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }
    
    // MARK: - Align Image to Top
    
    private func alignImageToTop() {
        let scrollViewSize = scrollView.bounds.size
        let imageViewSize = imageView.frame.size

        // Calculate horizontal inset for centering
        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        
        // Set vertical inset to 0 to align at the top
        scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )
    }

    // MARK: - Zoom Support
    
    private func updateZoomScaleForSize(_ size: CGSize) {
        guard let image = imageView.image else { return }

        // Calculate scales to fit image in view
        let widthScale = size.width / image.size.width
        let heightScale = size.height / image.size.height
        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale // Reset zoom to minimum

        // Align image at the top
        alignImageToTop()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        alignImageToTop()
    }
}
