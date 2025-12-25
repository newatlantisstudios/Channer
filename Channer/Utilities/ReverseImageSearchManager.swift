//
//  ReverseImageSearchManager.swift
//  Channer
//
//  Provides reverse image search functionality for images
//

import UIKit

/// Manager class for handling reverse image search operations
class ReverseImageSearchManager {

    /// Shared singleton instance
    static let shared = ReverseImageSearchManager()

    private init() {}

    // MARK: - Search Service Definitions

    /// Available reverse image search services
    enum SearchService: String, CaseIterable {
        case sauceNAO = "SauceNAO"
        case google = "Google Images"
        case iqdb = "IQDB"
        case tineye = "TinEye"
        case yandex = "Yandex"
        case ascii2d = "ascii2d"

        /// Icon for the search service
        var icon: String {
            switch self {
            case .sauceNAO: return "magnifyingglass.circle"
            case .google: return "globe"
            case .iqdb: return "photo"
            case .tineye: return "eye"
            case .yandex: return "magnifyingglass"
            case .ascii2d: return "textformat"
            }
        }

        /// Description of the search service
        var description: String {
            switch self {
            case .sauceNAO: return "Best for anime/manga source finding"
            case .google: return "General reverse image search"
            case .iqdb: return "Multi-service anime/manga search"
            case .tineye: return "Find exact image matches"
            case .yandex: return "Alternative general search"
            case .ascii2d: return "Japanese artwork search"
            }
        }
    }

    // MARK: - URL Generation

    /// Generates the search URL for a given service and image URL
    /// - Parameters:
    ///   - service: The search service to use
    ///   - imageURL: The URL of the image to search
    /// - Returns: The URL to open in a browser for the search
    func searchURL(for service: SearchService, imageURL: URL) -> URL? {
        let encodedURL = imageURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageURL.absoluteString

        switch service {
        case .sauceNAO:
            return URL(string: "https://saucenao.com/search.php?url=\(encodedURL)")

        case .google:
            return URL(string: "https://lens.google.com/uploadbyurl?url=\(encodedURL)")

        case .iqdb:
            return URL(string: "https://iqdb.org/?url=\(encodedURL)")

        case .tineye:
            return URL(string: "https://tineye.com/search?url=\(encodedURL)")

        case .yandex:
            return URL(string: "https://yandex.com/images/search?rpt=imageview&url=\(encodedURL)")

        case .ascii2d:
            return URL(string: "https://ascii2d.net/search/url/\(encodedURL)")
        }
    }

    /// Performs reverse image search using the specified service
    /// - Parameters:
    ///   - service: The search service to use
    ///   - imageURL: The URL of the image to search
    func performSearch(service: SearchService, imageURL: URL) {
        guard let searchURL = searchURL(for: service, imageURL: imageURL) else {
            print("DEBUG: ReverseImageSearchManager - Failed to create search URL")
            return
        }

        print("DEBUG: ReverseImageSearchManager - Opening \(service.rawValue) search: \(searchURL)")
        UIApplication.shared.open(searchURL, options: [:], completionHandler: nil)
    }

    /// Creates a UIMenu for reverse image search options
    /// - Parameter imageURL: The URL of the image to search
    /// - Returns: A UIMenu with all available search options
    func createSearchMenu(for imageURL: URL) -> UIMenu {
        var actions: [UIAction] = []

        for service in SearchService.allCases {
            let action = UIAction(
                title: service.rawValue,
                subtitle: service.description,
                image: UIImage(systemName: service.icon)
            ) { [weak self] _ in
                self?.performSearch(service: service, imageURL: imageURL)
            }
            actions.append(action)
        }

        return UIMenu(title: "Reverse Image Search", image: UIImage(systemName: "magnifyingglass"), children: actions)
    }

    /// Creates an alert controller with reverse image search options
    /// - Parameters:
    ///   - imageURL: The URL of the image to search
    ///   - presenter: The view controller to present from
    func showSearchOptions(for imageURL: URL, from presenter: UIViewController) {
        let alertController = UIAlertController(
            title: "Reverse Image Search",
            message: "Select a search service",
            preferredStyle: .actionSheet
        )

        for service in SearchService.allCases {
            let action = UIAlertAction(title: service.rawValue, style: .default) { [weak self] _ in
                self?.performSearch(service: service, imageURL: imageURL)
            }
            alertController.addAction(action)
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = presenter.view
            popoverController.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        presenter.present(alertController, animated: true)
    }
}
