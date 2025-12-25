import UIKit

class PassSettingsViewController: UIViewController {

    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let headerLabel = UILabel()
    private let descriptionLabel = UILabel()

    private let tokenTextField = UITextField()
    private let pinTextField = UITextField()

    private let loginButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)

    private let statusView = UIView()
    private let statusLabel = UILabel()
    private let statusIndicator = UIView()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Initialization
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateAuthState()
        loadStoredCredentials()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAuthState()
    }

    // MARK: - UI Setup
    private func setupUI() {
        title = "4chan Pass"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        setupScrollView()
        setupHeader()
        setupStatusSection()
        setupCredentialsSection()
        setupButtons()
        setupActivityIndicator()

        // Dismiss keyboard on tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeader() {
        headerLabel.text = "4chan Pass Authentication"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        headerLabel.textColor = ThemeManager.shared.primaryTextColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        descriptionLabel.text = "Enter your 4chan Pass credentials to enable posting. Your credentials are stored securely in the iOS Keychain."
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = ThemeManager.shared.secondaryTextColor
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupStatusSection() {
        statusView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        statusView.layer.cornerRadius = 10
        statusView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusView)

        statusIndicator.layer.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusView.addSubview(statusIndicator)

        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textColor = ThemeManager.shared.primaryTextColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            statusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusView.heightAnchor.constraint(equalToConstant: 50),

            statusIndicator.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 16),
            statusIndicator.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -16)
        ])
    }

    private func setupCredentialsSection() {
        let tokenContainer = createTextFieldContainer()
        contentView.addSubview(tokenContainer)

        tokenTextField.placeholder = "Pass Token (10 characters)"
        tokenTextField.font = UIFont.systemFont(ofSize: 16)
        tokenTextField.textColor = ThemeManager.shared.primaryTextColor
        tokenTextField.autocapitalizationType = .allCharacters
        tokenTextField.autocorrectionType = .no
        tokenTextField.returnKeyType = .next
        tokenTextField.delegate = self
        tokenTextField.translatesAutoresizingMaskIntoConstraints = false
        tokenContainer.addSubview(tokenTextField)

        let pinContainer = createTextFieldContainer()
        contentView.addSubview(pinContainer)

        pinTextField.placeholder = "PIN"
        pinTextField.font = UIFont.systemFont(ofSize: 16)
        pinTextField.textColor = ThemeManager.shared.primaryTextColor
        pinTextField.isSecureTextEntry = true
        pinTextField.autocapitalizationType = .none
        pinTextField.autocorrectionType = .no
        pinTextField.returnKeyType = .done
        pinTextField.delegate = self
        pinTextField.translatesAutoresizingMaskIntoConstraints = false
        pinContainer.addSubview(pinTextField)

        NSLayoutConstraint.activate([
            tokenContainer.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 20),
            tokenContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tokenContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tokenContainer.heightAnchor.constraint(equalToConstant: 50),

            tokenTextField.leadingAnchor.constraint(equalTo: tokenContainer.leadingAnchor, constant: 16),
            tokenTextField.trailingAnchor.constraint(equalTo: tokenContainer.trailingAnchor, constant: -16),
            tokenTextField.centerYAnchor.constraint(equalTo: tokenContainer.centerYAnchor),

            pinContainer.topAnchor.constraint(equalTo: tokenContainer.bottomAnchor, constant: 12),
            pinContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pinContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            pinContainer.heightAnchor.constraint(equalToConstant: 50),

            pinTextField.leadingAnchor.constraint(equalTo: pinContainer.leadingAnchor, constant: 16),
            pinTextField.trailingAnchor.constraint(equalTo: pinContainer.trailingAnchor, constant: -16),
            pinTextField.centerYAnchor.constraint(equalTo: pinContainer.centerYAnchor)
        ])
    }

    private func createTextFieldContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = ThemeManager.shared.cellBackgroundColor
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    private func setupButtons() {
        loginButton.setTitle("Login", for: .normal)
        loginButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        loginButton.backgroundColor = .systemGreen
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 10
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loginButton)

        logoutButton.setTitle("Logout", for: .normal)
        logoutButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        logoutButton.backgroundColor = .systemRed
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.layer.cornerRadius = 10
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoutButton)

        // Get reference to pinContainer
        let pinContainer = pinTextField.superview!

        NSLayoutConstraint.activate([
            loginButton.topAnchor.constraint(equalTo: pinContainer.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            loginButton.heightAnchor.constraint(equalToConstant: 50),

            logoutButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
            logoutButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            logoutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            logoutButton.heightAnchor.constraint(equalToConstant: 50),
            logoutButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - State Management
    private func updateAuthState() {
        let isAuthenticated = PassAuthManager.shared.isAuthenticated

        if isAuthenticated {
            statusLabel.text = "Authenticated"
            statusIndicator.backgroundColor = .systemGreen
            loginButton.isHidden = true
            logoutButton.isHidden = false
            tokenTextField.isEnabled = false
            pinTextField.isEnabled = false
            tokenTextField.alpha = 0.5
            pinTextField.alpha = 0.5
        } else {
            statusLabel.text = "Not Authenticated"
            statusIndicator.backgroundColor = .systemRed
            loginButton.isHidden = false
            logoutButton.isHidden = true
            tokenTextField.isEnabled = true
            pinTextField.isEnabled = true
            tokenTextField.alpha = 1.0
            pinTextField.alpha = 1.0
        }
    }

    private func loadStoredCredentials() {
        if let token = PassAuthManager.shared.getToken() {
            tokenTextField.text = token
        }
    }

    // MARK: - Actions
    @objc private func loginTapped() {
        guard let token = tokenTextField.text, !token.isEmpty else {
            showAlert(title: "Error", message: "Please enter your Pass token")
            return
        }

        guard let pin = pinTextField.text, !pin.isEmpty else {
            showAlert(title: "Error", message: "Please enter your PIN")
            return
        }

        guard token.count == 10 else {
            showAlert(title: "Error", message: "Token must be exactly 10 characters")
            return
        }

        setLoading(true)

        PassAuthManager.shared.login(token: token, pin: pin, longLogin: true) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)

                if result.success {
                    self?.showAlert(title: "Success", message: "You are now authenticated and can post")
                    self?.updateAuthState()
                } else {
                    self?.showAlert(title: "Login Failed", message: result.message ?? "Unknown error")
                }
            }
        }
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout? You will need to re-enter your credentials to post again.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })

        present(alert, animated: true)
    }

    private func performLogout() {
        setLoading(true)

        PassAuthManager.shared.logout { [weak self] _ in
            DispatchQueue.main.async {
                self?.setLoading(false)
                self?.pinTextField.text = ""
                self?.updateAuthState()
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Helpers
    private func setLoading(_ loading: Bool) {
        if loading {
            activityIndicator.startAnimating()
            loginButton.isEnabled = false
            logoutButton.isEnabled = false
        } else {
            activityIndicator.stopAnimating()
            loginButton.isEnabled = true
            logoutButton.isEnabled = true
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension PassSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == tokenTextField {
            pinTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginTapped()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Limit token to 10 characters
        if textField == tokenTextField {
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            return updatedText.count <= 10
        }
        return true
    }
}
