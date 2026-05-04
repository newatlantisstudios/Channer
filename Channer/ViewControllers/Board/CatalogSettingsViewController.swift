import UIKit

class CatalogSettingsViewController: UIViewController {

    private let gridSizeLabel = UILabel()
    private let gridSizeSegment = UISegmentedControl(items: ["3XS", "2XS", "XS", "S", "M", "L", "XL"])

    private let fontSizeLabel = UILabel()
    private let fontSizeValueLabel = UILabel()
    private let fontSizeStepper = UIStepper()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground
        // Settings UI must stay at a fixed size; opt out of the user's in-app
        // font scale so a large preference doesn't truncate segment labels.
        view.accessibilityIdentifier = FontScaleManager.unscaledSubtreeIdentifier

        setupGridSizeRow()
        setupFontSizeRow()
        layoutRows()
    }

    /// Returns a system font at exactly `size` pt regardless of the global
    /// FontScaleManager swizzle (which would otherwise inflate the size).
    private static func fixedFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight).withSize(size)
    }

    // MARK: - Grid Size

    private func setupGridSizeRow() {
        gridSizeLabel.text = "Catalog Grid Size"
        gridSizeLabel.font = Self.fixedFont(ofSize: 15, weight: .regular)
        gridSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        gridSizeSegment.selectedSegmentIndex = GridItemSizeManager.shared.sizeIndex
        gridSizeSegment.translatesAutoresizingMaskIntoConstraints = false
        gridSizeSegment.addTarget(self, action: #selector(gridSizeChanged), for: .valueChanged)

        let segmentFont = Self.fixedFont(ofSize: 12, weight: .medium)
        gridSizeSegment.setTitleTextAttributes([.font: segmentFont], for: .normal)
        gridSizeSegment.setTitleTextAttributes([.font: segmentFont], for: .selected)

        view.addSubview(gridSizeLabel)
        view.addSubview(gridSizeSegment)
    }

    // MARK: - Font Size

    private func setupFontSizeRow() {
        fontSizeLabel.text = "Font Size"
        fontSizeLabel.font = Self.fixedFont(ofSize: 15, weight: .regular)
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        fontSizeValueLabel.text = "\(FontScaleManager.shared.scalePercent)%"
        fontSizeValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium).withSize(14)
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
        let sectionSpacing: CGFloat = 20
        let labelToControlSpacing: CGFloat = 10

        NSLayoutConstraint.activate([
            // Grid size: label on its own row, segmented control full-width below
            gridSizeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            gridSizeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            gridSizeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            gridSizeSegment.topAnchor.constraint(equalTo: gridSizeLabel.bottomAnchor, constant: labelToControlSpacing),
            gridSizeSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            gridSizeSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            // Font size row
            fontSizeLabel.topAnchor.constraint(equalTo: gridSizeSegment.bottomAnchor, constant: sectionSpacing),
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
