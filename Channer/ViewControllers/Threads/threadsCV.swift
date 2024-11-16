//
//  threadsCV.swift
//  
//
//  Created by x on 4/15/19.
//

import UIKit
import Alamofire
import Kingfisher

private let reuseIdentifier = "boardCVCell"

class threadsCV: UICollectionViewController {
    
    @IBOutlet var threadsCVOutlet: UICollectionView!
    
    var boardName = ""
    var boardAbv = ""
    var totalThreadCount = 0
    var allThreadNumbers = [String]()
    
    // Threads First Reply Data
    var threadStats = [String]()
    var threadFirstComments = [String]()
    var threadImages = [String]()
    var threadTitles = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        getBoardData(page: 1)
    }

    func getBoardData(page: Int) {
        print("getting boardData for: \(boardName) - \(boardAbv)")
        
        let url = "https://a.4cdn.org/\(boardAbv)/\(page).json"
        
        AF.request(url).responseDecodable(of: BoardResponse.self) { response in
            switch response.result {
            case .success(let boardResponse):
                let threadsCount = boardResponse.threads.count
                print("threadsCount: \(threadsCount)")
                self.totalThreadCount += threadsCount
                
                // Fetch data for each thread
                for thread in boardResponse.threads {
                    let threadNumber = thread.posts[0].no
                    self.fetchThreadData(threadNumber: threadNumber)
                }
                
                // Fetch next page if not at the end
                if page != 10 {
                    print("📌Next page")
                    self.getBoardData(page: page + 1)
                }
                
            case .failure(let error):
                print("Error getting board data: \(error)")
            }
        }
    }
    
    private func fetchThreadData(threadNumber: Int) {
        let url = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        AF.request(url).responseDecodable(of: ThreadResponse.self) { response in
            switch response.result {
            case .success(let threadResponse):
                guard let firstPost = threadResponse.posts.first else { return }
                
                // Store thread number
                self.allThreadNumbers.append(String(threadNumber))
                
                // Store thread statistics
                let newStat = "\(firstPost.replies ?? 0)/\(firstPost.images ?? 0)"
                self.threadStats.append(newStat)
                
                // Process thread title
                let threadTitle = self.processHTML(firstPost.sub ?? "")
                self.threadTitles.append(threadTitle)
                
                // Process first comment
                let firstComment = self.processHTML(firstPost.com ?? "")
                self.threadFirstComments.append(firstComment)
                
                // Process image
                if let tim = firstPost.tim, let ext = firstPost.ext {
                    let imageURL = "https://i.4cdn.org/\(self.boardAbv)/\(tim)\(ext)"
                    self.threadImages.append(imageURL)
                } else {
                    self.threadImages.append("")
                }
                
                // Reload collection view if all data is loaded
                if self.totalThreadCount == self.threadFirstComments.count {
                    print("🏁 Data loading complete")
                    self.threadsCVOutlet.reloadData()
                }
                
            case .failure(let error):
                print("Error getting thread data: \(error)")
            }
        }
    }
    
    private func processHTML(_ html: String) -> String {
        var processed = html
        
        // HTML replacements
        let replacements: [String: String] = [
            "<span class=\"quote\">&gt;": "⭕️",
            "</span>": "",
            "<br>": "\n",
            "&#039;": "'",
            "<s>": "‼️",
            "</s>": "‼️",
            "&gt;": ">",
            "&quot;": "\"",
            "<wbr>": "",
            "&amp;": "&"
        ]
        
        for (key, value) in replacements {
            processed = processed.replacingOccurrences(of: key, with: value)
        }
        
        return processed
    }

    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalThreadCount
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! threadsCell
    
        if totalThreadCount == 0 {
            configureLoadingCell(cell)
        } else {
            configureCell(cell, at: indexPath)
        }
    
        return cell
    }
    
    private func configureLoadingCell(_ cell: threadsCell) {
        cell.topicStats.text = "Loading..."
        cell.topicTextNoTitle.text = "Loading..."
    }
    
    private func configureCell(_ cell: threadsCell, at indexPath: IndexPath) {
        cell.topicStats.text = threadStats[indexPath.row]
        
        // Configure title and text
        if threadTitles[indexPath.row] == "null" {
            cell.topicTextTitle.isHidden = true
            cell.topicTextNoTitle.isHidden = false
            cell.topicTextNoTitle.text = threadFirstComments[indexPath.row]
            cell.topicTitle.isHidden = true
            cell.topicTitle.text = ""
        } else {
            cell.topicTextTitle.isHidden = false
            cell.topicTextNoTitle.isHidden = true
            cell.topicTextTitle.text = threadFirstComments[indexPath.row]
            cell.topicTitle.isHidden = false
            cell.topicTitle.text = threadTitles[indexPath.row]
        }
        
        // Configure image
        configureImage(for: cell, at: indexPath)
    }
    
    private func configureImage(for cell: threadsCell, at indexPath: IndexPath) {
        let imageUrl = threadImages[indexPath.row]
        
        if imageUrl.contains(".webm") {
            // Handle webm thumbnail
            let thumbnailUrl = imageUrl.replacingOccurrences(of: ".webm", with: "s.jpg")
            cell.topicImage.kf.setImage(with: URL(string: thumbnailUrl))
        } else {
            cell.topicImage.kf.setImage(with: URL(string: imageUrl))
        }
        
        cell.topicImage.layer.cornerRadius = 12
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "threadRepliesTV") as! threadRepliesTV
        vc.boardAbv = boardAbv
        vc.threadNumber = allThreadNumbers[indexPath.row]
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Data Models
struct BoardResponse: Decodable {
    let threads: [ThreadPreview]
}

struct ThreadPreview: Decodable {
    let posts: [Post]
}

struct ThreadResponse: Decodable {
    let posts: [Post]
}

struct Post: Decodable {
    let no: Int
    let replies: Int?
    let images: Int?
    let sub: String?
    let com: String?
    let tim: Int?
    let ext: String?
}
