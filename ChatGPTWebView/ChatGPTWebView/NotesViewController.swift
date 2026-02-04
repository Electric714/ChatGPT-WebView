import UIKit

final class NotesViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private var autosaveTimer: Timer?
    private let notesDefaultsKey = "notes.text"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notes"
        view.backgroundColor = .systemBackground
        tabBarItem = UITabBarItem(title: "Notes", image: UIImage(systemName: "note.text"), tag: 0)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Send To…", style: .plain, target: self, action: #selector(showSendToMenu)),
            UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(shareNotes)),
            UIBarButtonItem(title: "Copy", style: .plain, target: self, action: #selector(copyNotes))
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(confirmClear))

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.text = loadNotes()

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autosaveTimer?.invalidate()
        autosaveTimer = nil
        saveNotes(textView.text)
    }

    func textViewDidChange(_ textView: UITextView) {
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.saveNotes(self.textView.text)
        }
    }

    private func loadNotes() -> String {
        UserDefaults.standard.string(forKey: notesDefaultsKey) ?? ""
    }

    private func saveNotes(_ text: String) {
        UserDefaults.standard.set(text, forKey: notesDefaultsKey)
    }

    @objc private func copyNotes() {
        UIPasteboard.general.string = textView.text
    }

    @objc private func shareNotes() {
        let activity = UIActivityViewController(activityItems: [textView.text ?? ""], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(activity, animated: true)
    }

    @objc private func showSendToMenu() {
        let alert = UIAlertController(title: "Send To…", message: nil, preferredStyle: .actionSheet)
        Service.allCases.forEach { service in
            alert.addAction(UIAlertAction(title: service.title, style: .default) { [weak self] _ in
                self?.sendNotes(to: service)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(alert, animated: true)
    }

    private func sendNotes(to service: Service) {
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyNotesAlert()
            return
        }
        UIPasteboard.general.string = textView.text
        if let tabBarController = nearestTabBarController() {
            selectServiceTab(service, in: tabBarController)
            showToast(message: "Copied — paste to send", in: tabBarController.view)
        } else {
            showToast(message: "Copied — paste to send", in: view)
        }
    }

    private func showEmptyNotesAlert() {
        let alert = UIAlertController(title: "Notes are empty", message: "Add something to send first.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func nearestTabBarController() -> UITabBarController? {
        var current: UIViewController? = self
        while let controller = current {
            if let tabBarController = controller as? UITabBarController {
                return tabBarController
            }
            current = controller.parent
        }
        return nil
    }

    private func selectServiceTab(_ service: Service, in tabBarController: UITabBarController) {
        guard let viewControllers = tabBarController.viewControllers else { return }
        if let target = viewControllers.first(where: { controller in
            if let nav = controller as? UINavigationController,
               let webController = nav.viewControllers.first as? WebContainerViewController {
                return webController.serviceType == service
            }
            if let webController = controller as? WebContainerViewController {
                return webController.serviceType == service
            }
            return false
        }) {
            tabBarController.selectedViewController = target
        }
    }

    private func showToast(message: String, in containerView: UIView) {
        let toastLabel = PaddingLabel()
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 0
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true

        containerView.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            toastLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 24),
            toastLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -24)
        ])

        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.25, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.2, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    @objc private func confirmClear() {
        let alert = UIAlertController(title: "Clear Notes?", message: "This will remove all text.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.textView.text = ""
            self?.saveNotes("")
        })
        present(alert, animated: true)
    }
}

private final class PaddingLabel: UILabel {
    private let textInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}
