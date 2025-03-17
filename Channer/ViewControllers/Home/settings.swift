import UIKit

class settings: UIViewController, UISearchBarDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties
    var boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    var boardAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
    
    // Filtered arrays for search functionality
    private var filteredBoardNames: [String] = []
    private var filteredBoardAbv: [String] = []
    
    // UI Components
    private let headerLabel = UILabel()
    private let searchBar = UISearchBar()
    private let collectionView: UICollectionView
    private let selectedBoardView = UIView()
    private let selectedBoardLabel = UILabel()
    
    // Constants
    private let cellIdentifier = "BoardCell"
    private let userDefaultsKey = "defaultBoard"
    private let sectionInset: CGFloat = 16
    private let interItemSpacing: CGFloat = 10
    private let lineSpacing: CGFloat = 10
    
    // MARK: - Initialization
    init() {
        let layout = UICollectionViewFlowLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        sortBoardsAlphabetically()
        setupUI()
        filteredBoardNames = boardNames
        filteredBoardAbv = boardAbv
    }
    
    private func sortBoardsAlphabetically() {
        // Create array of tuples containing both board name and abbreviation
        let combinedBoards = zip(boardNames, boardAbv).map { ($0, $1) }
        
        // Sort the combined array by board name
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        
        // Update the original arrays with sorted values
        boardNames = sortedBoards.map { $0.0 }
        boardAbv = sortedBoards.map { $0.1 }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Header Label
        headerLabel.text = "Choose Your Start Up Board"
        headerLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // Search Bar
        searchBar.placeholder = "Search Boards"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        view.addSubview(searchBar)
        
        // Selected Board View
        selectedBoardView.backgroundColor = UIColor.systemGray5
        selectedBoardView.layer.cornerRadius = 12
        selectedBoardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedBoardView)
        
        // Selected Board Label
        selectedBoardLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        selectedBoardLabel.textAlignment = .center
        selectedBoardLabel.translatesAutoresizingMaskIntoConstraints = false
        updateSelectedBoardLabel()
        selectedBoardView.addSubview(selectedBoardLabel)
        
        // Collection View
        collectionView.register(BoardCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsVerticalScrollIndicator = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header Label
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            
            // Selected Board View
            selectedBoardView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 16),
            selectedBoardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectedBoardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectedBoardView.heightAnchor.constraint(equalToConstant: 50),
            
            // Selected Board Label
            selectedBoardLabel.centerYAnchor.constraint(equalTo: selectedBoardView.centerYAnchor),
            selectedBoardLabel.leadingAnchor.constraint(equalTo: selectedBoardView.leadingAnchor, constant: 16),
            selectedBoardLabel.trailingAnchor.constraint(equalTo: selectedBoardView.trailingAnchor, constant: -16),
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: selectedBoardView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    private func updateSelectedBoardLabel() {
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey),
           let index = boardAbv.firstIndex(of: savedDefault) {
            selectedBoardLabel.text = "\(boardNames[index]) (/\(savedDefault)/)"
        } else {
            selectedBoardLabel.text = "No default board selected"
        }
    }
    
    private func selectBoard(at indexPath: IndexPath) {
        let selectedBoardAbv = filteredBoardAbv[indexPath.item]
        UserDefaults.standard.set(selectedBoardAbv, forKey: userDefaultsKey)
        updateSelectedBoardLabel()
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Flash the selected board view to indicate change
        UIView.animate(withDuration: 0.2, animations: {
            self.selectedBoardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.selectedBoardView.backgroundColor = UIColor.systemGray5
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredBoardNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? BoardCell else {
            fatalError("Failed to dequeue BoardCell")
        }
        
        let boardName = filteredBoardNames[indexPath.item]
        let boardCode = filteredBoardAbv[indexPath.item]
        cell.configure(boardName: boardName, boardCode: boardCode)
        
        // Highlight the cell if it's the currently selected default board
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey), 
           savedDefault == boardCode {
            cell.isSelected = true
            cell.setSelected(true)
        } else {
            cell.isSelected = false
            cell.setSelected(false)
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectBoard(at: indexPath)
        collectionView.reloadData()
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate width based on number of cells per row
        let cellsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = collectionView.bounds.width - (sectionInset * 2) - (interItemSpacing * (cellsPerRow - 1))
        let cellWidth = availableWidth / cellsPerRow
        
        return CGSize(width: cellWidth, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: sectionInset, bottom: 0, right: sectionInset)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return interItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return lineSpacing
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredBoardNames = boardNames
            filteredBoardAbv = boardAbv
        } else {
            let searchTextLowercased = searchText.lowercased()
            
            // Filter by both board name and abbreviation
            let filteredIndices = boardNames.indices.filter { index in
                boardNames[index].lowercased().contains(searchTextLowercased) || 
                boardAbv[index].lowercased().contains(searchTextLowercased)
            }
            
            filteredBoardNames = filteredIndices.map { boardNames[$0] }
            filteredBoardAbv = filteredIndices.map { boardAbv[$0] }
        }
        
        collectionView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - BoardCell
class BoardCell: UICollectionViewCell {
    private let nameLabel = UILabel()
    private let codeLabel = UILabel()
    private let stackView = UIStackView()
    
    override var isSelected: Bool {
        didSet {
            setSelected(isSelected)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Cell appearance
        contentView.backgroundColor = UIColor.systemGray6
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        
        // Stack View
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Name Label
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        
        // Code Label
        codeLabel.font = UIFont.systemFont(ofSize: 12)
        codeLabel.textAlignment = .center
        codeLabel.textColor = UIColor.systemGray
        
        // Add labels to stack view
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(codeLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(boardName: String, boardCode: String) {
        nameLabel.text = boardName
        codeLabel.text = "/\(boardCode)/"
    }
    
    func setSelected(_ selected: Bool) {
        if selected {
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            contentView.backgroundColor = UIColor.systemGray6
            contentView.layer.borderWidth = 0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        setSelected(false)
    }
}
