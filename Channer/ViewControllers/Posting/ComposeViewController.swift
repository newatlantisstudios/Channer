import UIKit
import WebKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

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
    private let fileInfoLabel = UILabel()
    private let spoilerSwitch = UISwitch()
    private let spoilerLabel = UILabel()

    // Filename UI
    private let filenameContainerView = UIView()
    private let filenameLabel = UILabel()
    private let filenameField = UITextField()
    private let randomizeButton = UIButton(type: .system)

    private let postButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // Quick Reply controls
    private let quickReplyContainerView = UIView()
    private let quickReplyStackView = UIStackView()
    private let personaButton = UIButton(type: .system)
    private let sjisPreviewButton = UIButton(type: .system)
    private let qrSizeControl = UISegmentedControl(items: ["S", "M", "L"])
    private let dumpModeLabel = UILabel()
    private let dumpModeSwitch = UISwitch()
    private let autoPostLabel = UILabel()
    private let autoPostSwitch = UISwitch()
    private let manualCaptchaLabel = UILabel()
    private let manualCaptchaSwitch = UISwitch()

    // Captcha UI
    private let captchaContainerView = UIView()
    private let captchaStatusLabel = UILabel()
    private let manualCaptchaStackView = UIStackView()
    private let captchaChallengeField = UITextField()
    private let captchaResponseField = UITextField()
    private var captchaWebView: WKWebView?
    private var captchaContainerHeightConstraint: NSLayoutConstraint?
    private var commentHeightConstraint: NSLayoutConstraint?

    // State
    private var selectedImage: SelectedImage?
    private let imagePicker = ImagePickerHelper()
    private var isPosting = false
    private var isSJISPreviewEnabled = false
    private var captchaChallenge: String?
    private var captchaResponse: String?
    private var captchaReady = false
    private var pendingCaptchaPost = false

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
        captchaWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "captcha")
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = isNewThread ? "New Thread" : "Reply"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // Navigation buttons
        let cancelButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.accessibilityLabel = "Cancel"
        cancelButton.tintColor = .black
        navigationItem.leftBarButtonItem = cancelButton

        // Right side: minimize and post buttons
        let minimizeButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down.circle"),
            style: .plain,
            target: self,
            action: #selector(minimizeTapped)
        )
        minimizeButton.accessibilityLabel = "Minimize"
        minimizeButton.tintColor = .black

        let postButton = UIBarButtonItem(
            image: UIImage(systemName: "paperplane.fill"),
            style: .done,
            target: self,
            action: #selector(postTapped)
        )
        postButton.accessibilityLabel = "Post"
        postButton.tintColor = .black
        navigationItem.rightBarButtonItems = [postButton, minimizeButton]

        setupScrollView()
        setupNameField()
        setupEmailField()

        if isNewThread {
            setupSubjectField()
        }

        setupCommentTextView()
        setupQuickReplyControls()
        setupCaptchaSection()
        setupImageSection()
        setupConstraints()
        configureCaptchaVisibility()
        applySavedPersona()
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
#if targetEnvironment(macCatalyst)
        setupDropInteractionForCommentTextView()
#endif

        characterCountLabel.font = UIFont.systemFont(ofSize: 12)
        characterCountLabel.textColor = ThemeManager.shared.secondaryTextColor
        characterCountLabel.textAlignment = .right
        characterCountLabel.text = "0/\(maxCommentLength)"
        characterCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(characterCountLabel)
    }

    private func setupQuickReplyControls() {
        quickReplyContainerView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        quickReplyContainerView.layer.cornerRadius = 8
        quickReplyContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quickReplyContainerView)

        quickReplyStackView.axis = .vertical
        quickReplyStackView.spacing = 8
        quickReplyStackView.translatesAutoresizingMaskIntoConstraints = false
        quickReplyContainerView.addSubview(quickReplyStackView)

        personaButton.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
        personaButton.setTitle(" Persona", for: .normal)
        personaButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        personaButton.showsMenuAsPrimaryAction = true
        updatePersonaMenu()

        sjisPreviewButton.setImage(UIImage(systemName: "textformat"), for: .normal)
        sjisPreviewButton.setTitle(" SJIS", for: .normal)
        sjisPreviewButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        sjisPreviewButton.addTarget(self, action: #selector(toggleSJISPreview), for: .touchUpInside)

        qrSizeControl.selectedSegmentIndex = QuickReplyPreferences.shared.sizeIndex
        qrSizeControl.addTarget(self, action: #selector(qrSizeChanged), for: .valueChanged)

        dumpModeLabel.text = "Dump"
        dumpModeLabel.font = UIFont.systemFont(ofSize: 13)
        dumpModeLabel.textColor = ThemeManager.shared.secondaryTextColor
        dumpModeSwitch.isOn = QuickReplyPreferences.shared.dumpModeEnabled
        dumpModeSwitch.addTarget(self, action: #selector(dumpModeChanged), for: .valueChanged)

        autoPostLabel.text = "Auto-post captcha"
        autoPostLabel.font = UIFont.systemFont(ofSize: 13)
        autoPostLabel.textColor = ThemeManager.shared.secondaryTextColor
        autoPostSwitch.isOn = QuickReplyPreferences.shared.postOnCaptchaCompletion
        autoPostSwitch.addTarget(self, action: #selector(autoPostChanged), for: .valueChanged)

        manualCaptchaLabel.text = "Manual captcha"
        manualCaptchaLabel.font = UIFont.systemFont(ofSize: 13)
        manualCaptchaLabel.textColor = ThemeManager.shared.secondaryTextColor
        manualCaptchaSwitch.isOn = QuickReplyPreferences.shared.manualCaptchaMode
        manualCaptchaSwitch.addTarget(self, action: #selector(manualCaptchaModeChanged), for: .valueChanged)

        let firstRow = UIStackView(arrangedSubviews: [personaButton, sjisPreviewButton, qrSizeControl])
        firstRow.axis = .horizontal
        firstRow.spacing = 8
        firstRow.distribution = .fillEqually

        let dumpStack = makeSwitchStack(label: dumpModeLabel, toggle: dumpModeSwitch)
        let autoPostStack = makeSwitchStack(label: autoPostLabel, toggle: autoPostSwitch)
        let manualStack = makeSwitchStack(label: manualCaptchaLabel, toggle: manualCaptchaSwitch)
        let secondRow = UIStackView(arrangedSubviews: [dumpStack, autoPostStack, manualStack])
        secondRow.axis = .horizontal
        secondRow.spacing = 8
        secondRow.distribution = .fillEqually

        quickReplyStackView.addArrangedSubview(firstRow)
        quickReplyStackView.addArrangedSubview(secondRow)

        NSLayoutConstraint.activate([
            quickReplyStackView.topAnchor.constraint(equalTo: quickReplyContainerView.topAnchor, constant: 10),
            quickReplyStackView.leadingAnchor.constraint(equalTo: quickReplyContainerView.leadingAnchor, constant: 10),
            quickReplyStackView.trailingAnchor.constraint(equalTo: quickReplyContainerView.trailingAnchor, constant: -10),
            quickReplyStackView.bottomAnchor.constraint(equalTo: quickReplyContainerView.bottomAnchor, constant: -10)
        ])
    }

    private func makeSwitchStack(label: UILabel, toggle: UISwitch) -> UIStackView {
        toggle.transform = CGAffineTransform(scaleX: 0.78, y: 0.78)
        let stack = UIStackView(arrangedSubviews: [label, toggle])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }

    private func setupCaptchaSection() {
        captchaContainerView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        captchaContainerView.layer.cornerRadius = 8
        captchaContainerView.clipsToBounds = true
        captchaContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(captchaContainerView)

        captchaStatusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        captchaStatusLabel.textColor = ThemeManager.shared.secondaryTextColor
        captchaStatusLabel.numberOfLines = 2
        captchaStatusLabel.text = "Captcha loading..."
        captchaStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        captchaContainerView.addSubview(captchaStatusLabel)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "captcha")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        captchaContainerView.addSubview(webView)
        captchaWebView = webView

        captchaChallengeField.placeholder = "t-challenge"
        captchaChallengeField.font = UIFont.systemFont(ofSize: 14)
        captchaChallengeField.textColor = ThemeManager.shared.primaryTextColor
        captchaChallengeField.backgroundColor = ThemeManager.shared.backgroundColor
        captchaChallengeField.layer.cornerRadius = 6
        captchaChallengeField.autocapitalizationType = .none
        captchaChallengeField.autocorrectionType = .no
        captchaChallengeField.delegate = self
        captchaChallengeField.addTarget(self, action: #selector(manualCaptchaChanged), for: .editingChanged)

        captchaResponseField.placeholder = "t-response"
        captchaResponseField.font = UIFont.systemFont(ofSize: 14)
        captchaResponseField.textColor = ThemeManager.shared.primaryTextColor
        captchaResponseField.backgroundColor = ThemeManager.shared.backgroundColor
        captchaResponseField.layer.cornerRadius = 6
        captchaResponseField.autocapitalizationType = .none
        captchaResponseField.autocorrectionType = .no
        captchaResponseField.delegate = self
        captchaResponseField.addTarget(self, action: #selector(manualCaptchaChanged), for: .editingChanged)

        manualCaptchaStackView.axis = .vertical
        manualCaptchaStackView.spacing = 8
        manualCaptchaStackView.isHidden = true
        manualCaptchaStackView.translatesAutoresizingMaskIntoConstraints = false
        manualCaptchaStackView.addArrangedSubview(captchaChallengeField)
        manualCaptchaStackView.addArrangedSubview(captchaResponseField)
        captchaContainerView.addSubview(manualCaptchaStackView)

        NSLayoutConstraint.activate([
            captchaStatusLabel.topAnchor.constraint(equalTo: captchaContainerView.topAnchor, constant: 8),
            captchaStatusLabel.leadingAnchor.constraint(equalTo: captchaContainerView.leadingAnchor, constant: 12),
            captchaStatusLabel.trailingAnchor.constraint(equalTo: captchaContainerView.trailingAnchor, constant: -12),

            webView.topAnchor.constraint(equalTo: captchaStatusLabel.bottomAnchor, constant: 8),
            webView.centerXAnchor.constraint(equalTo: captchaContainerView.centerXAnchor),
            webView.widthAnchor.constraint(equalToConstant: 312),
            webView.heightAnchor.constraint(equalToConstant: 154),

            manualCaptchaStackView.topAnchor.constraint(equalTo: captchaStatusLabel.bottomAnchor, constant: 10),
            manualCaptchaStackView.leadingAnchor.constraint(equalTo: captchaContainerView.leadingAnchor, constant: 12),
            manualCaptchaStackView.trailingAnchor.constraint(equalTo: captchaContainerView.trailingAnchor, constant: -12),
            captchaChallengeField.heightAnchor.constraint(equalToConstant: 36),
            captchaResponseField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

#if targetEnvironment(macCatalyst)
    private func setupDropInteractionForCommentTextView() {
        commentTextView.addInteraction(UIDropInteraction(delegate: self))
    }
#endif

    private func setupImageSection() {
        // Image button
        imageButton.setTitle("  Attach File", for: .normal)
        imageButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
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

        // File info label (shows filename and size for attached files)
        fileInfoLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        fileInfoLabel.textColor = ThemeManager.shared.secondaryTextColor
        fileInfoLabel.numberOfLines = 1
        fileInfoLabel.lineBreakMode = .byTruncatingMiddle
        fileInfoLabel.isHidden = true
        fileInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileInfoLabel)

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
        randomizeButton.setTitle("  Random  ", for: .normal)
        randomizeButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        randomizeButton.titleLabel?.adjustsFontSizeToFitWidth = false
        randomizeButton.titleLabel?.lineBreakMode = .byClipping
        randomizeButton.backgroundColor = ThemeManager.shared.cellBackgroundColor
        randomizeButton.layer.cornerRadius = 6
        randomizeButton.addTarget(self, action: #selector(randomizeFilenameTapped), for: .touchUpInside)
        randomizeButton.translatesAutoresizingMaskIntoConstraints = false
        randomizeButton.setContentHuggingPriority(.required, for: .horizontal)
        randomizeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        filenameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        filenameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
            randomizeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupConstraints() {
        let topAnchor = isNewThread ? subjectField.bottomAnchor : emailField.bottomAnchor
        commentHeightConstraint = commentTextView.heightAnchor.constraint(equalToConstant: QuickReplyPreferences.shared.commentHeight)
        captchaContainerHeightConstraint = captchaContainerView.heightAnchor.constraint(equalToConstant: PassAuthManager.shared.isAuthenticated ? 0 : captchaHeight)

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
            commentHeightConstraint!,

            // Character count
            characterCountLabel.topAnchor.constraint(equalTo: commentTextView.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Quick reply controls
            quickReplyContainerView.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: 12),
            quickReplyContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickReplyContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quickReplyContainerView.heightAnchor.constraint(equalToConstant: 92),

            // Captcha
            captchaContainerView.topAnchor.constraint(equalTo: quickReplyContainerView.bottomAnchor, constant: 12),
            captchaContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            captchaContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            captchaContainerHeightConstraint!,

            // Image button
            imageButton.topAnchor.constraint(equalTo: captchaContainerView.bottomAnchor, constant: 16),
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

            // File info label (shown next to preview, above spoiler controls)
            fileInfoLabel.topAnchor.constraint(equalTo: imagePreviewView.topAnchor, constant: 4),
            fileInfoLabel.leadingAnchor.constraint(equalTo: imagePreviewView.trailingAnchor, constant: 12),
            fileInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Spoiler label
            spoilerLabel.topAnchor.constraint(equalTo: fileInfoLabel.bottomAnchor, constant: 8),
            spoilerLabel.leadingAnchor.constraint(equalTo: imagePreviewView.trailingAnchor, constant: 12),

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

    /// Returns a view controller that is properly in the view hierarchy for presenting pickers.
    /// On Mac Catalyst, the compose sheet lives in a _UIBridgedPresentationWindow where both
    /// the ComposeViewController and its navigation controller are "detached." Present from the
    /// VC that originally presented this compose sheet — it lives in the main app window.
    private var presenterInHierarchy: UIViewController {
        if let presenter = navigationController?.presentingViewController {
            return presenter
        }
        if let presenter = presentingViewController {
            return presenter
        }
        if let nav = navigationController {
            return nav
        }
        return self
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

        guard BoardsService.shared.selectedSite.supportsPosting else {
            showAlert(title: "Read Only", message: "Posting is only supported on 4chan. Other imageboard sites are read-only.")
            return
        }

        submitCurrentPost()
    }

    @objc private func toggleSJISPreview() {
        isSJISPreviewEnabled.toggle()
        commentTextView.font = isSJISPreviewEnabled
            ? UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            : UIFont.systemFont(ofSize: 16)
        sjisPreviewButton.tintColor = isSJISPreviewEnabled ? .systemBlue : nil
    }

    @objc private func qrSizeChanged() {
        QuickReplyPreferences.shared.sizeIndex = qrSizeControl.selectedSegmentIndex
        commentHeightConstraint?.constant = QuickReplyPreferences.shared.commentHeight
        view.layoutIfNeeded()
    }

    @objc private func dumpModeChanged() {
        QuickReplyPreferences.shared.dumpModeEnabled = dumpModeSwitch.isOn
    }

    @objc private func autoPostChanged() {
        QuickReplyPreferences.shared.postOnCaptchaCompletion = autoPostSwitch.isOn
    }

    @objc private func manualCaptchaModeChanged() {
        QuickReplyPreferences.shared.manualCaptchaMode = manualCaptchaSwitch.isOn
        captchaChallenge = nil
        captchaResponse = nil
        captchaReady = false
        configureCaptchaVisibility()
    }

    @objc private func manualCaptchaChanged() {
        captchaChallenge = captchaChallengeField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        captchaResponse = captchaResponseField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        captchaReady = captchaChallenge?.isEmpty == false
        captchaStatusLabel.text = captchaReady ? "Manual captcha ready" : "Paste t-challenge and t-response"
    }

    @objc private func attachImageTapped() {
        let alert = UIAlertController(title: "Attach File", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPickerAfterDismissal {
                guard let self = self else { return }
                let presenter = self.presenterInHierarchy
                self.imagePicker.presentPicker(from: presenter) { [weak self] selectedImage in
                    self?.handleImageSelection(selectedImage)
                }
            }
        })

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentPickerAfterDismissal {
                    guard let self = self else { return }
                    let presenter = self.presenterInHierarchy
                    self.imagePicker.presentCamera(from: presenter) { [weak self] selectedImage in
                        self?.handleImageSelection(selectedImage)
                    }
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Choose Image", style: .default) { [weak self] _ in
            self?.presentPickerAfterDismissal {
                guard let self = self else { return }
                let presenter = self.presenterInHierarchy
                self.imagePicker.presentImageFilePicker(from: presenter) { [weak self] selectedImage in
                    self?.handleImageSelection(selectedImage)
                }
            }
        })

        alert.addAction(UIAlertAction(title: "Choose File (WebM/MP4)", style: .default) { [weak self] _ in
            self?.presentPickerAfterDismissal {
                guard let self = self else { return }
                let presenter = self.presenterInHierarchy
                self.imagePicker.presentDocumentPicker(from: presenter) { [weak self] selectedFile in
                    guard let self = self else { return }
                    if let file = selectedFile, file.data.count > 4 * 1024 * 1024 {
                        self.showAlert(title: "File Too Large", message: "The maximum file size is 4MB")
                        return
                    }
                    self.handleImageSelection(selectedFile)
                }
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = imageButton
            popover.sourceRect = imageButton.bounds
        }

        present(alert, animated: true)
    }

    /// Presents a picker after ensuring the action sheet has fully dismissed.
    /// The action sheet's action handler fires while the sheet is still being dismissed,
    /// which prevents presenting another view controller from the same presenter.
    private func presentPickerAfterDismissal(_ block: @escaping () -> Void) {
        if presentedViewController != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.presentPickerAfterDismissal(block)
            }
        } else {
            block()
        }
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
        fileInfoLabel.isHidden = true
        fileInfoLabel.text = nil
        imageButton.setTitle("  Attach File", for: .normal)
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

    private var captchaHeight: CGFloat {
        QuickReplyPreferences.shared.manualCaptchaMode ? 132 : 210
    }

    private func submitCurrentPost() {
        guard !isPosting else { return }

        let comment = commentTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if comment.isEmpty && selectedImage == nil {
            showAlert(title: "Error", message: "Please enter a comment or attach a file")
            return
        }

        if isNewThread && selectedImage == nil {
            showAlert(title: "Error", message: "An image is required to start a new thread")
            return
        }

        if !PassAuthManager.shared.isAuthenticated && !captchaReady {
            pendingCaptchaPost = autoPostSwitch.isOn
            captchaStatusLabel.text = pendingCaptchaPost
                ? "Complete the captcha to post automatically"
                : "Complete the captcha, then tap Post again"
            loadCaptchaIfNeeded(forceReload: false)
            if !pendingCaptchaPost {
                showAlert(title: "Captcha Required", message: "Complete the captcha before posting without 4chan Pass.")
            }
            return
        }

        pendingCaptchaPost = false
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
            spoiler: spoilerSwitch.isOn,
            captchaChallenge: PassAuthManager.shared.isAuthenticated ? nil : captchaChallenge,
            captchaResponse: PassAuthManager.shared.isAuthenticated ? nil : captchaResponse
        )

        PostingManager.shared.submitPost(postData) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)

                switch result {
                case .success(let postResult):
                    self?.handlePostSuccess(postResult)
                case .failure(let error):
                    self?.captchaReady = false
                    self?.captchaChallenge = nil
                    self?.captchaResponse = nil
                    self?.captchaStatusLabel.text = error.localizedDescription
                    self?.loadCaptchaIfNeeded(forceReload: true)
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func configureCaptchaVisibility() {
        let usesCaptcha = !PassAuthManager.shared.isAuthenticated
        captchaContainerView.isHidden = !usesCaptcha
        captchaContainerHeightConstraint?.constant = usesCaptcha ? captchaHeight : 0
        manualCaptchaStackView.isHidden = !QuickReplyPreferences.shared.manualCaptchaMode
        captchaWebView?.isHidden = QuickReplyPreferences.shared.manualCaptchaMode

        if usesCaptcha {
            captchaStatusLabel.text = QuickReplyPreferences.shared.manualCaptchaMode
                ? "Paste t-challenge and t-response"
                : "Captcha loading..."
            if QuickReplyPreferences.shared.manualCaptchaMode {
                manualCaptchaChanged()
            } else {
                loadCaptchaIfNeeded(forceReload: false)
            }
        }
    }

    private func loadCaptchaIfNeeded(forceReload: Bool) {
        guard !PassAuthManager.shared.isAuthenticated,
              !QuickReplyPreferences.shared.manualCaptchaMode else { return }
        guard forceReload || !captchaReady else { return }
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let autoLoadScript = QuickReplyPreferences.shared.autoLoadCaptcha
            ? "setTimeout(function() { TCaptcha.onReloadClick(); }, 350);"
            : ""
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
            #t-root { margin: 4px auto 0 auto; }
          </style>
          <script src="https://s.4cdn.org/js/tcaptcha.min.7.js"></script>
        </head>
        <body>
          <div id="t-root"></div>
          <script>
            function notifyCaptcha() {
              var challenge = document.querySelector('input[name="t-challenge"]');
              var response = document.querySelector('input[name="t-response"]');
              var task = document.getElementById('t-task');
              var payload = {
                challenge: challenge ? challenge.value : '',
                response: response ? response.value : '',
                done: window.TCaptcha && TCaptcha.isDone ? TCaptcha.isDone() : false,
                status: task ? task.innerText : ''
              };
              window.webkit.messageHandlers.captcha.postMessage(payload);
            }
            function wrapCaptcha() {
              if (!window.TCaptcha) { setTimeout(wrapCaptcha, 100); return; }
              var oldNext = TCaptcha.onNextClick;
              TCaptcha.onNextClick = function() {
                var result = oldNext.apply(TCaptcha, arguments);
                setTimeout(notifyCaptcha, 120);
                return result;
              };
              var oldBuild = TCaptcha.buildFromJson;
              TCaptcha.buildFromJson = function(data) {
                var result = oldBuild.apply(TCaptcha, arguments);
                setTimeout(notifyCaptcha, 120);
                return result;
              };
              TCaptcha.init(document.getElementById('t-root'), '\(board)', \(threadNumber), 1, \(darkMode ? "true" : "false"));
              TCaptcha.setErrorCb(function(error) {
                window.webkit.messageHandlers.captcha.postMessage({ error: error || '' });
              });
              setInterval(notifyCaptcha, 800);
              \(autoLoadScript)
            }
            wrapCaptcha();
          </script>
        </body>
        </html>
        """
        captchaWebView?.loadHTMLString(html, baseURL: URL(string: "https://boards.4chan.org/\(board)/"))
    }

    private func updateCaptcha(challenge: String?, response: String?, done: Bool, status: String?) {
        captchaChallenge = challenge?.trimmingCharacters(in: .whitespacesAndNewlines)
        captchaResponse = response?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChallenge = captchaChallenge?.isEmpty == false
        captchaReady = done && hasChallenge

        if captchaReady {
            captchaStatusLabel.text = "Captcha complete"
            if pendingCaptchaPost {
                submitCurrentPost()
            }
        } else if let status = status, !status.isEmpty {
            captchaStatusLabel.text = status
        }
    }

    private func applySavedPersona() {
        if let persona = QuickReplyPreferences.shared.selectedPersona {
            nameField.text = persona.name
            emailField.text = persona.email
            subjectField.text = persona.subject
        }
    }

    private func updatePersonaMenu() {
        var actions = QuickReplyPreferences.shared.personas.map { persona in
            UIAction(title: persona.title, image: UIImage(systemName: "person")) { [weak self] _ in
                self?.apply(persona: persona)
            }
        }

        if !actions.isEmpty {
            actions.append(UIAction(title: "Clear Persona", image: UIImage(systemName: "xmark.circle")) { [weak self] _ in
                QuickReplyPreferences.shared.selectedPersonaID = nil
                self?.nameField.text = nil
                self?.emailField.text = nil
                self?.subjectField.text = nil
                self?.updatePersonaMenu()
            })
        }

        actions.append(UIAction(title: "Save Current", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
            self?.saveCurrentPersona()
        })

        personaButton.menu = UIMenu(title: "Personas", children: actions)
    }

    private func apply(persona: QuickReplyPersona) {
        QuickReplyPreferences.shared.selectedPersonaID = persona.id
        nameField.text = persona.name
        emailField.text = persona.email
        subjectField.text = persona.subject
        updatePersonaMenu()
    }

    private func saveCurrentPersona() {
        let persona = QuickReplyPersona(
            title: nameField.text?.isEmpty == false ? nameField.text! : "Anonymous",
            name: nameField.text,
            email: emailField.text,
            subject: subjectField.text
        )
        QuickReplyPreferences.shared.save(persona: persona)
        QuickReplyPreferences.shared.selectedPersonaID = persona.id
        updatePersonaMenu()
    }

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
            fileInfoLabel.isHidden = false

            // Auto-randomize the filename if the user has enabled the setting
            let autoRandomize = UserDefaults.standard.bool(forKey: "channer_auto_randomize_filename_enabled")
            if autoRandomize {
                let randomName = generateRandomFilename()
                filenameField.text = randomName
                updateSelectedImageFilename()
            } else {
                // Set the filename field with the current filename (without extension)
                let nameWithoutExt = (image.filename as NSString).deletingPathExtension
                filenameField.text = nameWithoutExt
            }

            // Show file info (name + size) using the (possibly updated) selectedImage
            let displayImage = selectedImage ?? image
            let sizeString = ByteCountFormatter.string(fromByteCount: Int64(displayImage.data.count), countStyle: .file)
            let isVideo = displayImage.mimeType.hasPrefix("video/")
            let typeIcon = isVideo ? "Video" : "Image"
            fileInfoLabel.text = "\(typeIcon): \(displayImage.filename) (\(sizeString))"

            // Update attach button to indicate file is attached
            imageButton.setTitle("  Change File", for: .normal)
        } else {
            imagePreviewView.isHidden = true
            removeImageButton.isHidden = true
            spoilerLabel.isHidden = true
            spoilerSwitch.isHidden = true
            filenameContainerView.isHidden = true
            filenameField.text = ""
            fileInfoLabel.isHidden = true
            fileInfoLabel.text = nil
            imageButton.setTitle("  Attach File", for: .normal)
        }
    }

#if targetEnvironment(macCatalyst)
    private var supportedDropTypeIdentifiers: [String] {
        var identifiers = [
            UTType.image.identifier,
            UTType.movie.identifier,
            UTType.mpeg4Movie.identifier,
            UTType.fileURL.identifier
        ]

        if let webm = UTType(filenameExtension: "webm") {
            identifiers.append(webm.identifier)
        }

        return identifiers
    }

    private var mediaDropTypeIdentifiers: [String] {
        supportedDropTypeIdentifiers.filter { $0 != UTType.fileURL.identifier }
    }

    private func handleDroppedImage(_ image: UIImage, filename: String?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let selectedImage = self.imagePicker.createSelectedImage(from: image, originalFilename: filename)
            DispatchQueue.main.async {
                self.handleImageSelection(selectedImage)
            }
        }
    }

    private func handleDroppedFileURL(_ url: URL, preferredFilename: String? = nil, removeWhenDone: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer { if removeWhenDone { try? FileManager.default.removeItem(at: url) } }

            let selectedImage = self.imagePicker.createSelectedMedia(fromFileURL: url, preferredFilename: preferredFilename)
            DispatchQueue.main.async {
                if let selectedImage = selectedImage {
                    self.handleImageSelection(selectedImage)
                } else {
                    let message = self.imagePicker.lastVideoError ?? "The dropped file could not be read as a supported image or video."
                    self.showAlert(title: "Unable to Load File", message: message)
                }
            }
        }
    }

    private func handleDroppedTemporaryFileURL(_ url: URL, preferredFilename: String?) {
        let trimmedFilename = preferredFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = trimmedFilename?.isEmpty == false ? trimmedFilename : nil
        let copiedURL = copyDroppedTemporaryFile(at: url, preferredFilename: filename)
        handleDroppedFileURL(copiedURL ?? url, preferredFilename: filename, removeWhenDone: copiedURL != nil)
    }

    private func copyDroppedTemporaryFile(at url: URL, preferredFilename: String?) -> URL? {
        let filename = preferredFilename ?? url.lastPathComponent
        let ext = (filename as NSString).pathExtension.isEmpty ? url.pathExtension : (filename as NSString).pathExtension
        var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        if !ext.isEmpty {
            tempURL.appendPathExtension(ext)
        }

        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func preferredDropFilename(from provider: NSItemProvider, typeIdentifier: String) -> String? {
        let suggestedName = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let suggestedName = suggestedName, !suggestedName.isEmpty {
            return suggestedName
        }

        if let webm = UTType(filenameExtension: "webm"),
           typeIdentifier == webm.identifier {
            return "dropped.webm"
        }

        if typeIdentifier == UTType.movie.identifier || typeIdentifier == UTType.mpeg4Movie.identifier {
            return "dropped.mp4"
        }

        if typeIdentifier == UTType.image.identifier {
            return "dropped.jpg"
        }

        return nil
    }

    private func setDropHighlight(_ isActive: Bool) {
        if isActive {
            commentTextView.layer.borderWidth = 2
            commentTextView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            commentTextView.layer.borderWidth = 0
            commentTextView.layer.borderColor = nil
        }
    }

    private func loadDroppedMedia(from provider: NSItemProvider) {
        if let typeIdentifier = mediaDropTypeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, _ in
                guard let self = self else { return }
                let filename = self.preferredDropFilename(from: provider, typeIdentifier: typeIdentifier)
                if let url = url {
                    self.handleDroppedTemporaryFileURL(url, preferredFilename: filename)
                } else if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                        guard let self = self, let image = object as? UIImage else { return }
                        let filename = filename ?? "image.jpg"
                        self.handleDroppedImage(image, filename: filename)
                    }
                }
            }
            return
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self, let image = object as? UIImage else { return }
                let filename = provider.suggestedName ?? "image.jpg"
                self.handleDroppedImage(image, filename: filename)
            }
        }
    }
#endif

    private func handlePostSuccess(_ result: PostResult) {
        let postNumber = result.postNumber ?? result.threadNumber
        print("[ComposeViewController] Post success result postNumber=\(String(describing: result.postNumber)) threadNumber=\(String(describing: result.threadNumber)) resolved=\(String(describing: postNumber)) dumpMode=\(dumpModeSwitch.isOn)")

        if dumpModeSwitch.isOn {
            delegate?.composeViewControllerDidPost(self, postNumber: postNumber)
            commentTextView.text = ""
            updateCharacterCount()
            removeImageTapped()
            captchaChallenge = nil
            captchaResponse = nil
            captchaReady = false
            captchaStatusLabel.text = "Posted. Captcha reloading for next dump."
            loadCaptchaIfNeeded(forceReload: true)
            return
        }

        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            print("[ComposeViewController] Dismiss completed; notifying delegate for postNumber=\(String(describing: postNumber))")
            self.delegate?.composeViewControllerDidPost(self, postNumber: postNumber)
        }
    }

    private func setLoading(_ loading: Bool) {
        isPosting = loading
        navigationItem.leftBarButtonItem?.isEnabled = !loading
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = !loading }

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
        } else if textField == captchaChallengeField {
            captchaResponseField.becomeFirstResponder()
        } else if textField == captchaResponseField {
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

// MARK: - WKScriptMessageHandler
extension ComposeViewController: WKScriptMessageHandler, WKNavigationDelegate {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "captcha" else { return }

        if let body = message.body as? [String: Any] {
            if let error = body["error"] as? String, !error.isEmpty {
                captchaStatusLabel.text = error
                return
            }

            let challenge = body["challenge"] as? String
            let response = body["response"] as? String
            let done = body["done"] as? Bool ?? false
            let status = body["status"] as? String
            updateCaptcha(challenge: challenge, response: response, done: done, status: status)
        }
    }
}

// MARK: - Quick Reply Preferences
struct QuickReplyPersona: Codable, Equatable {
    let id: String
    let title: String
    let name: String?
    let email: String?
    let subject: String?

    init(id: String = UUID().uuidString, title: String, name: String?, email: String?, subject: String?) {
        self.id = id
        self.title = title
        self.name = name?.isEmpty == false ? name : nil
        self.email = email?.isEmpty == false ? email : nil
        self.subject = subject?.isEmpty == false ? subject : nil
    }
}

final class QuickReplyPreferences {
    static let shared = QuickReplyPreferences()

    private let autoLoadCaptchaKey = "channer_qr_auto_load_captcha"
    private let postOnCaptchaCompletionKey = "channer_qr_post_on_captcha_completion"
    private let dumpModeEnabledKey = "channer_qr_dump_mode_enabled"
    private let manualCaptchaModeKey = "channer_qr_manual_captcha_mode"
    private let sizeIndexKey = "channer_qr_size_index"
    private let personasKey = "channer_qr_personas"
    private let selectedPersonaIDKey = "channer_qr_selected_persona_id"
    private let defaults = UserDefaults.standard

    var autoLoadCaptcha: Bool {
        if defaults.object(forKey: autoLoadCaptchaKey) == nil { return true }
        return defaults.bool(forKey: autoLoadCaptchaKey)
    }

    var postOnCaptchaCompletion: Bool {
        get { defaults.bool(forKey: postOnCaptchaCompletionKey) }
        set { defaults.set(newValue, forKey: postOnCaptchaCompletionKey) }
    }

    var dumpModeEnabled: Bool {
        get { defaults.bool(forKey: dumpModeEnabledKey) }
        set { defaults.set(newValue, forKey: dumpModeEnabledKey) }
    }

    var manualCaptchaMode: Bool {
        get { defaults.bool(forKey: manualCaptchaModeKey) }
        set { defaults.set(newValue, forKey: manualCaptchaModeKey) }
    }

    var sizeIndex: Int {
        get {
            let stored = defaults.integer(forKey: sizeIndexKey)
            return min(max(stored, 0), 2)
        }
        set { defaults.set(min(max(newValue, 0), 2), forKey: sizeIndexKey) }
    }

    var commentHeight: CGFloat {
        switch sizeIndex {
        case 0: return 110
        case 2: return 230
        default: return 160
        }
    }

    var personas: [QuickReplyPersona] {
        guard let data = defaults.data(forKey: personasKey),
              let decoded = try? JSONDecoder().decode([QuickReplyPersona].self, from: data) else {
            return []
        }
        return decoded
    }

    var selectedPersonaID: String? {
        get { defaults.string(forKey: selectedPersonaIDKey) }
        set {
            if let newValue = newValue {
                defaults.set(newValue, forKey: selectedPersonaIDKey)
            } else {
                defaults.removeObject(forKey: selectedPersonaIDKey)
            }
        }
    }

    var selectedPersona: QuickReplyPersona? {
        guard let id = selectedPersonaID else { return nil }
        return personas.first { $0.id == id }
    }

    func save(persona: QuickReplyPersona) {
        var updated = personas.filter { $0.id != persona.id }
        updated.append(persona)
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: personasKey)
        }
    }
}

#if targetEnvironment(macCatalyst)
// MARK: - UIDropInteractionDelegate (macOS)
extension ComposeViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: supportedDropTypeIdentifiers)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        setDropHighlight(true)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        setDropHighlight(false)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        setDropHighlight(false)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        setDropHighlight(false)
        guard let provider = session.items.first?.itemProvider else { return }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let self = self else { return }
                if let url = item as? URL {
                    self.handleDroppedFileURL(url)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    self.handleDroppedFileURL(url)
                } else {
                    self.loadDroppedMedia(from: provider)
                }
            }
            return
        }

        loadDroppedMedia(from: provider)
    }
}
#endif
