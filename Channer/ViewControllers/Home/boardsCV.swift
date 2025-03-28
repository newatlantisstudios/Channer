import UIKit
import Alamofire
import SwiftyJSON
import LocalAuthentication

private let reuseIdentifier = "boardCell"

class boardsCV: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties
    /// An array containing the full names of the boards.
    var boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    
    /// An array containing the abbreviated names of the boards.
    var boardsAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
    
    // MARK: - Authentication
    /// Authenticates the user using Face ID or Touch ID.
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if Face ID/Touch ID is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access this feature."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Fallback if Face ID/Touch ID is not available
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    // MARK: - View Lifecycle
    
    /// Sorts the boards alphabetically by name while maintaining name-abbreviation pairs
    private func sortBoardsAlphabetically() {
        // Create array of tuples with board name and abbreviation
        let combinedBoards = zip(boardNames, boardsAbv).map { ($0, $1) }
        
        // Sort the combined array by board name
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        
        // Update the original arrays with sorted values
        boardNames = sortedBoards.map { $0.0 }
        boardsAbv = sortedBoards.map { $0.1 }
        
        // Print confirmation
        print("Boards sorted alphabetically")
    }
    
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sort boards alphabetically
        sortBoardsAlphabetically()
        
        // Set theme background color for automatic light/dark mode support
        collectionView.backgroundColor = ThemeManager.shared.backgroundColor

        // Ensure the collection view is using a UICollectionViewFlowLayout
        if collectionView.collectionViewLayout as? UICollectionViewFlowLayout == nil {
            collectionView.collectionViewLayout = UICollectionViewFlowLayout()
        }

        // Register cell
        collectionView.register(boardCVCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Add navigation buttons
        let filesButton = UIBarButtonItem(image: UIImage(named: "files"), style: .plain, target: self, action: #selector(openFilesList))
        let settingsButton = UIBarButtonItem(image: UIImage(named: "setting"), style: .plain, target: self, action: #selector(openSettings))
        navigationItem.rightBarButtonItems = [settingsButton, filesButton]

        let historyButton = UIBarButtonItem(image: UIImage(named: "history"), style: .plain, target: self, action: #selector(openHistory))
        let favoritesButton = UIBarButtonItem(image: UIImage(named: "favorite"), style: .plain, target: self, action: #selector(showFavorites))
        navigationItem.leftBarButtonItems = [historyButton, favoritesButton]
    }
    
    /// Called to notify the view controller that its view is about to layout its subviews.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureCollectionViewLayout()
    }
    
    // MARK: - Navigation Actions
    /// Opens the files list after successful authentication.
    @objc func openFilesList() {
        authenticateUser { [weak self] isAuthenticated in
            guard let self = self else { return }
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening files list
            let filesVC = FilesListVC()
            self.splitViewController?.showDetailViewController(filesVC, sender: self)
            
        }
    }
    
    /// Navigates to the settings view, where the user can configure app preferences such as the default board.
    /// Navigates to the settings view, where the user can configure app preferences such as the default board.
    @objc private func openSettings() {
        let settingsVC = settings() // Instantiate settings view controller programmatically
        settingsVC.title = "Settings" // Set the title for the navigation bar
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    /// Opens the history view after successful authentication.
    @objc func openHistory() {
        authenticateUser { [weak self] isAuthenticated in
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening history
            guard let self = self else { return }
            let historyThreads = HistoryManager.shared.getHistoryThreads()
            if historyThreads.isEmpty {
                let alert = UIAlertController(title: "No Threads", message: "There are no threads in your history.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }

            let vc = boardTV()
            vc.isHistoryView = true
            vc.threadData = historyThreads
            self.splitViewController?.showDetailViewController(vc, sender: self)
        }
    }

    /// Shows the favorites view after successful authentication.
    @objc private func showFavorites() {
        authenticateUser { [weak self] isAuthenticated in
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening favorites
            guard let self = self else { return }
            FavoritesManager.shared.verifyAndRemoveInvalidFavorites { updatedFavorites in
                guard !updatedFavorites.isEmpty else {
                    let alert = UIAlertController(title: "No Favorites", message: "There are no threads in your favorites.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }

                let vc = boardTV()

                vc.title = "Favorites"
                vc.threadData = updatedFavorites
                vc.filteredThreadData = updatedFavorites
                vc.isFavoritesView = true

                DispatchQueue.main.async {
                    vc.tableView.reloadData()
                }

                self.splitViewController?.showDetailViewController(vc, sender: self)
            }
        }
    }
    
    // MARK: - UICollectionView Data Source
    /// Returns the number of sections in the collection view.
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    /// Returns the number of items in the specified section.
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return boardNames.count
    }
    
    /// Configures and returns the cell for the item at the specified index path.
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? boardCVCell else {
            fatalError("Failed to dequeue boardCVCell")
        }

        // Configure the cell
        cell.boardName.text = boardNames[indexPath.row] // Ensure this array has valid strings
        cell.boardNameAbv.text = "/" + boardsAbv[indexPath.row] + "/" // Ensure this array matches `boardNames`
        cell.boardImage.image = UIImage(named: "boardSquare") // Replace with your actual image logic

        return cell
    }
    
    // MARK: - UICollectionView Delegate
    /// Handles the selection of an item in the collection view.
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(indexPath.row)
        guard indexPath.row < boardNames.count else {
            print("Index \(indexPath.row) out of bounds for boardNames array.")
            return
        }

        // Instantiate boardTV
        let vc = boardTV()

        // Configure boardTV with selected category
        vc.boardName = boardNames[indexPath.row]
        vc.boardAbv = boardsAbv[indexPath.row]
        vc.title = "/" + boardsAbv[indexPath.row] + "/"
        vc.boardPassed = true

        // Adapt behavior based on device type
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad behavior: update the detail view controller in the split view
            if let splitVC = self.splitViewController,
               let detailNavController = splitVC.viewController(for: .secondary) as? UINavigationController {
                detailNavController.setViewControllers([vc], animated: false)
            } else {
                print("Detail navigation controller is not properly configured.")
            }
        } else {
            // Handle navigation stack
            if let navController = navigationController {
                navController.pushViewController(vc, animated: true)
            } else {
                // Fallback to modal presentation for iPhones
                let navController = UINavigationController(rootViewController: vc)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    /// Returns the minimum spacing between items in the same row.
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 2 // Match the spacing in `configureCollectionViewLayout`
    }

    /// Returns the minimum spacing between lines of items in the grid.
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 2 // Match the spacing in `configureCollectionViewLayout`
    }
    
    /// Configures the layout of the collection view.
    private func configureCollectionViewLayout() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        // Define fixed cell size
        let cellWidth: CGFloat = 85
        let cellHeight: CGFloat = 85

        // Define spacing
        let interItemSpacing: CGFloat = 5  // Horizontal space between cells
        let lineSpacing: CGFloat = 5       // Vertical space between rows

        // Get the collection view's width
        let collectionViewWidth = collectionView.bounds.width

        // Calculate the maximum number of columns that can fit
        let totalAvailableWidth = collectionViewWidth - 10 // Subtract minimum sectionInsets of 5 on each side
        let maxColumns = floor((totalAvailableWidth + interItemSpacing) / (cellWidth + interItemSpacing))
        let columns = max(min(maxColumns, 4), 1) // Ensure at least 1 column and no more than 4

        // Calculate total cell content width
        let totalCellWidth = cellWidth * columns
        let totalInterItemSpacing = interItemSpacing * (columns - 1)
        let totalContentWidth = totalCellWidth + totalInterItemSpacing

        // Determine section insets based on device
        let isPad = traitCollection.userInterfaceIdiom == .pad

        let leftInset: CGFloat
        let rightInset: CGFloat

        if isPad {
            // Align to right on iPadOS
            leftInset = max(collectionViewWidth - totalContentWidth - 5, 5) // Ensure at least 5px
            rightInset = 5
        } else {
            // Center on iOS
            let horizontalInset = max((collectionViewWidth - totalContentWidth) / 2.0, 5)
            leftInset = horizontalInset
            rightInset = horizontalInset
        }

        // Configure layout
        layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        layout.minimumInteritemSpacing = interItemSpacing
        layout.minimumLineSpacing = lineSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 5,
            left: leftInset,
            bottom: 5,
            right: rightInset
        )
    }
}
