import UIKit

final class NotesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notes"
        view.backgroundColor = .systemBackground
        tabBarItem = UITabBarItem(title: "Notes", image: UIImage(systemName: "note.text"), tag: 0)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Notes"
        label.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        label.textColor = .secondaryLabel

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
