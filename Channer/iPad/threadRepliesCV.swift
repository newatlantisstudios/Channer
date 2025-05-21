// 
//  threadRepliesCV.swift
//  Channer
//
//  Created by x on 4/15/19.
//  Copyright © 2019 x. All rights reserved.
//

import UIKit
import Kingfisher

class threadRepliesCV: UICollectionViewController {
    
    func replyNo(_ text: String) ->String {
        
        if let a: Range = text.range(of: "id=\"p") {
            let str1 = text[a.upperBound...]
            var i = 0
            if let i1: String.Index = str1.firstIndex(of: "\"") {
                i = str1.distance(from: str1.startIndex, to: i1)
            }
            
            let endIndex = str1.index(str1.startIndex, offsetBy: i)
            
            return String(str1[str1.startIndex..<endIndex])
        }
        return "None"
    }
    
    func processDate(_ text: String) ->String {
        
        if let a: Range = text.range(of: "class=\"dateTime") {
            var str1 = text[a.upperBound...]
            if let b: Range = str1.range(of: ">") {
                str1 = str1[b.upperBound...]
                
                var i = 0
                if let i1: String.Index = str1.firstIndex(of: "<") {
                    i = str1.distance(from: str1.startIndex, to: i1)
                }
                
                let endIndex = str1.index(str1.startIndex, offsetBy: i)
                
                return String(str1[str1.startIndex..<endIndex])
            }
            return "error1"
        }
        return "error2"
    }
    
    func replyText(_ text: String) ->String {
        //class="postMessage"
        if let a: Range = text.range(of: "class=\"postMessage") {
            var str1 = text[a.upperBound...]
            if let b: Range = str1.range(of: "\">") {
                str1 = str1[b.upperBound...]
                
                if let c: Range = str1.range(of: "</blockquote") {
                    
                    return "<blockquote " + String(str1[str1.startIndex..<c.lowerBound])
                    
                }
                
                return "blockquoteerror"
            }
            return "poMerror"
        }
        return "error"
    }
    
    var repliesWithNo = 0
    
    var threadNumber = ""
    var boardAbv = ""
    var forBoardThread = Bool()
    var replyNumber = ""
    
    var threadRepliesImages: [String] = []
    var threadReplies: [String] = []
    var threadRepliesOld: [String] = []
    var threadBoardReplyNumber: [String] = []
    var threadBoardReplies: [String: [String]] = [:]
    
    var threadPostId = [String]()
    var boardPostReplies: [String: [String]] = [:]
    
    // Current view is a reply
    var isReply: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.backgroundColor = ThemeManager.shared.appBackgroundColor
        
        //register cell
        //collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "threadReplyCell")
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        
        let width = UIScreen.main.bounds.width
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        layout.itemSize = CGSize(width: width, height: 200)
        
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView!.collectionViewLayout = layout
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let jsonFile = documentsDirectory.appendingPathComponent(boardAbv + "-" + threadNumber + ".json")
        let txtFile = documentsDirectory.appendingPathComponent(boardAbv + "-" + threadNumber + ".txt")
        
        if !forBoardThread { // Thread
            
            threadBoardReplies.removeAll()
            
            let string = try! String(contentsOf: txtFile, encoding: String.Encoding.utf8)
            
            for line in string.components(separatedBy: "\n") {
                
                if repliesWithNo % 2 == 0 {
                    guard line != "" else {
                        continue
                    }
                    
                    threadPostId.append(line)
                } else {
                    guard line != "" else {
                        continue
                    }
                    
                    var nArray: [String] = []
                    
                    for n in line.components(separatedBy: ",") {
                        nArray.append(n)
                    }
                    
                    boardPostReplies[threadPostId[repliesWithNo / 2]] = nArray
                }
                
                repliesWithNo += 1
            }
            
            for (postId, replies) in boardPostReplies {
                /*
                for r in replies {
                //print("post id: \(postId) has reply: \(r)")
                threadBoardReplies[r] = [postId]
                */
                for r in replies {
                    if var existingReplies = threadBoardReplies[r] {
                        existingReplies.append(postId)
                        threadBoardReplies[r] = existingReplies
                    } else {
                        threadBoardReplies[r] = [postId]
                    }
                }
            }
            
            let html = try! Data(contentsOf: jsonFile)
            let json = try! JSONSerialization.jsonObject(with: html, options: []) as! [String:Any]
            let posts = json["posts"] as! [[String:Any]]
            
            for dict in posts {
                
                if let imgName = dict["tim"] as? Int, let ext = dict["ext"] as? String {
                    let fileUrl = "https://i.4cdn.org/\(boardAbv)/\(imgName)\(ext)"
                    threadRepliesImages.append(fileUrl)
                } else {
                    threadRepliesImages.append("https://i.4cdn.org/\(boardAbv)/")
                }
                
                if let comment = dict["com"] as? String {
                    threadReplies.append(comment)
                } else {
                    threadReplies.append(" ")
                }
                
                if let num = dict["no"] as? Int {
                    threadBoardReplyNumber.append(String(num))
                }
                
            }
        } else { // Replies
        
            let html = try! Data(contentsOf: jsonFile)
            let json = try! JSONSerialization.jsonObject(with: html, options: []) as! [String:Any]
            let posts = json["posts"] as! [[String:Any]]
            
            var foundReplyNumber = false
            var gotReplies = false
            
            threadRepliesOld = threadReplies
            threadReplies = []
            threadRepliesImages = []
            threadBoardReplyNumber = []
            
            for dict in posts {
                
                if let num = dict["no"] as? Int {
                    
                    if replyNumber == String(num) {
                        foundReplyNumber = true
                    }
                    
                    if !foundReplyNumber || !gotReplies {
                        continue
                    }
                    
                    
                    if let imgName = dict["tim"] as? Int, let ext = dict["ext"] as? String {
                        let fileUrl = "https://i.4cdn.org/\(boardAbv)/\(imgName)\(ext)"
                        threadRepliesImages.append(fileUrl)
                    } else {
                        threadRepliesImages.append("https://i.4cdn.org/\(boardAbv)/")
                    }
                    
                    if let comment = dict["com"] as? String {
                        threadReplies.append(comment)
                    } else {
                        threadReplies.append(" ")
                    }
                    
                    threadBoardReplyNumber.append(String(num))
                    
                }
                
                if !gotReplies && foundReplyNumber {
                    
                    if let imgName = dict["tim"] as? Int, let ext = dict["ext"] as? String {
                        let fileUrl = "https://i.4cdn.org/\(boardAbv)/\(imgName)\(ext)"
                        threadRepliesImages.append(fileUrl)
                    } else {
                        threadRepliesImages.append("https://i.4cdn.org/\(boardAbv)/")
                    }
                    
                    if let comment = dict["com"] as? String {
                        threadReplies.append(comment)
                    } else {
                        threadReplies.append(" ")
                    }
                    
                    if let num = dict["no"] as? Int {
                        threadBoardReplyNumber.append(String(num))
                    }
                    
                    gotReplies = true
                }
                
            }
            
        }
        
        collectionView?.reloadData()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return threadReplies.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "threadReplyCell", for: indexPath) as! threadReplyCell
        
        // Set up hover features for Apple Pencil
        if #available(iOS 13.4, *) {
            // Configure hover for thread image button if we have an image URL
            if indexPath.row < threadRepliesImages.count {
                let imageUrl = threadRepliesImages[indexPath.row]
                let hasImage = imageUrl != "https://i.4cdn.org/\(boardAbv)/"
                
                if hasImage && cell.threadImage != nil {
                    // Visual indicator for hover capability
                    cell.threadImage.layer.borderWidth = 1.0
                    cell.threadImage.layer.borderColor = UIColor.systemBlue.cgColor
                    
                    // Store image URL for hover preview
                    cell.setImageURL(imageUrl)
                    
                    print("iPad: Hover support enabled for cell \(indexPath.row)")
                }
            }
        }
        
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
        
            // Store image URL for hover preview
            cell.setImageURL(finalImageUrl)
    }
    
    // MARK: - Actions
    @objc func threadContentOpen(_ sender: UIButton) {
        let segue = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "imageGrid") as! ImageGalleryVC
        
        segue.imagesLinks = threadRepliesImages
        segue.selectedIndex = sender.tag
        segue.currentTableView = nil
        segue.currentCollectionView = collectionView
        
        self.present(segue, animated: true, completion: nil)
    }
    
    @objc func showThread(_ sender: UIButton) {
        
        let storyBoard = UIStoryboard(name: "iPad", bundle: nil)
        
        let replyVC = storyBoard.instantiateViewController(withIdentifier: "threadReplyVC") as! threadRepliesCV
        replyVC.replyNumber = threadBoardRepliesArray(indexPath: sender.tag)[0]
        replyVC.threadNumber = threadNumber
        replyVC.boardAbv = boardAbv
        replyVC.forBoardThread = true
        replyVC.isReply = true
        replyVC.modalPresentationStyle = .fullScreen
        
        present(replyVC, animated: true, completion: nil)
    }
    
    func threadBoardRepliesArray(indexPath: Int) -> [String] {
        
        if threadBoardReplies[threadBoardReplyNumber[indexPath]] != nil {
            return threadBoardReplies[threadBoardReplyNumber[indexPath]]!
        }
        
        return []
    }
    
    @IBAction func closeButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}