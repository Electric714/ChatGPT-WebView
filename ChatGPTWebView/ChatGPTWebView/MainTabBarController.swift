import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let webControllers = Service.allCases.map { service in
            let webController = WebContainerViewController(service: service)
            return UINavigationController(rootViewController: webController)
        }
        let notesController = UINavigationController(rootViewController: NotesViewController())
        viewControllers = webControllers + [notesController]
    }
}
