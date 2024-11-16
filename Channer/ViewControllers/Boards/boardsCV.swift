import UIKit
import Alamofire
import SwiftyJSON

private let reuseIdentifier = "boardCell"

class boardsCV: UICollectionViewController {

    let boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    let boardsAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set system background color for automatic light/dark mode support
        collectionView.backgroundColor = .systemBackground
        
        // Create the buttons
        let filesButton = UIBarButtonItem(image: UIImage(named: "files"), style: .plain, target: self, action: #selector(openFilesList))
        let historyButton = UIBarButtonItem(image: UIImage(named: "history"), style: .plain, target: self, action: #selector(openHistory))
        let favoritesButton = UIBarButtonItem(image: UIImage(named: "favorite"), style: .plain, target: self, action: #selector(showFavorites))
        
        // Add the buttons to their respective sides
        navigationItem.rightBarButtonItem = filesButton
        navigationItem.leftBarButtonItems = [historyButton, favoritesButton]
    }


    @objc func openFilesList() {
        let filesVC = FilesListVC()
        navigationController?.pushViewController(filesVC, animated: true)
    }
    
    @objc func openHistory() {
        // Example check for no threads in history
        let historyThreads = HistoryManager.shared.getHistoryThreads() // Assume this fetches the history threads
        if historyThreads.isEmpty {
            // Show a popup alert
            let alert = UIAlertController(title: "No Threads", message: "There are no threads in your history.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }

        // Load boardTV with history data
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "boardTV") as! boardTV
        vc.isHistoryView = true // New property to indicate history mode
        vc.threadData = historyThreads // Pass the history threads
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func showFavorites() {
        FavoritesManager.shared.verifyAndRemoveInvalidFavorites { updatedFavorites in
            guard !updatedFavorites.isEmpty else {
                // Show a popup alert
                let alert = UIAlertController(title: "No Favorites", message: "There are no threads in your favorites.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "boardTV") as? boardTV else {
                print("Could not find boardTV in storyboard.")
                return
            }

            vc.title = "Favorites"
            vc.threadData = updatedFavorites
            vc.filteredThreadData = updatedFavorites
            vc.isFavoritesView = true

            DispatchQueue.main.async {
                vc.tableView.reloadData()
            }

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return boardNames.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! boardCVCell
    
        // Configure the cell
        cell.boardName.text = boardNames[indexPath.row]
        cell.boardNameAbv.text = "/" + boardsAbv[indexPath.row] + "/"
    
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Use Main storyboard for all devices
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "boardTV") as! boardTV
        
        // Configure the view controller
        vc.boardName = boardNames[indexPath.row]
        vc.boardAbv = boardsAbv[indexPath.row]
        vc.title = "/" + boardsAbv[indexPath.row] + "/"
        
        // Push the view controller
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
