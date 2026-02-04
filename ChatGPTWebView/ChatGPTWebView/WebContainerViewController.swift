import UIKit
import WebKit

final class WebContainerViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    static let sharedProcessPool = WKProcessPool()

    private(set) var webView: WKWebView?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let service: Service
    private var lastKnownURL: URL?
    private var memoryWarningObserver: NSObjectProtocol?
    private lazy var zoomBarButtonItem = UIBarButtonItem(
        title: "Zoom 100%",
        style: .plain,
        target: self,
        action: #selector(showZoomOptions)
    )
    private let zoomStep: Double = 0.05
    private let minZoomScale: Double = 0.5
    private let maxZoomScale: Double = 2.0

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
        recreateWebViewIfNeeded()
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recreateWebViewIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSelection()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        handleDeselection()
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    func unloadIfNeeded() {
        guard let webView else { return }
        lastKnownURL = webView.url ?? lastKnownURL
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        self.webView = nil
        activityIndicator.stopAnimating()
    }

    private func configureActivityIndicator() {
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }

    private func configureNavigationItems() {
        let safariButton = UIBarButtonItem(
            image: UIImage(systemName: "safari"),
            style: .plain,
            target: self,
            action: #selector(openInSafari)
        )
        navigationItem.rightBarButtonItems = [safariButton, zoomBarButtonItem]
        updateZoomButtonTitle(scale: storedZoomScale)
    }

    private func recreateWebViewIfNeeded() {
        guard webView == nil else {
            webView?.isHidden = false
            return
        }
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
        loadLastURLIfNeeded()
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

    private func loadLastURLIfNeeded() {
        guard let webView else { return }
        guard webView.url == nil else { return }
        activityIndicator.startAnimating()
        let destination = lastKnownURL ?? service.homeURL
        let request = URLRequest(url: destination, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            webView.load(request)
        }
    }

    @objc private func openInSafari() {
        let destination = webView?.url ?? service.homeURL
        UIApplication.shared.open(destination, options: [:], completionHandler: nil)
    }

    @objc private func showZoomOptions() {
        let alert = UIAlertController(title: "Zoom", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Zoom Out (−5%)", style: .default) { [weak self] _ in
            guard let self else { return }
            self.adjustZoom(by: -self.zoomStep)
        })
        alert.addAction(UIAlertAction(title: "Zoom In (+5%)", style: .default) { [weak self] _ in
            guard let self else { return }
            self.adjustZoom(by: self.zoomStep)
        })
        alert.addAction(UIAlertAction(title: "Reset (100%)", style: .default) { [weak self] _ in
            self?.setZoom(scale: 1.0)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = zoomBarButtonItem
        }

        present(alert, animated: true, completion: nil)
    }

    private var storedZoomScale: Double {
        get {
            let defaults = UserDefaults.standard
            let key = service.zoomDefaultsKey
            if let value = defaults.object(forKey: key) as? Double {
                return clampZoomScale(value)
            }
            return 1.0
        }
        set {
            UserDefaults.standard.set(clampZoomScale(newValue), forKey: service.zoomDefaultsKey)
        }
    }

    private func clampZoomScale(_ scale: Double) -> Double {
        return min(max(scale, minZoomScale), maxZoomScale)
    }

    private func adjustZoom(by delta: Double) {
        setZoom(scale: storedZoomScale + delta)
    }

    private func setZoom(scale: Double) {
        let clamped = clampZoomScale(scale)
        storedZoomScale = clamped
        applyZoom(scale: clamped)
        updateZoomButtonTitle(scale: clamped)
    }

    private func applyStoredZoomIfNeeded() {
        applyZoom(scale: storedZoomScale)
        updateZoomButtonTitle(scale: storedZoomScale)
    }

    private func updateZoomButtonTitle(scale: Double) {
        let percent = Int(round(scale * 100))
        zoomBarButtonItem.title = "Zoom \(percent)%"
    }

    private func applyZoom(scale: Double) {
        guard let webView else { return }
        let formattedScale = String(format: "%.2f", scale)
        let script = """
        (function() {
          var scale = \(formattedScale);
          if (document.body) {
            document.body.style.zoom = scale;
          }
          if (document.documentElement) {
            document.documentElement.style.zoom = scale;
          }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        lastKnownURL = webView.url ?? lastKnownURL
        if let didFinishScript = service.injectedJavaScript?.didFinish {
            webView.evaluateJavaScript(didFinishScript, completionHandler: nil)
        }
        applyStoredZoomIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        print("❌ Navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else { return }
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

    private func handleSelection() {
        recreateWebViewIfNeeded()
        webView?.isHidden = false
        loadLastURLIfNeeded()
    }

    private func handleDeselection() {
        webView?.stopLoading()
        webView?.isHidden = true
        activityIndicator.stopAnimating()
    }

    private func handleMemoryWarning() {
        guard !isSelectedTab else { return }
        unloadIfNeeded()
    }

    private var isSelectedTab: Bool {
        guard let tabBarController else { return true }
        if let navigationController {
            return tabBarController.selectedViewController === navigationController
        }
        return tabBarController.selectedViewController === self
    }
}
