//
//  threadRepliesCV.swift
//  Channer
//
//  Created by x on 4/15/19.
//  Copyright © 2019 x. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import Kingfisher

// MARK: - Collection View Extension
extension UICollectionView {
    func scrollToLast() {
        guard numberOfSections > 0 else { return }
        let lastSection = numberOfSections - 1
        guard numberOfItems(inSection: lastSection) > 0 else { return }
        
        let lastItemIndexPath = IndexPath(item: numberOfItems(inSection: lastSection) - 1,
                                        section: lastSection)
        scrollToItem(at: lastItemIndexPath, at: .bottom, animated: true)
    }
}

// MARK: - Main Collection View Controller
class threadRepliesCV: UICollectionViewController {
    
    @IBOutlet var threadReplyCVOutlet: UICollectionView!
    
    var boardAbv = ""
    var threadNumber = ""
    
    // Thread Data
    var replyCount = 0
    var threadReplies = [String]()
    var threadBoardReplyNumber = [String]()
    var threadBoardReplies = [String: [String]]()
    var threadRepliesImages = [String]()
    
    // Stored thread state
    var threadRepliesOld = [String]()
    var threadBoardReplyNumberOld = [String]()
    var threadRepliesImagesOld = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        getThreadData()
    }
    
    private func setupNavigationBar() {
        let refreshButton = UIBarButtonItem(image: UIImage(named: "refreshWVx50"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(refresh))
        let goDownButton = UIBarButtonItem(image: UIImage(named: "downx50"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(down))
        navigationItem.rightBarButtonItems = [refreshButton, goDownButton]
    }
    
    func getThreadData() {
        print("Getting data from \(boardAbv) of \(threadNumber)")
        
        let url = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        AF.request(url).responseData { [weak self] response in
            guard let self = self else { return }
            
            switch response.result {
            case .success(let data):
                do {
                    let json = try JSON(data: data)
                    self.processThreadData(json)
                } catch {
                    print("Error parsing JSON: \(error)")
                }
            case .failure(let error):
                print("Network error: \(error)")
            }
        }
    }
    
    private func processThreadData(_ json: JSON) {
        // Get reply count
        replyCount = Int(json["posts"][0]["replies"].stringValue) ?? 0
        
        let forLimit = max(0, replyCount == 1 ? 1 : replyCount - 1)
        
        // Process first post if no replies
        if replyCount == 0 {
            processPost(json["posts"][0], index: 0)
            replyCount = 1
            threadReplyCVOutlet.reloadData()
            return
        }
        
        // Process all posts
        for i in 0...forLimit {
            processPost(json["posts"][i], index: i)
        }
        
        if replyCount == threadReplies.count {
            structureThreadReplies()
        }
    }
    
    private func processPost(_ post: JSON, index: Int) {
        // Board reply number
        threadBoardReplyNumber.append(String(describing: post["no"]))
                
        // Image URL
        let timestamp = post["tim"].stringValue
        let fileExtension = post["ext"].stringValue
        let imageUrl = "https://i.4cdn.org/\(boardAbv)/\(timestamp)\(fileExtension)"
        threadRepliesImages.append(imageUrl)
                
        // Process comment
        var comment = post["com"].stringValue
        comment = formatComment(comment)
        threadReplies.append(comment)
    }
    
    private func formatComment(_ comment: String) -> String {
        var formatted = comment
        
        // HTML decode mapping
        let replacements = [
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
            formatted = formatted.replacingOccurrences(of: key, with: value)
        }
        
        return formatted
    }
    
    private func structureThreadReplies() {
        for (i, reply) in threadReplies.enumerated() {
            if reply.contains("class=\"quotelink\"") {
                for (a, boardNumber) in threadBoardReplyNumber.enumerated() {
                    if reply.contains(boardNumber) {
                        // Remove quoteLink
                        let removeString = "<a href=\"#p\(boardNumber)\" class=\"quotelink\">>>\(boardNumber)</a>"
                        threadReplies[i] = reply.replacingOccurrences(of: removeString, with: "")
                            .replacingOccurrences(of: "^\\s*", with: "", options: .regularExpression)
                        
                        // Add to threadBoardReplies
                        if threadBoardReplies[boardNumber] == nil {
                            threadBoardReplies[boardNumber] = [threadBoardReplyNumber[i]]
                        } else {
                            threadBoardReplies[boardNumber]?.append(threadBoardReplyNumber[i])
                        }
                    }
                }
            }
        }
        
        threadReplyCVOutlet.reloadData()
    }
    
    // MARK: - Actions
    
    @objc func threadContentOpen(sender: UIButton) {
        let content = threadRepliesImages[sender.tag]
        let urlVC = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "urlWebview") as! urlWeb
        urlVC.urlPass = content
        navigationController?.pushViewController(urlVC, animated: true)
    }
    
    @objc func showThread(sender: UIButton) {
        let tag = sender.tag
        
        // Update navigation bar
        let goDownButton = UIBarButtonItem(image: UIImage(named: "downx50"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(down))
        let showCompleteThreadButton = UIBarButtonItem(image: UIImage(named: "completeThreadx50"),
                                                     style: .plain,
                                                     target: self,
                                                     action: #selector(completeThread))
        navigationItem.rightBarButtonItems = [goDownButton, showCompleteThreadButton]
        
        // Store current state
        threadRepliesOld = threadReplies
        threadBoardReplyNumberOld = threadBoardReplyNumber
        threadRepliesImagesOld = threadRepliesImages
        
        // Clear current data
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        
        // Organize thread
        if let thread = threadBoardReplies[threadBoardReplyNumberOld[tag]] {
            var threadWithFirst = [threadBoardReplyNumberOld[tag]]
            threadWithFirst.append(contentsOf: thread)
            threadBoardReplyNumber = threadWithFirst
            
            // Rebuild content arrays
            for boardNumber in threadBoardReplyNumber {
                if let index = threadBoardReplyNumberOld.firstIndex(of: boardNumber) {
                    threadReplies.append(threadRepliesOld[index])
                    threadRepliesImages.append(threadRepliesImagesOld[index])
                }
            }
        }
        
        replyCount = threadReplies.count
        threadReplyCVOutlet.reloadData()
    }
    
    @objc func refresh() {
        replyCount = 0
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        threadReplyCVOutlet.reloadData()
        getThreadData()
    }
    
    @objc func down() {
        threadReplyCVOutlet.scrollToLast()
    }
    
    @objc func completeThread() {
        // Restore navigation bar
        setupNavigationBar()
        
        // Restore full thread
        threadReplies = threadRepliesOld
        threadBoardReplyNumber = threadBoardReplyNumberOld
        threadRepliesImages = threadRepliesImagesOld
        
        threadRepliesOld.removeAll()
        threadBoardReplyNumberOld.removeAll()
        threadRepliesImagesOld.removeAll()
        
        replyCount = threadReplies.count
        threadReplyCVOutlet.reloadData()
    }
}

// MARK: - Collection View Data Source
extension threadRepliesCV {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return replyCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "threadReplyCell", for: indexPath) as! threadReplyCell
        
        if threadReplies.isEmpty {
            configureLoadingCell(cell)
        } else {
            configureCell(cell, at: indexPath)
        }
        
        return cell
    }
    
    private func configureLoadingCell(_ cell: threadReplyCell) {
        cell.boardReplyCount.text = "Loading..."
        cell.threadReplyCount.text = "Loading..."
        cell.replyText.text = "Loading..."
    }
    
    private func configureCell(_ cell: threadReplyCell, at indexPath: IndexPath) {
        // Configure thread button visibility
        let hasThread = threadBoardReplies[threadBoardReplyNumber[indexPath.row]]?.isEmpty == false
        let isFullThread = threadRepliesOld.isEmpty
        cell.thread.isHidden = !(hasThread && isFullThread)
        
        if !cell.thread.isHidden {
            cell.thread.tag = indexPath.row
            cell.thread.addTarget(self, action: #selector(showThread), for: .touchUpInside)
        }
        
        // Set reply counts
        cell.boardReplyCount.text = threadBoardReplyNumber[indexPath.row]
        cell.threadReplyCount.text = String(indexPath.row + 1)
        
        // Configure content
        let imageUrl = threadRepliesImages[indexPath.row]
        if imageUrl.contains("nullnull") {
            configureTextOnlyCell(cell, at: indexPath)
        } else {
            configureMediaCell(cell, at: indexPath, imageUrl: imageUrl)
        }
    }
    
    private func configureTextOnlyCell(_ cell: threadReplyCell, at indexPath: IndexPath) {
        cell.replyTextNoImage.isHidden = false
        cell.replyText.isHidden = true
        cell.threadImage.isHidden = true
        cell.replyTextNoImage.text = threadReplies[indexPath.row].replacingOccurrences(of: "null", with: "")
    }
    
    private func configureMediaCell(_ cell: threadReplyCell, at indexPath: IndexPath, imageUrl: String) {
        
        cell.replyTextNoImage.isHidden = true
        cell.replyText.isHidden = false
        cell.threadImage.isHidden = false
        cell.replyText.text = threadReplies[indexPath.row].replacingOccurrences(of: "null", with: "")
                
        let finalImageUrl: String
            if imageUrl.contains(".webm") {
                finalImageUrl = imageUrl.replacingOccurrences(of: ".webm", with: "s.jpg")
            } else {
                finalImageUrl = imageUrl
            }
                
            // Correct way to set image on UIButton using Kingfisher
            if let url = URL(string: finalImageUrl) {
                cell.threadImage.kf.setImage(with: url, for: .normal)
            }
                
            cell.threadImage.tag = indexPath.row
            cell.threadImage.layer.cornerRadius = 12
            cell.threadImage.contentMode = .scaleAspectFill
            cell.threadImage.addTarget(self, action: #selector(threadContentOpen), for: .touchUpInside)
        
    }
    
}
