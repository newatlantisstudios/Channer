import UIKit
import UIKit
import ObjectiveC.runtime

final class FontScaleManager {
    static let shared = FontScaleManager()

    private let fontScaleKey = "channer_font_scale_index"
    private let fontScalePercentKey = "channer_font_scale_percent"
    private let scaleOptions: [CGFloat] = [1.0, 1.2, 1.35, 1.5, 1.65]
    private var currentScale: CGFloat = 1.0

    static let minimumPercent: Int = 80
    static let maximumPercent: Int = 200
    static let stepPercent: Int = 5
    static let defaultPercent: Int = 100

    private init() {
        // Migrate from old index-based storage if needed
        if UserDefaults.standard.object(forKey: fontScalePercentKey) == nil {
            if let _ = UserDefaults.standard.object(forKey: fontScaleKey) {
                let savedIndex = UserDefaults.standard.integer(forKey: fontScaleKey)
                let clampedIndex = max(0, min(savedIndex, scaleOptions.count - 1))
                let percent = Int(scaleOptions[clampedIndex] * 100)
                UserDefaults.standard.set(percent, forKey: fontScalePercentKey)
            } else {
                UserDefaults.standard.set(FontScaleManager.defaultPercent, forKey: fontScalePercentKey)
            }
        }

        let savedPercent = UserDefaults.standard.integer(forKey: fontScalePercentKey)
        currentScale = CGFloat(clampPercent(savedPercent)) / 100.0
    }

    func enableFontScaling() {
        UIFont.enableFontScaling()
    }

    var scalePercent: Int {
        let saved = UserDefaults.standard.integer(forKey: fontScalePercentKey)
        return clampPercent(saved)
    }

    var scaleFactor: CGFloat {
        return currentScale
    }

    func setScalePercent(_ percent: Int) {
        let clamped = clampPercent(percent)
        let newScale = CGFloat(clamped) / 100.0
        let oldScale = currentScale

        guard newScale != oldScale else { return }

        UserDefaults.standard.set(clamped, forKey: fontScalePercentKey)
        currentScale = newScale

        DispatchQueue.main.async {
            self.applyScaleChange(from: oldScale, to: newScale)
            NotificationCenter.default.post(name: .fontScaleDidChange, object: nil)
        }
    }

    func scaledFontSize(_ size: CGFloat) -> CGFloat {
        return size * currentScale
    }

    private func clampPercent(_ percent: Int) -> Int {
        return max(FontScaleManager.minimumPercent, min(percent, FontScaleManager.maximumPercent))
    }

    private func applyScaleChange(from oldScale: CGFloat, to newScale: CGFloat) {
        guard oldScale > 0 else { return }

        let ratio = newScale / oldScale
        guard ratio != 1 else { return }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                updateFonts(in: window, ratio: ratio)
            }
        }
    }

    private func updateFonts(in view: UIView, ratio: CGFloat) {
        if let label = view as? UILabel {
            updateLabelFont(label, ratio: ratio)
        } else if let textView = view as? UITextView {
            updateTextViewFont(textView, ratio: ratio)
        } else if let textField = view as? UITextField {
            updateTextFieldFont(textField, ratio: ratio)
        } else if let button = view as? UIButton {
            updateButtonFont(button, ratio: ratio)
        } else if let segmentedControl = view as? UISegmentedControl {
            updateSegmentedControlFont(segmentedControl, ratio: ratio)
        }

        for subview in view.subviews {
            updateFonts(in: subview, ratio: ratio)
        }

        if let tableView = view as? UITableView {
            tableView.beginUpdates()
            tableView.endUpdates()
        } else if let collectionView = view as? UICollectionView {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func updateLabelFont(_ label: UILabel, ratio: CGFloat) {
        if let attributedText = label.attributedText, attributedText.length > 0 {
            label.attributedText = scaledAttributedText(attributedText, ratio: ratio)
        } else if let font = label.font {
            label.font = font.withSize(font.pointSize * ratio)
        }
    }

    private func updateTextViewFont(_ textView: UITextView, ratio: CGFloat) {
        if let attributedText = textView.attributedText, attributedText.length > 0 {
            textView.attributedText = scaledAttributedText(attributedText, ratio: ratio)
        } else if let font = textView.font {
            textView.font = font.withSize(font.pointSize * ratio)
        }

        var typingAttributes = textView.typingAttributes
        if let font = typingAttributes[.font] as? UIFont {
            typingAttributes[.font] = font.withSize(font.pointSize * ratio)
            textView.typingAttributes = typingAttributes
        }
    }

    private func updateTextFieldFont(_ textField: UITextField, ratio: CGFloat) {
        if let font = textField.font {
            textField.font = font.withSize(font.pointSize * ratio)
        }

        var defaultAttributes = textField.defaultTextAttributes
        if let font = defaultAttributes[.font] as? UIFont {
            defaultAttributes[.font] = font.withSize(font.pointSize * ratio)
            textField.defaultTextAttributes = defaultAttributes
        }
    }

    private func updateButtonFont(_ button: UIButton, ratio: CGFloat) {
        if let font = button.titleLabel?.font {
            button.titleLabel?.font = font.withSize(font.pointSize * ratio)
        }

        if let attributedTitle = button.attributedTitle(for: .normal) {
            button.setAttributedTitle(scaledAttributedText(attributedTitle, ratio: ratio), for: .normal)
        }
    }

    private func updateSegmentedControlFont(_ segmentedControl: UISegmentedControl, ratio: CGFloat) {
        let states: [UIControl.State] = [.normal, .selected, .highlighted, .disabled]
        var handledFont = false

        for state in states {
            guard var attributes = segmentedControl.titleTextAttributes(for: state) else { continue }
            if let font = attributes[.font] as? UIFont {
                attributes[.font] = font.withSize(font.pointSize * ratio)
                segmentedControl.setTitleTextAttributes(attributes, for: state)
                handledFont = true
            }
        }

        if !handledFont {
            let font = UIFont.systemFont(ofSize: 13, weight: .regular)
            segmentedControl.setTitleTextAttributes([.font: font], for: .normal)
            segmentedControl.setTitleTextAttributes([.font: font], for: .selected)
        }
    }

    private func scaledAttributedText(_ attributedText: NSAttributedString, ratio: CGFloat) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            mutable.addAttribute(.font, value: font.withSize(font.pointSize * ratio), range: range)
        }
        return mutable
    }
}

extension UIFont {
    static func enableFontScaling() {
        _ = swizzleFontScaling
    }

    private static let swizzleFontScaling: Void = {
        let classType: AnyClass = UIFont.self
        let swizzles: [(Selector, Selector)] = [
            (#selector(systemFont(ofSize:)), #selector(channer_systemFont(ofSize:))),
            (#selector(systemFont(ofSize:weight:)), #selector(channer_systemFont(ofSize:weight:))),
            (#selector(boldSystemFont(ofSize:)), #selector(channer_boldSystemFont(ofSize:))),
            (#selector(italicSystemFont(ofSize:)), #selector(channer_italicSystemFont(ofSize:))),
            (#selector(monospacedSystemFont(ofSize:weight:)), #selector(channer_monospacedSystemFont(ofSize:weight:)))
        ]

        for (originalSelector, swizzledSelector) in swizzles {
            guard let originalMethod = class_getClassMethod(classType, originalSelector),
                  let swizzledMethod = class_getClassMethod(classType, swizzledSelector) else {
                continue
            }
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()

    @objc class func channer_systemFont(ofSize size: CGFloat) -> UIFont {
        return channer_systemFont(ofSize: FontScaleManager.shared.scaledFontSize(size))
    }

    @objc class func channer_systemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return channer_systemFont(ofSize: FontScaleManager.shared.scaledFontSize(size), weight: weight)
    }

    @objc class func channer_boldSystemFont(ofSize size: CGFloat) -> UIFont {
        return channer_boldSystemFont(ofSize: FontScaleManager.shared.scaledFontSize(size))
    }

    @objc class func channer_italicSystemFont(ofSize size: CGFloat) -> UIFont {
        return channer_italicSystemFont(ofSize: FontScaleManager.shared.scaledFontSize(size))
    }

    @objc class func channer_monospacedSystemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return channer_monospacedSystemFont(ofSize: FontScaleManager.shared.scaledFontSize(size), weight: weight)
    }
}

extension Notification.Name {
    static let fontScaleDidChange = Notification.Name("FontScaleDidChangeNotification")
}
