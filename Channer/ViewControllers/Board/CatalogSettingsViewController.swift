import UIKit

class CatalogSettingsViewController: UIViewController {

    private let gridSizeLabel = UILabel()
    private let gridSizeSegment = UISegmentedControl(items: ["XS", "S", "M", "L", "XL"])

    private let fontSizeLabel = UILabel()
    private let fontSizeValueLabel = UILabel()
    private let fontSizeStepper = UIStepper()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground

        setupGridSizeRow()
        setupFontSizeRow()
        layoutRows()
    }

    // MARK: - Grid Size

    private func setupGridSizeRow() {
        gridSizeLabel.text = "Catalog Grid Size"
        gridSizeLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        gridSizeLabel.adjustsFontSizeToFitWidth = true
        gridSizeLabel.minimumScaleFactor = 0.8
        gridSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        gridSizeSegment.selectedSegmentIndex = GridItemSizeManager.shared.sizeIndex
        gridSizeSegment.translatesAutoresizingMaskIntoConstraints = false
        gridSizeSegment.addTarget(self, action: #selector(gridSizeChanged), for: .valueChanged)

        let segFont: CGFloat = 11
        gridSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: segFont, weight: .medium)], for: .normal)
        gridSizeSegment.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: segFont, weight: .medium)], for: .selected)

        view.addSubview(gridSizeLabel)
        view.addSubview(gridSizeSegment)
    }

    // MARK: - Font Size

    private func setupFontSizeRow() {
        fontSizeLabel.text = "Font Size"
        fontSizeLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        fontSizeLabel.adjustsFontSizeToFitWidth = true
        fontSizeLabel.minimumScaleFactor = 0.8
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        fontSizeValueLabel.text = "\(FontScaleManager.shared.scalePercent)%"
        fontSizeValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        fontSizeValueLabel.textAlignment = .center
        fontSizeValueLabel.translatesAutoresizingMaskIntoConstraints = false

        fontSizeStepper.minimumValue = Double(FontScaleManager.minimumPercent)
        fontSizeStepper.maximumValue = Double(FontScaleManager.maximumPercent)
        fontSizeStepper.stepValue = Double(FontScaleManager.stepPercent)
        fontSizeStepper.value = Double(FontScaleManager.shared.scalePercent)
        fontSizeStepper.wraps = false
        fontSizeStepper.translatesAutoresizingMaskIntoConstraints = false
        fontSizeStepper.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)

        view.addSubview(fontSizeLabel)
        view.addSubview(fontSizeValueLabel)
        view.addSubview(fontSizeStepper)
    }

    // MARK: - Layout

    private func layoutRows() {
        let margin: CGFloat = 20
        let rowSpacing: CGFloat = 20

        NSLayoutConstraint.activate([
            // Grid size row
            gridSizeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            gridSizeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            gridSizeLabel.trailingAnchor.constraint(lessThanOrEqualTo: gridSizeSegment.leadingAnchor, constant: -12),

            gridSizeSegment.centerYAnchor.constraint(equalTo: gridSizeLabel.centerYAnchor),
            gridSizeSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            gridSizeSegment.widthAnchor.constraint(equalToConstant: 180),

            // Font size row
            fontSizeLabel.topAnchor.constraint(equalTo: gridSizeLabel.bottomAnchor, constant: rowSpacing),
            fontSizeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            fontSizeValueLabel.centerYAnchor.constraint(equalTo: fontSizeLabel.centerYAnchor),
            fontSizeValueLabel.trailingAnchor.constraint(equalTo: fontSizeStepper.leadingAnchor, constant: -8),

            fontSizeStepper.centerYAnchor.constraint(equalTo: fontSizeLabel.centerYAnchor),
            fontSizeStepper.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
        ])
    }

    // MARK: - Actions

    @objc private func gridSizeChanged(_ sender: UISegmentedControl) {
        GridItemSizeManager.shared.setSizeIndex(sender.selectedSegmentIndex)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func fontSizeChanged(_ sender: UIStepper) {
        let percent = Int(sender.value)
        fontSizeValueLabel.text = "\(percent)%"
        FontScaleManager.shared.setScalePercent(percent)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
