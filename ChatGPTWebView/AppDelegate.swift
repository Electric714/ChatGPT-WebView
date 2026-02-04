import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let tabBarController = UITabBarController()

        let chatController = WebContainerViewController(service: .chatgpt)
        chatController.tabBarItem = UITabBarItem(
            title: WebService.chatgpt.title,
            image: UIImage(systemName: "message.fill"),
            tag: 0
        )

        let geminiController = WebContainerViewController(service: .gemini)
        geminiController.tabBarItem = UITabBarItem(
            title: WebService.gemini.title,
            image: UIImage(systemName: "sparkles"),
            tag: 1
        )

        let grokController = WebContainerViewController(service: .grok)
        grokController.tabBarItem = UITabBarItem(
            title: WebService.grok.title,
            image: UIImage(systemName: "bolt.fill"),
            tag: 2
        )

        tabBarController.viewControllers = [chatController, geminiController, grokController]
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
        return true
    }
}
