import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = Service.allCases.map { service in
            let webController = WebContainerViewController(service: service)
            return UINavigationController(rootViewController: webController)
        }
    }
}
