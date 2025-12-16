import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private var webView: WKWebView!
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let enableCGPTWVConsole = true

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

        if enableCGPTWVConsole {
            let consoleScript = WKUserScript(
                source: cgptwvConsoleScript(),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(consoleScript)
        }

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

extension ViewController {
    private func cgptwvConsoleScript() -> String {
        return #"""

        (function() {
          if (window.__cgptwv_installed) return;
          window.__cgptwv_installed = true;

          const ROOT_ID = '__cgptwv_root';
          const TOGGLE_ID = '__cgptwv_toggle';
          const HISTORY_KEY = '__cgptwv_history';
          const STATE_KEY = '__cgptwv_state';
          const MAX_HISTORY = 50;
          const MAX_LOG_LEN = 20000;
          const MAX_NETWORK = 100;

          const loadJSON = (key, fallback) => {
            try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch (_) { return fallback; }
          };
          const saveJSON = (key, value) => {
            try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {}
          };

          let history = loadJSON(HISTORY_KEY, []);
          let state = loadJSON(STATE_KEY, { open: false, fetchHook: false });
          let historyIndex = history.length;

          const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
          const networkLogs = [];

          function ensureStyle() {
            if (document.getElementById('__cgptwv_style')) return;
            const style = document.createElement('style');
            style.id = '__cgptwv_style';
            style.textContent = `
              #${ROOT_ID} { position: fixed; z-index: 2147483000; bottom: 16px; right: 16px; width: min(480px, 90vw); background: rgba(17,17,17,0.95); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.12); border-radius: 12px; box-shadow: 0 12px 40px rgba(0,0,0,0.4); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 10px; display: flex; flex-direction: column; gap: 8px; }
              #${ROOT_ID}.hidden { display: none; }
              #${ROOT_ID} * { box-sizing: border-box; }
              #${ROOT_ID} .__cgptwv_header { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
              #${ROOT_ID} .__cgptwv_title { font-weight: 700; font-size: 14px; }
              #${ROOT_ID} .__cgptwv_output { height: 160px; overflow: auto; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; padding: 8px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; line-height: 1.4; }
              #${ROOT_ID} .__cgptwv_entry { margin-bottom: 6px; white-space: pre-wrap; word-break: break-word; }
              #${ROOT_ID} .__cgptwv_entry .time { color: #9ca3af; margin-right: 6px; }
              #${ROOT_ID} .__cgptwv_entry .error { color: #fca5a5; }
              #${ROOT_ID} textarea.__cgptwv_input { width: 100%; min-height: 80px; background: rgba(255,255,255,0.06); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 8px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; resize: vertical; }
              #${ROOT_ID} .__cgptwv_row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
              #${ROOT_ID} button.__cgptwv_btn { background: rgba(255,255,255,0.08); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.18); border-radius: 8px; padding: 6px 10px; cursor: pointer; font-size: 12px; }
              #${ROOT_ID} button.__cgptwv_btn:hover { background: rgba(255,255,255,0.16); }
              #${ROOT_ID} .__cgptwv_small { font-size: 12px; color: #d1d5db; }
              #${ROOT_ID} .__cgptwv_network { background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; padding: 8px; max-height: 140px; overflow: auto; font-size: 12px; display: flex; flex-direction: column; gap: 4px; }
              #${ROOT_ID} .__cgptwv_net_item { border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 4px; }
              #${ROOT_ID} .__cgptwv_net_item:last-child { border-bottom: none; }
              #${ROOT_ID} .__cgptwv_net_meta { display: flex; gap: 6px; flex-wrap: wrap; color: #e5e7eb; }
              #${ROOT_ID} .__cgptwv_net_url { color: #bfdbfe; word-break: break-all; }
              #${ROOT_ID} .__cgptwv_toggle_btn { position: fixed; bottom: 16px; right: 16px; z-index: 2147483001; background: rgba(17,17,17,0.95); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.18); border-radius: 10px; padding: 10px; font-size: 16px; cursor: pointer; }
            `;
            document.head.appendChild(style);
          }

          function ensureContainers() {
            ensureStyle();
            let root = document.getElementById(ROOT_ID);
            if (!root) {
              root = document.createElement('div');
              root.id = ROOT_ID;
              document.body.appendChild(root);
            }
            let toggle = document.getElementById(TOGGLE_ID);
            if (!toggle) {
              toggle = document.createElement('button');
              toggle.id = TOGGLE_ID;
              toggle.textContent = '≡';
              toggle.className = '__cgptwv_toggle_btn';
              toggle.addEventListener('click', () => {
                state.open = !state.open;
                saveJSON(STATE_KEY, state);
                applyVisibility();
              });
              document.body.appendChild(toggle);
            }
            return root;
          }

          function applyVisibility() {
            const root = document.getElementById(ROOT_ID);
            if (!root) return;
            root.classList.toggle('hidden', !state.open);
          }

          function safeStringify(value) {
            if (value === undefined) return 'undefined';
            if (value === null) return 'null';
            if (typeof value === 'string') return value;
            if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') return String(value);
            const seen = new WeakSet();
            try {
              const str = JSON.stringify(value, function(key, val) {
                if (val instanceof Error) {
                  return { name: val.name, message: val.message, stack: val.stack };
                }
                if (typeof val === 'object' && val !== null) {
                  if (seen.has(val)) return '[circular]';
                  seen.add(val);
                }
                if (typeof val === 'function') return `[Function ${val.name || 'anonymous'}]`;
                if (typeof val === 'bigint') return `${val.toString()}n`;
                return val;
              }, 2);
              if (!str) return String(value);
              return str.length > MAX_LOG_LEN ? str.slice(0, MAX_LOG_LEN) + '\n...[truncated]' : str;
            } catch (err) {
              const msg = err && err.message ? err.message : String(err);
              return `[unserializable: ${msg}]`;
            }
          }
          window.__cgptwv_safeStringify = safeStringify;

          function formatError(err) {
            if (!err) return 'Unknown error';
            const name = err.name || 'Error';
            const message = err.message || String(err);
            const stack = err.stack ? `\n${err.stack}` : '';
            return `${name}: ${message}${stack}`;
          }

          function appendLog(text, isError) {
            const output = document.getElementById('__cgptwv_output');
            if (!output) return;
            const entry = document.createElement('div');
            entry.className = '__cgptwv_entry';
            const time = document.createElement('span');
            time.className = 'time';
            time.textContent = `[${new Date().toLocaleTimeString()}]`;
            const body = document.createElement('span');
            body.className = isError ? 'error' : 'normal';
            body.textContent = text;
            entry.append(time, body);
            output.appendChild(entry);
            output.scrollTop = output.scrollHeight;
          }

          function trimNetwork() {
            while (networkLogs.length > MAX_NETWORK) networkLogs.shift();
          }

          function renderNetwork() {
            const list = document.getElementById('__cgptwv_network_list');
            if (!list) return;
            list.innerHTML = '';
            networkLogs.forEach((entry) => {
              const wrap = document.createElement('div');
              wrap.className = '__cgptwv_net_item';
              const meta = document.createElement('div');
              meta.className = '__cgptwv_net_meta';
              const type = document.createElement('span');
              type.textContent = 'fetch';
              const method = document.createElement('span');
              method.textContent = entry.method || '';
              const status = document.createElement('span');
              status.textContent = entry.status != null ? `status: ${entry.status}` : 'pending';
              const dur = document.createElement('span');
              dur.textContent = entry.durationMs != null ? `${entry.durationMs} ms` : '';
              meta.append(type, method, status, dur);
              const url = document.createElement('div');
              url.className = '__cgptwv_net_url';
              url.textContent = entry.url;
              wrap.append(meta, url);
              list.appendChild(wrap);
            });
          }

          const originalFetch = window.fetch;
          const wrappedFetch = async (...args) => {
            const start = performance.now();
            const url = (() => {
              const target = args[0];
              if (!target) return '';
              if (typeof target === 'string') return target;
              if (target.url) return target.url;
              try { return String(target); } catch (_) { return ''; }
            })();
            const method = ((args[1] && args[1].method) || 'GET').toString().toUpperCase();
            try {
              const resp = await originalFetch.apply(window, args);
              networkLogs.push({ type: 'fetch', method, url, status: resp.status, durationMs: Math.round(performance.now() - start) });
              trimNetwork();
              renderNetwork();
              return resp;
            } catch (err) {
              networkLogs.push({ type: 'fetch', method, url, status: 'error', durationMs: Math.round(performance.now() - start) });
              trimNetwork();
              renderNetwork();
              throw err;
            }
          };

          function setFetchHook(enabled) {
            state.fetchHook = !!enabled;
            saveJSON(STATE_KEY, state);
            const indicator = document.getElementById('__cgptwv_fetch_state');
            if (indicator) indicator.textContent = state.fetchHook ? 'ON' : 'OFF';
            const checkbox = document.getElementById('__cgptwv_fetch_toggle');
            if (checkbox) checkbox.checked = state.fetchHook;
            if (state.fetchHook) {
              if (window.fetch !== wrappedFetch) window.fetch = wrappedFetch;
            } else {
              if (window.fetch !== originalFetch) window.fetch = originalFetch;
            }
          }

          async function runCode(raw) {
            const code = (raw || '').trim();
            if (!code) return;
            history.push(raw);
            history = history.slice(-MAX_HISTORY);
            historyIndex = history.length;
            saveJSON(HISTORY_KEY, history);
            const input = document.getElementById('__cgptwv_input');
            if (input) input.value = '';

            let fn;
            try {
              fn = new AsyncFunction('return (' + raw + ')');
            } catch (err) {
              if (err instanceof SyntaxError) {
                try {
                  fn = new AsyncFunction(raw);
                } catch (err2) {
                  appendLog(formatError(err2), true);
                  return;
                }
              } else {
                appendLog(formatError(err), true);
                return;
              }
            }

            try {
              const result = await fn();
              appendLog(safeStringify(result), false);
            } catch (err) {
              appendLog(formatError(err), true);
            }
          }

          function bindUI(root) {
            root.innerHTML = `
              <div class="__cgptwv_header">
                <div class="__cgptwv_title">CGPTWV Console</div>
                <div class="__cgptwv_row">
                  <label class="__cgptwv_small"><input type="checkbox" id="__cgptwv_fetch_toggle" /> Fetch Hook</label>
                  <span class="__cgptwv_small" id="__cgptwv_fetch_state"></span>
                  <button class="__cgptwv_btn" id="__cgptwv_hide">Hide</button>
                </div>
              </div>
              <div class="__cgptwv_output" id="__cgptwv_output"></div>
              <textarea class="__cgptwv_input __cgptwv_inputbox" id="__cgptwv_input" placeholder="Enter JS. Enter to run, Shift+Enter for newline"></textarea>
              <div class="__cgptwv_row">
                <button class="__cgptwv_btn" id="__cgptwv_run">Run</button>
                <button class="__cgptwv_btn" id="__cgptwv_clear">Clear</button>
              </div>
              <div class="__cgptwv_network">
                <div class="__cgptwv_small">Network (fetch metadata)</div>
                <div id="__cgptwv_network_list"></div>
              </div>
            `;

            const input = document.getElementById('__cgptwv_input');
            const runBtn = document.getElementById('__cgptwv_run');
            const clearBtn = document.getElementById('__cgptwv_clear');
            const hideBtn = document.getElementById('__cgptwv_hide');
            const fetchToggle = document.getElementById('__cgptwv_fetch_toggle');

            runBtn?.addEventListener('click', () => runCode(input?.value || ''));
            clearBtn?.addEventListener('click', () => {
              const output = document.getElementById('__cgptwv_output');
              if (output) output.innerHTML = '';
            });
            hideBtn?.addEventListener('click', () => {
              state.open = false;
              saveJSON(STATE_KEY, state);
              applyVisibility();
            });

            fetchToggle?.addEventListener('change', (e) => {
              setFetchHook(e.target.checked);
            });

            if (input) {
              input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  runCode(input.value);
                } else if (e.key === 'ArrowUp' && input.selectionStart === 0 && input.selectionEnd === 0) {
                  if (historyIndex > 0) historyIndex -= 1;
                  input.value = history[historyIndex] || '';
                  e.preventDefault();
                } else if (e.key === 'ArrowDown' && input.selectionStart === input.value.length && input.selectionEnd === input.value.length) {
                  if (historyIndex < history.length) historyIndex += 1;
                  input.value = history[historyIndex] || '';
                  e.preventDefault();
                }
              });
            }

            setFetchHook(state.fetchHook);
            applyVisibility();
            renderNetwork();
          }

          function mount() {
            const root = ensureContainers();
            if (!root) return;
            bindUI(root);
            applyVisibility();
          }

          mount();
          setInterval(() => {
            if (!document.getElementById(ROOT_ID) || !document.getElementById(TOGGLE_ID)) {
              mount();
            }
          }, 1000);
        })();
                """#
    }
}
