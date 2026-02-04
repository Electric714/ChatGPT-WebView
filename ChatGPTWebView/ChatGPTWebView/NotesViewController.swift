import UIKit

final class NotesViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private var autosaveWorkItem: DispatchWorkItem?
    private let storageKey = "notes.autosave.text"
    private let autosaveDelay: TimeInterval = 0.6
    private var keyboardObservers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notes"
        view.backgroundColor = .systemBackground
        configureTextView()
        configurePlaceholder()
        configureNavigationItems()
        loadSavedNote()
        updatePlaceholderVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForKeyboardNotifications()
    }

    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        scheduleAutosave()
    }

    private func configureTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configurePlaceholder() {
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Write here…"
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.font = textView.font
        placeholderLabel.numberOfLines = 0
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 6),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -6)
        ])
    }

    private func configureNavigationItems() {
        let copyItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyTapped)
        )
        let shareItem = UIBarButtonItem(
            title: "Share",
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        let clearItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )
        navigationItem.rightBarButtonItems = [shareItem, copyItem]
        navigationItem.leftBarButtonItem = clearItem
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = textView.text
    }

    @objc private func shareTapped() {
        let text = textView.text ?? ""
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(controller, animated: true)
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(
            title: "Clear Note",
            message: "Are you sure you want to clear this note?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.textView.text = ""
            self?.updatePlaceholderVisibility()
            self?.saveNote()
        })
        present(alert, animated: true)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNote()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: workItem)
    }

    private func saveNote() {
        UserDefaults.standard.set(textView.text, forKey: storageKey)
    }

    private func loadSavedNote() {
        if let saved = UserDefaults.standard.string(forKey: storageKey) {
            textView.text = saved
        }
    }

    private func registerForKeyboardNotifications() {
        guard keyboardObservers.isEmpty else { return }
        let willChange = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboard(notification: notification)
        }
        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTextViewInsets(bottomInset: 0)
        }
        keyboardObservers = [willChange, willHide]
    }

    private func unregisterForKeyboardNotifications() {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
    }

    private func handleKeyboard(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else {
            return
        }

        let keyboardFrame = frameValue.cgRectValue
        let keyboardFrameInView = view.convert(keyboardFrame, from: view.window)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.origin.y)
        let bottomInset = max(0, overlap - view.safeAreaInsets.bottom)
        updateTextViewInsets(bottomInset: bottomInset)
    }

    private func updateTextViewInsets(bottomInset: CGFloat) {
        var insets = textView.contentInset
        insets.bottom = bottomInset
        textView.contentInset = insets
        textView.scrollIndicatorInsets = insets
    }
}
