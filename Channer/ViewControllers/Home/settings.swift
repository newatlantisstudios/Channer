import UIKit

class settings: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    let boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    let boardAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]

    var pickerView: UIPickerView!
    var label: UILabel!
    let userDefaultsKey = "defaultBoard"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor // Using our theme manager for consistency

        // Create and configure label
        label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // Create and configure picker view
        pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pickerView)

        // Add constraints
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100), // Position label vertically centered above picker
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            pickerView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20) // Adjust spacing
        ])

        // Load saved default board and update label
        updateDefaultBoardLabel()

        // Set picker selection to saved default board
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey),
           let index = boardAbv.firstIndex(of: savedDefault) {
            pickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }

    private func updateDefaultBoardLabel() {
        if let savedDefault = UserDefaults.standard.string(forKey: userDefaultsKey),
           let index = boardAbv.firstIndex(of: savedDefault) {
            label.text = "Start Up Board: \(boardNames[index])"
        } else {
            label.text = "Default Board: None"
        }
    }

    // MARK: - UIPickerView Delegate & DataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return boardNames.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return boardNames[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedBoardAbv = boardAbv[row]
        UserDefaults.standard.set(selectedBoardAbv, forKey: userDefaultsKey)
        // Update label and debugging output
        updateDefaultBoardLabel()
        print("Selected Board: \(boardNames[row]) (\(selectedBoardAbv))")
    }
}
