import UIKit

final class MainTabBarController: UITabBarController {
    private var memoryWarningObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        var controllers = Service.allCases.map { service in
            let webController = WebContainerViewController(service: service)
            return UINavigationController(rootViewController: webController)
        }
        let notesController = NotesViewController()
        controllers.append(UINavigationController(rootViewController: notesController))
        viewControllers = controllers
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    private func handleMemoryWarning() {
        let selectedController = selectedViewController
        viewControllers?.forEach { controller in
            guard controller !== selectedController else { return }
            if let navigationController = controller as? UINavigationController,
               let webController = navigationController.viewControllers.first as? WebContainerViewController {
                webController.releaseWebView()
            } else if let webController = controller as? WebContainerViewController {
                webController.releaseWebView()
            }
        }
    }
}
