import UIKit
import WebKit

final class WebContainerViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    static let sharedProcessPool = WKProcessPool()

    private(set) var webView: WKWebView?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let service: Service

    init(service: Service) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
        title = service.title
        tabBarItem = UITabBarItem(title: service.title, image: UIImage(systemName: service.tabIconSystemName), tag: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureActivityIndicator()
        configureNavigationItems()
        createWebViewIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        createWebViewIfNeeded()
    }

    func releaseWebView() {
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
    }

    private func configureActivityIndicator() {
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }

    private func configureNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "safari"),
            style: .plain,
            target: self,
            action: #selector(openInSafari)
        )
    }

    private func createWebViewIfNeeded() {
        guard webView == nil else { return }
        let config = makeConfiguration()
        let newWebView = WKWebView(frame: view.bounds, configuration: config)
        if let userAgent = service.userAgentOverride {
            newWebView.customUserAgent = userAgent
        }
        newWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self
        newWebView.allowsBackForwardNavigationGestures = true
        newWebView.backgroundColor = .systemBackground
        newWebView.isOpaque = false
        view.insertSubview(newWebView, belowSubview: activityIndicator)
        webView = newWebView
        loadHomeIfNeeded()
    }

    private func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = false

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        prefs.preferredContentMode = .mobile
        config.defaultWebpagePreferences = prefs

        let userContentController = WKUserContentController()
        if let injectedJavaScript = service.injectedJavaScript {
            if let documentStart = injectedJavaScript.documentStart {
                let script = WKUserScript(source: documentStart, injectionTime: .atDocumentStart, forMainFrameOnly: true)
                userContentController.addUserScript(script)
            }
            if let documentEnd = injectedJavaScript.documentEnd {
                let script = WKUserScript(source: documentEnd, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                userContentController.addUserScript(script)
            }
        }
        config.userContentController = userContentController

        return config
    }

    private func loadHomeIfNeeded() {
        guard let webView else { return }
        guard webView.url == nil else { return }
        activityIndicator.startAnimating()
        let request = URLRequest(url: service.homeURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            webView.load(request)
        }
    }

    @objc private func openInSafari() {
        let destination = webView?.url ?? service.homeURL
        UIApplication.shared.open(destination, options: [:], completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        if let didFinishScript = service.injectedJavaScript?.didFinish {
            webView.evaluateJavaScript(didFinishScript, completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        print("❌ Navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true, completion: nil)
    }
}
