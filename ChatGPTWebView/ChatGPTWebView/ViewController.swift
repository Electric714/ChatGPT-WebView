import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private var webView: WKWebView!
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ ViewController loaded (Document Start Sidebar Fix + Voice Mode OK)")

        // MARK: - WebView Configuration
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = false

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        prefs.preferredContentMode = .mobile
        config.defaultWebpagePreferences = prefs

        let userContentController = WKUserContentController()

        // Inject BEFORE React hydration: force sidebar closed
        let preHydrationSidebarFix = WKUserScript(
            source: """
            try {
              localStorage.setItem('sidebar-expanded-state', 'false');
              console.log('💥 Injected: sidebar-expanded-state set to false BEFORE hydration');
            } catch (e) {
              console.log('⚠️ Failed to set sidebar state early:', e);
            }
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(preHydrationSidebarFix)

        // Inject viewport tag AFTER DOM builds
        let viewportScript = WKUserScript(source: """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0';
            document.head.appendChild(meta);
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(viewportScript)

        config.userContentController = userContentController

        // MARK: - Initialize WebView
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        view.addSubview(webView)

        // MARK: - Spinner Setup
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()

        // MARK: - Load ChatGPT (Stable landing page)
        if let url = URL(string: "https://chat.openai.com") {
            let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.webView.load(request)
            }
        }
    }

    // MARK: - WebView Delegates

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        print("✅ Page finished loading")

        // Optional: bind hold-to-speak icon to mic (future-facing)
        let voiceBind = """
        setTimeout(() => {
          try {
            const voiceBtn = document.querySelector('[aria-label="Hold to speak"]');
            const micBtn = document.querySelector('[aria-label="Start voice input"]');
            if (voiceBtn && micBtn) {
              voiceBtn.addEventListener('mousedown', () => micBtn.click());
              console.log('🎤 Hold-to-speak rebound to mic');
            }
          } catch (e) {
            console.log('❌ Mic bind failed:', e);
          }
        }, 3000);
        """
        webView.evaluateJavaScript(voiceBind, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        print("❌ Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        self.present(alert, animated: true, completion: nil)
    }
}
