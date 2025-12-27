import UIKit

/// Delegate for compose view controller actions
protocol ComposeViewControllerDelegate: AnyObject {
    func composeViewControllerDidPost(_ controller: ComposeViewController, postNumber: Int?)
    func composeViewControllerDidCancel(_ controller: ComposeViewController)
    func composeViewControllerDidMinimize(_ controller: ComposeViewController)
}

/// View controller for composing posts and replies
class ComposeViewController: UIViewController {

    // MARK: - Properties

    /// Board abbreviation
    let board: String

    /// Thread number (0 for new thread)
    let threadNumber: Int

    /// Optional quote text to insert
    var quoteText: String?

    /// Delegate for actions
    weak var delegate: ComposeViewControllerDelegate?

    /// Whether this is a new thread
    var isNewThread: Bool { threadNumber == 0 }

    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let subjectField = UITextField()
    private let commentTextView = UITextView()
    private let characterCountLabel = UILabel()

    private let imageButton = UIButton(type: .system)
    private let imagePreviewView = UIImageView()
    private let removeImageButton = UIButton(type: .close)
    private let spoilerSwitch = UISwitch()
    private let spoilerLabel = UILabel()

    // Filename UI
    private let filenameContainerView = UIView()
    private let filenameLabel = UILabel()
    private let filenameField = UITextField()
    private let randomizeButton = UIButton(type: .system)

    private let postButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // State
    private var selectedImage: SelectedImage?
    private let imagePicker = ImagePickerHelper()
    private var isPosting = false

    // Constants
    private let maxCommentLength = 2000

    // MARK: - Initialization

    init(board: String, threadNumber: Int = 0, quoteText: String? = nil) {
        self.board = board
        self.threadNumber = threadNumber
        self.quoteText = quoteText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()

        // Insert quote if provided
        if let quote = quoteText {
            commentTextView.text = quote + "\n"
            updateCharacterCount()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        commentTextView.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = isNewThread ? "New Thread" : "Reply"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // Navigation buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        // Right side: minimize and post buttons
        let minimizeButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down.circle"),
            style: .plain,
            target: self,
            action: #selector(minimizeTapped)
        )
        let postButton = UIBarButtonItem(
            title: "Post",
            style: .done,
            target: self,
            action: #selector(postTapped)
        )
        navigationItem.rightBarButtonItems = [postButton, minimizeButton]

        setupScrollView()
        setupNameField()
        setupEmailField()

        if isNewThread {
            setupSubjectField()
        }

        setupCommentTextView()
        setupImageSection()
        setupConstraints()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }

    private func setupNameField() {
        nameField.placeholder = "Name (optional)"
        nameField.font = UIFont.systemFont(ofSize: 16)
        nameField.textColor = ThemeManager.shared.primaryTextColor
        nameField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        nameField.layer.cornerRadius = 8
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        nameField.leftViewMode = .always
        nameField.returnKeyType = .next
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameField)
    }

    private func setupEmailField() {
        emailField.placeholder = "Email/Options (optional)"
        emailField.font = UIFont.systemFont(ofSize: 16)
        emailField.textColor = ThemeManager.shared.primaryTextColor
        emailField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        emailField.layer.cornerRadius = 8
        emailField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        emailField.leftViewMode = .always
        emailField.autocapitalizationType = .none
        emailField.keyboardType = .emailAddress
        emailField.returnKeyType = .next
        emailField.delegate = self
        emailField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emailField)
    }

    private func setupSubjectField() {
        subjectField.placeholder = "Subject"
        subjectField.font = UIFont.systemFont(ofSize: 16)
        subjectField.textColor = ThemeManager.shared.primaryTextColor
        subjectField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        subjectField.layer.cornerRadius = 8
        subjectField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        subjectField.leftViewMode = .always
        subjectField.returnKeyType = .next
        subjectField.delegate = self
        subjectField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subjectField)
    }

    private func setupCommentTextView() {
        commentTextView.font = UIFont.systemFont(ofSize: 16)
        commentTextView.textColor = ThemeManager.shared.primaryTextColor
        commentTextView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        commentTextView.layer.cornerRadius = 8
        commentTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        commentTextView.delegate = self
        commentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(commentTextView)

        characterCountLabel.font = UIFont.systemFont(ofSize: 12)
        characterCountLabel.textColor = ThemeManager.shared.secondaryTextColor
        characterCountLabel.textAlignment = .right
        characterCountLabel.text = "0/\(maxCommentLength)"
        characterCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(characterCountLabel)
    }

    private func setupImageSection() {
        // Image button
        imageButton.setTitle("  Attach Image", for: .normal)
        imageButton.setImage(UIImage(systemName: "photo"), for: .normal)
        imageButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        imageButton.backgroundColor = ThemeManager.shared.cellBackgroundColor
        imageButton.layer.cornerRadius = 8
        imageButton.addTarget(self, action: #selector(attachImageTapped), for: .touchUpInside)
        imageButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageButton)

        // Image preview
        imagePreviewView.contentMode = .scaleAspectFit
        imagePreviewView.layer.cornerRadius = 8
        imagePreviewView.clipsToBounds = true
        imagePreviewView.isHidden = true
        imagePreviewView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imagePreviewView)

        // Remove image button
        removeImageButton.addTarget(self, action: #selector(removeImageTapped), for: .touchUpInside)
        removeImageButton.isHidden = true
        removeImageButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(removeImageButton)

        // Spoiler switch
        spoilerLabel.text = "Spoiler Image"
        spoilerLabel.font = UIFont.systemFont(ofSize: 14)
        spoilerLabel.textColor = ThemeManager.shared.secondaryTextColor
        spoilerLabel.isHidden = true
        spoilerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spoilerLabel)

        spoilerSwitch.isHidden = true
        spoilerSwitch.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spoilerSwitch)

        // Filename section
        setupFilenameSection()

        // Activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
    }

    private func setupFilenameSection() {
        // Container view (hidden by default)
        filenameContainerView.isHidden = true
        filenameContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(filenameContainerView)

        // Filename label
        filenameLabel.text = "Filename:"
        filenameLabel.font = UIFont.systemFont(ofSize: 14)
        filenameLabel.textColor = ThemeManager.shared.secondaryTextColor
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        filenameContainerView.addSubview(filenameLabel)

        // Filename text field
        filenameField.font = UIFont.systemFont(ofSize: 14)
        filenameField.textColor = ThemeManager.shared.primaryTextColor
        filenameField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        filenameField.layer.cornerRadius = 6
        filenameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        filenameField.leftViewMode = .always
        filenameField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        filenameField.rightViewMode = .always
        filenameField.placeholder = "Enter filename"
        filenameField.returnKeyType = .done
        filenameField.delegate = self
        filenameField.addTarget(self, action: #selector(filenameFieldChanged), for: .editingChanged)
        filenameField.translatesAutoresizingMaskIntoConstraints = false
        filenameContainerView.addSubview(filenameField)

        // Randomize button
        randomizeButton.setImage(UIImage(systemName: "shuffle"), for: .normal)
        randomizeButton.setTitle(" Random", for: .normal)
        randomizeButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        randomizeButton.backgroundColor = ThemeManager.shared.cellBackgroundColor
        randomizeButton.layer.cornerRadius = 6
        randomizeButton.addTarget(self, action: #selector(randomizeFilenameTapped), for: .touchUpInside)
        randomizeButton.translatesAutoresizingMaskIntoConstraints = false
        filenameContainerView.addSubview(randomizeButton)

        // Constraints for filename section
        NSLayoutConstraint.activate([
            filenameContainerView.topAnchor.constraint(equalTo: imagePreviewView.bottomAnchor, constant: 12),
            filenameContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            filenameContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            filenameContainerView.heightAnchor.constraint(equalToConstant: 36),

            filenameLabel.leadingAnchor.constraint(equalTo: filenameContainerView.leadingAnchor),
            filenameLabel.centerYAnchor.constraint(equalTo: filenameContainerView.centerYAnchor),
            filenameLabel.widthAnchor.constraint(equalToConstant: 70),

            filenameField.leadingAnchor.constraint(equalTo: filenameLabel.trailingAnchor, constant: 8),
            filenameField.centerYAnchor.constraint(equalTo: filenameContainerView.centerYAnchor),
            filenameField.heightAnchor.constraint(equalToConstant: 32),

            randomizeButton.leadingAnchor.constraint(equalTo: filenameField.trailingAnchor, constant: 8),
            randomizeButton.trailingAnchor.constraint(equalTo: filenameContainerView.trailingAnchor),
            randomizeButton.centerYAnchor.constraint(equalTo: filenameContainerView.centerYAnchor),
            randomizeButton.widthAnchor.constraint(equalToConstant: 80),
            randomizeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupConstraints() {
        let topAnchor = isNewThread ? subjectField.bottomAnchor : emailField.bottomAnchor

        var constraints = [
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Name field
            nameField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameField.heightAnchor.constraint(equalToConstant: 44),

            // Email field
            emailField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            emailField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            emailField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            emailField.heightAnchor.constraint(equalToConstant: 44),

            // Comment text view
            commentTextView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            commentTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            commentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            commentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            // Character count
            characterCountLabel.topAnchor.constraint(equalTo: commentTextView.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Image button
            imageButton.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: 16),
            imageButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageButton.heightAnchor.constraint(equalToConstant: 44),

            // Image preview
            imagePreviewView.topAnchor.constraint(equalTo: imageButton.bottomAnchor, constant: 12),
            imagePreviewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imagePreviewView.widthAnchor.constraint(equalToConstant: 100),
            imagePreviewView.heightAnchor.constraint(equalToConstant: 100),

            // Remove image button
            removeImageButton.topAnchor.constraint(equalTo: imagePreviewView.topAnchor, constant: -8),
            removeImageButton.trailingAnchor.constraint(equalTo: imagePreviewView.trailingAnchor, constant: 8),

            // Spoiler label
            spoilerLabel.centerYAnchor.constraint(equalTo: imagePreviewView.centerYAnchor),
            spoilerLabel.leadingAnchor.constraint(equalTo: imagePreviewView.trailingAnchor, constant: 16),

            // Spoiler switch
            spoilerSwitch.centerYAnchor.constraint(equalTo: spoilerLabel.centerYAnchor),
            spoilerSwitch.leadingAnchor.constraint(equalTo: spoilerLabel.trailingAnchor, constant: 8),

            // Bottom spacing (filenameContainerView is placed below the spoiler switch in setupFilenameSection)
            filenameContainerView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            imagePreviewView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -70),
            imageButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),

            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        if isNewThread {
            constraints.append(contentsOf: [
                subjectField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 12),
                subjectField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                subjectField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                subjectField.heightAnchor.constraint(equalToConstant: 44)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = insets
        scrollView.scrollIndicatorInsets = insets
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        view.endEditing(true)
        delegate?.composeViewControllerDidCancel(self)
        dismiss(animated: true)
    }

    @objc private func minimizeTapped() {
        view.endEditing(true)
        delegate?.composeViewControllerDidMinimize(self)
        dismiss(animated: true)
    }

    @objc private func postTapped() {
        guard !isPosting else { return }

        // Validate
        let comment = commentTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if comment.isEmpty && selectedImage == nil {
            showAlert(title: "Error", message: "Please enter a comment or attach an image")
            return
        }

        if isNewThread && selectedImage == nil {
            showAlert(title: "Error", message: "An image is required to start a new thread")
            return
        }

        if !PassAuthManager.shared.isAuthenticated {
            showAlert(title: "Not Authenticated", message: "Please configure your 4chan Pass in Settings to post")
            return
        }

        // Submit post
        setLoading(true)

        let postData = PostData(
            board: board,
            resto: threadNumber,
            name: nameField.text?.isEmpty == false ? nameField.text : nil,
            email: emailField.text?.isEmpty == false ? emailField.text : nil,
            subject: isNewThread ? subjectField.text : nil,
            comment: comment,
            imageData: selectedImage?.data,
            imageFilename: selectedImage?.filename,
            imageMimeType: selectedImage?.mimeType,
            spoiler: spoilerSwitch.isOn
        )

        PostingManager.shared.submitPost(postData) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)

                switch result {
                case .success(let postResult):
                    self?.handlePostSuccess(postResult)
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func attachImageTapped() {
        let alert = UIAlertController(title: "Attach Image", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.imagePicker.presentPicker(from: self) { selectedImage in
                self.handleImageSelection(selectedImage)
            }
        })

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.imagePicker.presentCamera(from: self) { selectedImage in
                    self.handleImageSelection(selectedImage)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = imageButton
            popover.sourceRect = imageButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func removeImageTapped() {
        selectedImage = nil
        imagePreviewView.image = nil
        imagePreviewView.isHidden = true
        removeImageButton.isHidden = true
        spoilerLabel.isHidden = true
        spoilerSwitch.isHidden = true
        spoilerSwitch.isOn = false
        filenameContainerView.isHidden = true
        filenameField.text = ""
    }

    @objc private func randomizeFilenameTapped() {
        let randomName = generateRandomFilename()
        filenameField.text = randomName
        updateSelectedImageFilename()
    }

    @objc private func filenameFieldChanged() {
        updateSelectedImageFilename()
    }

    // MARK: - Helpers

    /// Generate a random filename (8 characters alphanumeric)
    private func generateRandomFilename() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }

    /// Update the selectedImage with the current filename from the text field
    private func updateSelectedImageFilename() {
        guard let image = selectedImage else { return }

        let newName = filenameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !newName.isEmpty else { return }

        // Get the original extension
        let originalFilename = image.filename
        let ext = (originalFilename as NSString).pathExtension

        // Create new filename with original extension
        let newFilename = ext.isEmpty ? newName : "\(newName).\(ext)"

        // Create updated SelectedImage with new filename
        selectedImage = SelectedImage(
            data: image.data,
            filename: newFilename,
            mimeType: image.mimeType,
            thumbnail: image.thumbnail
        )
    }

    private func handleImageSelection(_ image: SelectedImage?) {
        selectedImage = image

        if let image = image {
            imagePreviewView.image = image.thumbnail ?? UIImage(data: image.data)
            imagePreviewView.isHidden = false
            removeImageButton.isHidden = false
            spoilerLabel.isHidden = false
            spoilerSwitch.isHidden = false
            filenameContainerView.isHidden = false

            // Set the filename field with the current filename (without extension)
            let filenameWithExt = image.filename
            let nameWithoutExt = (filenameWithExt as NSString).deletingPathExtension
            filenameField.text = nameWithoutExt
        } else {
            imagePreviewView.isHidden = true
            removeImageButton.isHidden = true
            spoilerLabel.isHidden = true
            spoilerSwitch.isHidden = true
            filenameContainerView.isHidden = true
            filenameField.text = ""
        }
    }

    private func handlePostSuccess(_ result: PostResult) {
        let postNumber = result.postNumber ?? result.threadNumber
        delegate?.composeViewControllerDidPost(self, postNumber: postNumber)
        dismiss(animated: true)
    }

    private func setLoading(_ loading: Bool) {
        isPosting = loading
        navigationItem.leftBarButtonItem?.isEnabled = !loading
        navigationItem.rightBarButtonItem?.isEnabled = !loading

        if loading {
            activityIndicator.startAnimating()
            view.isUserInteractionEnabled = false
        } else {
            activityIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
        }
    }

    private func updateCharacterCount() {
        let count = commentTextView.text.count
        characterCountLabel.text = "\(count)/\(maxCommentLength)"

        if count > maxCommentLength {
            characterCountLabel.textColor = .systemRed
        } else {
            characterCountLabel.textColor = ThemeManager.shared.secondaryTextColor
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Public Methods

    /// Insert a quote reference
    func insertQuote(_ postNumber: Int) {
        let quote = ">>\(postNumber)\n"
        if let selectedRange = commentTextView.selectedTextRange {
            commentTextView.replace(selectedRange, withText: quote)
        } else {
            commentTextView.text = (commentTextView.text ?? "") + quote
        }
        updateCharacterCount()
    }
}

// MARK: - UITextFieldDelegate
extension ComposeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameField {
            emailField.becomeFirstResponder()
        } else if textField == emailField {
            if isNewThread {
                subjectField.becomeFirstResponder()
            } else {
                commentTextView.becomeFirstResponder()
            }
        } else if textField == subjectField {
            commentTextView.becomeFirstResponder()
        } else if textField == filenameField {
            // Dismiss keyboard when done is pressed on filename field
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - UITextViewDelegate
extension ComposeViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCount()
    }
}
