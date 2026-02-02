import UIKit

final class ImageCropViewController: UIViewController, UIScrollViewDelegate {
    private let normalizedImage: UIImage
    private let onCrop: (UIImage) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = UIView()
    private let borderView = UIView()
    private let overlayLayer = CAShapeLayer()
    private var cropFrame: CGRect = .zero
    private var hasConfiguredZoom = false

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.normalizedImage = image.normalizedOrientation()
        self.onCrop = onCrop
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        title = "Crop"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )

        setupScrollView()
        setupOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCropArea()
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = true
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        view.addSubview(scrollView)

        imageView.image = normalizedImage
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }

    private func setupOverlay() {
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        overlayLayer.fillRule = .evenOdd
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        overlayView.layer.addSublayer(overlayLayer)

        borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        borderView.layer.borderWidth = 1
        borderView.isUserInteractionEnabled = false
        view.addSubview(borderView)
    }

    private func layoutCropArea() {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let padding: CGFloat = 20
        let imageAspect = normalizedImage.size.height / normalizedImage.size.width

        var cropWidth = safeFrame.width - (padding * 2)
        var cropHeight = cropWidth * imageAspect

        if cropHeight > safeFrame.height - (padding * 2) {
            cropHeight = safeFrame.height - (padding * 2)
            cropWidth = cropHeight / imageAspect
        }

        cropFrame = CGRect(
            x: safeFrame.midX - (cropWidth / 2),
            y: safeFrame.midY - (cropHeight / 2),
            width: cropWidth,
            height: cropHeight
        )

        scrollView.frame = cropFrame
        borderView.frame = cropFrame
        overlayView.frame = view.bounds
        overlayLayer.frame = overlayView.bounds
        updateOverlayMask()

        configureZoomIfNeeded()
        updateContentInset()
    }

    private func updateOverlayMask() {
        let path = UIBezierPath(rect: overlayView.bounds)
        path.append(UIBezierPath(rect: cropFrame))
        overlayLayer.path = path.cgPath
    }

    private func configureZoomIfNeeded() {
        imageView.frame = CGRect(origin: .zero, size: normalizedImage.size)
        scrollView.contentSize = imageView.bounds.size

        let scaleX = cropFrame.width / imageView.bounds.width
        let scaleY = cropFrame.height / imageView.bounds.height
        let minScale = max(scaleX, scaleY)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 6, 3)

        if !hasConfiguredZoom {
            scrollView.zoomScale = minScale
            hasConfiguredZoom = true
        }
    }

    private func updateContentInset() {
        let scaledWidth = imageView.bounds.width * scrollView.zoomScale
        let scaledHeight = imageView.bounds.height * scrollView.zoomScale
        let horizontalInset = max((scrollView.bounds.width - scaledWidth) / 2, 0)
        let verticalInset = max((scrollView.bounds.height - scaledHeight) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func doneTapped() {
        guard let cropped = cropImage() else {
            let alert = UIAlertController(title: "Crop Failed", message: "Unable to crop this image.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        onCrop(cropped)
        navigationController?.popViewController(animated: true)
    }

    private func cropImage() -> UIImage? {
        let zoomScale = scrollView.zoomScale
        let offsetX = (scrollView.contentOffset.x + scrollView.contentInset.left) / zoomScale
        let offsetY = (scrollView.contentOffset.y + scrollView.contentInset.top) / zoomScale
        let width = scrollView.bounds.width / zoomScale
        let height = scrollView.bounds.height / zoomScale

        let cropRect = CGRect(x: offsetX, y: offsetY, width: width, height: height)
        let scale = normalizedImage.scale
        let pixelRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.size.width * scale,
            height: cropRect.size.height * scale
        )
        return normalizedImage.cropped(to: pixelRect)
    }

    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentInset()
    }
}
