// 
//  threadRepliesCV.swift
//  Channer
//
//  Created by x on 4/15/19.
//  Copyright © 2019 x. All rights reserved.
//

import UIKit
import Kingfisher

/// iPad-optimized collection view controller for displaying thread replies
/// Uses collection view layout for better performance on larger iPad screens
class threadRepliesCV: UICollectionViewController {
    
    // MARK: - HTML Parsing Methods
    
    /// Extracts reply number from HTML text
    /// - Parameter text: HTML string containing reply number
    /// - Returns: Reply number string or "None" if not found
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
    
    /// Extracts and processes date from HTML text
    /// - Parameter text: HTML string containing dateTime class
    /// - Returns: Processed date string or error message
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
    
    /// Extracts reply text content from HTML
    /// - Parameter text: HTML string containing post message
    /// - Returns: Extracted message content or error message
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
    
    // MARK: - Properties
    
    /// Counter for replies with numbers
    var repliesWithNo = 0
    
    /// Current thread number
    var threadNumber = ""
    /// Current board abbreviation
    var boardAbv = ""
    /// Flag indicating if viewing board thread list
    var forBoardThread = Bool()
    /// Current reply number being viewed
    var replyNumber = ""
    
    /// Array of thread reply image URLs
    var threadRepliesImages: [String] = []
    /// Array of thread reply content
    var threadReplies: [String] = []
    /// Backup array of old thread replies
    var threadRepliesOld: [String] = []
    /// Array of thread board reply numbers
    var threadBoardReplyNumber: [String] = []
    /// Dictionary mapping thread boards to their replies
    var threadBoardReplies: [String: [String]] = [:]
    
    /// Array of thread post IDs
    var threadPostId = [String]()
    /// Dictionary mapping board posts to their replies
    var boardPostReplies: [String: [String]] = [:]
    
    /// Flag indicating if current view is a reply
    var isReply: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView?.backgroundColor = ThemeManager.shared.appBackgroundColor

        // Setup navigation items
        setupNavigationItems()

        //register cell
        //collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "threadReplyCell")
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        
        let width = UIScreen.main.bounds.width
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        layout.itemSize = CGSize(width: width, height: 200)
        
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView!.collectionViewLayout = layout
        
        // Improved scrolling performance for iPad
        collectionView?.decelerationRate = UIScrollView.DecelerationRate.fast
        collectionView?.showsVerticalScrollIndicator = true
        collectionView?.bounces = true
        collectionView?.alwaysBounceVertical = true
        collectionView?.scrollsToTop = true
        
        // Optimize for smooth scrolling
        if #available(iOS 15.0, *) {
            collectionView?.isPrefetchingEnabled = true
        }
        
        // Memory optimization
        collectionView?.remembersLastFocusedIndexPath = false
        
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
                    // Remove any border
                    cell.threadImage.layer.borderWidth = 0.0
                    
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
        
        print("Debug (iPad): Configuring media cell with image URL: \(imageUrl)")
                
        let finalImageUrl: String
        if imageUrl.contains(".webm") {
            finalImageUrl = imageUrl.replacingOccurrences(of: ".webm", with: "s.jpg")
            print("Debug (iPad): Using JPG thumbnail for WebM: \(finalImageUrl)")
        } else if imageUrl.contains(".mp4") {
            finalImageUrl = imageUrl.replacingOccurrences(of: ".mp4", with: "s.jpg")
            print("Debug (iPad): Using JPG thumbnail for MP4: \(finalImageUrl)")
        } else if imageUrl.contains(".png") {
            // Get thumbnail URL for PNG image - 4chan uses JPG thumbnails even for PNG files
            let components = imageUrl.components(separatedBy: "/")
            if let last = components.last, let range = last.range(of: ".") {
                let filename = String(last[..<range.lowerBound])
                // Always use .jpg extension for thumbnails, even for PNG files
                let thumbnailFilename = filename + "s.jpg"
                finalImageUrl = imageUrl.replacingOccurrences(of: last, with: thumbnailFilename)
                print("Debug (iPad): Using JPG thumbnail for PNG: \(finalImageUrl)")
            } else {
                finalImageUrl = imageUrl
                print("Debug (iPad): Using original PNG URL: \(finalImageUrl)")
            }
        } else {
            // Default JPG handling
            let components = imageUrl.components(separatedBy: "/")
            if let last = components.last, let range = last.range(of: ".") {
                let filename = String(last[..<range.lowerBound])
                let thumbnailFilename = filename + "s.jpg"
                finalImageUrl = imageUrl.replacingOccurrences(of: last, with: thumbnailFilename)
                print("Debug (iPad): Using JPG thumbnail: \(finalImageUrl)")
            } else {
                finalImageUrl = imageUrl
                print("Debug (iPad): Using original URL: \(finalImageUrl)")
            }
        }
                
        // Correct way to set image on UIButton using Kingfisher
        if let url = URL(string: finalImageUrl) {
            // Use enhanced options for better loading
            let options: KingfisherOptionsInfo = [
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.2)),
                .cacheOriginalImage,
                .backgroundDecode,
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1)))
            ]
            
            cell.threadImage.kf.setImage(
                with: url,
                for: .normal,
                options: options) { result in
                    switch result {
                    case .success:
                        print("Debug (iPad): Successfully loaded image: \(url)")
                    case .failure(let error):
                        print("Debug (iPad): Failed to load image: \(error.localizedDescription)")
                        
                        // We shouldn't need fallbacks anymore since we're always using JPG thumbnails,
                        // but let's keep this just in case for robustness
                        if finalImageUrl.hasSuffix(".png") {
                            let jpgUrl = finalImageUrl.replacingOccurrences(of: ".png", with: ".jpg")
                            print("Debug (iPad): Thumbnail loading failed. Trying explicit JPG fallback: \(jpgUrl)")
                            
                            if let fallbackUrl = URL(string: jpgUrl) {
                                cell.threadImage.kf.setImage(with: fallbackUrl, for: .normal, options: options)
                            }
                        }
                    }
                }
        }
                
        cell.threadImage.tag = indexPath.row
        cell.threadImage.layer.cornerRadius = 12
        cell.threadImage.contentMode = .scaleAspectFill
        cell.threadImage.addTarget(self, action: #selector(threadContentOpen), for: .touchUpInside)
        
        // Store the original high-quality image URL for hover preview
        cell.setImageURL(imageUrl)
        print("Debug (iPad): Stored full image URL for tap action: \(imageUrl)")
    }
    
    // MARK: - Actions
    @objc func threadContentOpen(_ sender: UIButton) {
        // Get the selected image URL
        let selectedIndex = sender.tag
        guard selectedIndex < threadRepliesImages.count else {
            print("Debug (iPad): Invalid image index")
            return
        }
        
        let selectedImageURL = threadRepliesImages[selectedIndex]
        print("Debug (iPad): Opening image at index \(selectedIndex): \(selectedImageURL)")
        
        // Check if this is a PNG image that might need special handling
        if selectedImageURL.contains(".png") {
            print("Debug (iPad): PNG image detected in threadContentOpen")
        }
        
        // Set up the gallery view controller with potentially corrected image URLs
        let segue = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "imageGrid") as! ImageGalleryVC
        
        // For ImageGalleryVC, we need to make sure we're passing the correct full-size URLs, not thumbnails
        let processedImageLinks = threadRepliesImages.map { url -> String in
            // If the URL contains "s.jpg" but is actually a PNG, correct it
            if url.contains("s.jpg") && url.contains(".png") {
                return url.replacingOccurrences(of: "s.jpg", with: ".png")
            }
            return url
        }
        
        segue.imagesLinks = processedImageLinks
        segue.selectedIndex = selectedIndex
        segue.currentTableView = nil
        segue.currentCollectionView = collectionView
        
        print("Debug (iPad): Presenting image gallery with \(processedImageLinks.count) images")
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

    // MARK: - Navigation Items

    private func setupNavigationItems() {
        // Create the Reply button
        let replyImage = UIImage(systemName: "square.and.pencil")
        let replyButton = UIBarButtonItem(image: replyImage,
                                          style: .plain,
                                          target: self,
                                          action: #selector(showComposeView))

        navigationItem.rightBarButtonItems = [replyButton]
    }

    @objc private func showComposeView() {
        showComposeView(quotePostNumber: nil)
    }

    private func showComposeView(quotePostNumber: Int?) {
        guard let threadNum = Int(threadNumber) else { return }

        var quoteText: String? = nil
        if let postNum = quotePostNumber {
            quoteText = ">>\(postNum)\n"
        }

        let composeVC = ComposeViewController(board: boardAbv, threadNumber: threadNum, quoteText: quoteText)
        composeVC.delegate = self
        let navController = UINavigationController(rootViewController: composeVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
}

// MARK: - ComposeViewControllerDelegate
extension threadRepliesCV: ComposeViewControllerDelegate {
    func composeViewControllerDidPost(_ controller: ComposeViewController, postNumber: Int?) {
        // Track user's post for reply notifications
        if let postNo = postNumber {
            MyPostsManager.shared.addUserPost(
                boardAbv: boardAbv,
                threadNo: threadNumber,
                postNo: String(postNo),
                postText: ""
            )
        }

        // Show success message
        let message = postNumber != nil ? "Post #\(postNumber!) submitted successfully" : "Post submitted successfully"
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func composeViewControllerDidCancel(_ controller: ComposeViewController) {
        // No action needed
    }
}