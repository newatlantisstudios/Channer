import UIKit

// MARK: - Custom Split View Controller
/// A custom split view controller that dynamically adjusts the primary column width based on the device's screen size.
class CustomSplitViewController: UISplitViewController {

    // MARK: - Lifecycle Methods
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
    }

    // MARK: - Split View Configuration
    /// Configures the split view dynamically based on screen size and orientation.
    func configureSplitView() {
        let screenSize = UIScreen.main.bounds.size

        // Log the screen size for debugging
        print("Debug Info: Screen size: \(screenSize)")

        /// Helper function to compare sizes with tolerance.
        ///
        /// - Parameters:
        ///   - size: The `CGSize` to compare with the current screen size.
        ///   - tolerance: The allowable difference in size for comparison.
        /// - Returns: A Boolean value indicating whether the sizes are approximately equal.
        func isApproximatelyEqual(to size: CGSize, tolerance: CGFloat = 20.0) -> Bool {
            let result = abs(screenSize.width - size.width) <= tolerance && abs(screenSize.height - size.height) <= tolerance
            print("Debug Info: Comparing \(screenSize) to \(size) with tolerance \(tolerance) -> \(result)")
            return result
        }

        if isApproximatelyEqual(to: CGSize(width: 1024, height: 1366)) || isApproximatelyEqual(to: CGSize(width: 1366, height: 1024)) {
            // Detected iPad Pro 13-inch or Air 13-inch
            print("Debug Info: Detected iPad Pro 13-inch or Air 13-inch")
            preferredPrimaryColumnWidthFraction = 0.355
            maximumPrimaryColumnWidth = UIScreen.main.bounds.width * 0.355
        } else if isApproximatelyEqual(to: CGSize(width: 834, height: 1194)) ||
                  isApproximatelyEqual(to: CGSize(width: 1194, height: 834)) ||
                  isApproximatelyEqual(to: CGSize(width: 834, height: 1210)) ||
                  isApproximatelyEqual(to: CGSize(width: 1210, height: 834)) {
            // Detected iPad Pro 11-inch or Air 11-inch
            print("Debug Info: Detected iPad Pro 11-inch or Air 11-inch")
            preferredPrimaryColumnWidthFraction = 0.44
            maximumPrimaryColumnWidth = UIScreen.main.bounds.width * 0.44
        } else if isApproximatelyEqual(to: CGSize(width: 820, height: 1180)) ||
                  isApproximatelyEqual(to: CGSize(width: 1180, height: 820)) {
            // Detected iPad 10th Generation
            print("Debug Info: Detected iPad 10th Generation")
            preferredPrimaryColumnWidthFraction = 0.45
            maximumPrimaryColumnWidth = UIScreen.main.bounds.width * 0.45
        } else if isApproximatelyEqual(to: CGSize(width: 744, height: 1133)) ||
                  isApproximatelyEqual(to: CGSize(width: 1133, height: 744)) {
            // Detected iPad Mini
            print("Debug Info: Detected iPad Mini")
            preferredPrimaryColumnWidthFraction = 0.49
            maximumPrimaryColumnWidth = UIScreen.main.bounds.width * 0.49
        }

        // Log the final column width configuration
        print("Debug Info: Final Preferred Primary Column Width Fraction = \(preferredPrimaryColumnWidthFraction)")
        print("Debug Info: Final Maximum Primary Column Width = \(maximumPrimaryColumnWidth)")
    }

}
