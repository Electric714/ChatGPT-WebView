import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ ViewController loaded (iOS 16+, Mic OK, Voice Mode Off)")

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let userContentController = WKUserContentController()

        // 1) Keep your existing viewport script
        let viewportScript = WKUserScript(source: """
            (function() {
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0';
                document.head.appendChild(meta);
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(viewportScript)

        // 2) Inject an in-page console (input + output) overlay
        let consoleScript = WKUserScript(source: """
            (function() {
                // Avoid double-injecting if the page is reloaded or SPA navigates
                if (window.__iosConsoleInjected) return;
                window.__iosConsoleInjected = true;

                function safeAppend(parent, child) {
                    try { parent.appendChild(child); } catch (_) {}
                }

                function escapeForText(s) {
                    return (s === null || s === undefined) ? String(s) : String(s);
                }

                // Root panel
                const panel = document.createElement('div');
                panel.id = 'ios-console';
                panel.style.cssText = [
                    'position:fixed',
                    'left:10px',
                    'right:10px',
                    'bottom:10px',
                    'height:200px',
                    'background:rgba(20,20,20,0.92)',
                    'color:#fff',
                    'font-family:ui-monospace, Menlo, SFMono-Regular, monospace',
                    'font-size:12px',
                    'border-radius:12px',
                    'box-shadow:0 6px 24px rgba(0,0,0,0.35)',
                    'z-index:2147483647',
                    'display:flex',
                    'flex-direction:column',
                    'overflow:hidden'
                ].join(';');

                // Header (draggable feel / title)
                const header = document.createElement('div');
                header.style.cssText = [
                    'padding:8px 10px',
                    'display:flex',
                    'align-items:center',
                    'justify-content:space-between',
                    'background:rgba(255,255,255,0.06)',
                    'border-bottom:1px solid rgba(255,255,255,0.08)',
                    'user-select:none'
                ].join(';');

                const title = document.createElement('div');
                title.textContent = 'iOS Console';
                title.style.cssText = 'font-weight:600; letter-spacing:0.2px;';

                const controls = document.createElement('div');
                controls.style.cssText = 'display:flex; gap:8px; align-items:center;';

                const clearBtn = document.createElement('button');
                clearBtn.type = 'button';
                clearBtn.textContent = 'Clear';
                clearBtn.style.cssText = [
                    'background:rgba(255,255,255,0.10)',
                    'color:#fff',
                    'border:none',
                    'padding:6px 10px',
                    'border-radius:10px',
                    'cursor:pointer'
                ].join(';');

                const hideBtn = document.createElement('button');
                hideBtn.type = 'button';
                hideBtn.textContent = 'Hide';
                hideBtn.style.cssText = clearBtn.style.cssText;

                safeAppend(controls, clearBtn);
                safeAppend(controls, hideBtn);
                safeAppend(header, title);
                safeAppend(header, controls);

                // Log area
                const logBox = document.createElement('div');
                logBox.id = 'ios-console-log';
                logBox.style.cssText = [
                    'flex:1',
                    'padding:8px 10px',
                    'overflow:auto',
                    'white-space:pre-wrap',
                    'word-break:break-word'
                ].join(';');

                // Input row
                const inputRow = document.createElement('div');
                inputRow.style.cssText = [
                    'display:flex',
                    'gap:8px',
                    'padding:8px 10px',
                    'border-top:1px solid rgba(255,255,255,0.08)',
                    'background:rgba(0,0,0,0.10)'
                ].join(';');

                const input = document.createElement('input');
                input.id = 'ios-console-input';
                input.placeholder = 'Enter JS and press ↵';
                input.autocapitalize = 'off';
                input.autocomplete = 'off';
                input.spellcheck = false;
                input.style.cssText = [
                    'flex:1',
                    'padding:8px 10px',
                    'border-radius:10px',
                    'border:1px solid rgba(255,255,255,0.12)',
                    'background:rgba(255,255,255,0.06)',
                    'color:#fff',
                    'outline:none'
                ].join(';');

                const runBtn = document.createElement('button');
                runBtn.type = 'button';
                runBtn.textContent = 'Run';
                runBtn.style.cssText = [
                    'background:rgba(0,160,255,0.25)',
                    'color:#fff',
                    'border:none',
                    'padding:8px 12px',
                    'border-radius:10px',
                    'cursor:pointer',
                    'min-width:64px'
                ].join(';');

                safeAppend(inputRow, input);
                safeAppend(inputRow, runBtn);

                safeAppend(panel, header);
                safeAppend(panel, logBox);
                safeAppend(panel, inputRow);

                function addLine(prefix, msg) {
                    const line = document.createElement('div');
                    line.textContent = prefix + ' ' + escapeForText(msg);
                    safeAppend(logBox, line);
                    logBox.scrollTop = logBox.scrollHeight;
                }

                // Expose a log function Swift can call
                window.iosConsoleLog = function(msg) { addLine('›', msg); };
                window.iosConsoleError = function(msg) { addLine('✕', msg); };
                window.iosConsoleLog('Console injected');

                function sendToSwift(code) {
                    try {
                        window.webkit.messageHandlers.consoleInput.postMessage(code);
                    } catch (e) {
                        window.iosConsoleError('Bridge not available: ' + e);
                    }
                }

                function submit() {
                    const code = input.value || '';
                    if (!code.trim()) return;
                    input.value = '';
                    addLine('››', code);
                    sendToSwift(code);
                }

                input.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter') submit();
                });
                runBtn.addEventListener('click', submit);

                clearBtn.addEventListener('click', function() {
                    logBox.textContent = '';
                });

                let hidden = false;
                hideBtn.addEventListener('click', function() {
                    hidden = !hidden;
                    if (hidden) {
                        logBox.style.display = 'none';
                        inputRow.style.display = 'none';
                        panel.style.height = '44px';
                        hideBtn.textContent = 'Show';
                    } else {
                        logBox.style.display = 'block';
                        inputRow.style.display = 'flex';
                        panel.style.height = '200px';
                        hideBtn.textContent = 'Hide';
                        input.focus();
                    }
                });

                // Append when body exists
                const attach = () => {
                    if (document.body && !document.getElementById('ios-console')) {
                        safeAppend(document.body, panel);
                    }
                };

                attach();
                // SPA navigation safety: try again after a tick
                setTimeout(attach, 500);
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(consoleScript)

        // 3) Register JS -> Swift bridge name used by the injected console
        userContentController.add(self, name: "consoleInput")

        config.userContentController = userContentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        view.addSubview(webView)

        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()

        if let url = URL(string: "https://chat.openai.com") {
            let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.webView.load(request)
            }
        }
    }

    // MARK: - JS -> Swift bridge handler
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "consoleInput" else { return }
        guard let code = message.body as? String else { return }

        print("🔧 JS console received: \(code)")

        // Evaluate the provided JS in the page
        webView.evaluateJavaScript(code) { result, error in
            let output: String
            if let error = error {
                output = "Error: \(error.localizedDescription)"
            } else if let result = result {
                output = String(describing: result)
            } else {
                output = "undefined"
            }

            // Escape backticks and backslashes so template literal stays valid
            let safeOutput = output
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")

            self.webView.evaluateJavaScript("window.iosConsoleLog(`\(safeOutput)`);", completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        print("✅ Page finished loading")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error.localizedDescription)")
        activityIndicator.stopAnimating()
    }

    // For mic permission popups from ChatGPT
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        self.present(alert, animated: true, completion: nil)
    }

    deinit {
        // Prevent potential retain cycles / crashes if the VC is torn down
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "consoleInput")
    }
}