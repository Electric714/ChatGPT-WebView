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
