import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let enableCGPTWVConsole = true
    private let defaultHooksEnabled = false

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
            userContentController.add(self, name: "__cgptwv_consoleBridge")
            let consoleScript = WKUserScript(
                source: cgptwvConsoleScript(defaultHooks: defaultHooksEnabled),
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

// MARK: - WKScriptMessageHandler

extension ViewController {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard enableCGPTWVConsole, message.name == "__cgptwv_consoleBridge" else { return }
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }

        switch type {
        case "log":
            if let level = body["level"] as? String, let msg = body["message"] as? String {
                print("[JS console][\(level)] \(msg)")
            }
        case "eval":
            guard let code = body["code"] as? String, let evalId = body["id"] as? String else { return }
            webView?.evaluateJavaScript(code) { [weak self] result, error in
                var payload: [String: Any] = [:]
                if let error = error {
                    payload = [
                        "status": "rejected",
                        "error": [
                            "message": error.localizedDescription
                        ]
                    ]
                } else {
                    payload = [
                        "status": "fulfilled",
                        "value": result ?? NSNull()
                    ]
                }

                self?.sendEvalResult(id: evalId, payload: payload)
            }
        default:
            break
        }
    }

    private func sendEvalResult(id: String, payload: [String: Any]) {
        guard let webView else { return }
        let idJSON = (try? JSONSerialization.data(withJSONObject: id))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let payloadJSON = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let js = "window.__cgptwv_onEvalResult && window.__cgptwv_onEvalResult(\(idJSON), \(payloadJSON));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func cgptwvConsoleScript(defaultHooks: Bool) -> String {
        let hooksDefault = defaultHooks ? "true" : "false"
        return """
        (function() {
          try {
            if (window.__cgptwv_initialized) {
              const existingRoot = document.getElementById('__cgptwv_root');
              if (!existingRoot && document.body) {
                document.body.appendChild(window.__cgptwv_rootElement);
              }
              return;
            }
            window.__cgptwv_initialized = true;

            const ROOT_ID = '__cgptwv_root';
            const HISTORY_KEY = '__cgptwv_history';
            const STATE_KEY = '__cgptwv_state';
            const MAX_HISTORY = 100;
            const MAX_NETWORK = 200;
            const BODY_LIMIT = 64 * 1024;

            const state = (() => {
              try {
                return JSON.parse(localStorage.getItem(STATE_KEY) || '{}');
              } catch (_) {
                return {};
              }
            })();

            const history = (() => {
              try {
                return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]');
              } catch (_) {
                return [];
              }
            })();

            const networkEntries = [];

            function persistHistory() {
              try { localStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(-MAX_HISTORY))); } catch (_) {}
            }

            function persistState() {
              try { localStorage.setItem(STATE_KEY, JSON.stringify(state)); } catch (_) {}
            }

            function ts() {
              return new Date().toLocaleTimeString();
            }

            function ensureRoot() {
              let root = document.getElementById(ROOT_ID);
              if (root) return root;
              root = document.createElement('div');
              root.id = ROOT_ID;
              document.body.appendChild(root);
              window.__cgptwv_rootElement = root;
              return root;
            }

            function createStyle() {
              const style = document.createElement('style');
              style.id = '__cgptwv_style';
              style.textContent = `
              #${ROOT_ID} { position: fixed; z-index: 2147483000; bottom: 16px; right: 16px; width: min(480px, 90vw); height: 420px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #f8f9fa; background: rgba(12,12,12,0.92); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; backdrop-filter: blur(10px); box-shadow: 0 12px 50px rgba(0,0,0,0.45); overflow: hidden; display: flex; flex-direction: column; }
              #${ROOT_ID}.hidden { display: none; }
              #${ROOT_ID} * { box-sizing: border-box; }
              #${ROOT_ID} .__cgptwv_header { display: flex; align-items: center; justify-content: space-between; padding: 10px 12px; background: rgba(255,255,255,0.04); border-bottom: 1px solid rgba(255,255,255,0.08); }
              #${ROOT_ID} .__cgptwv_title { font-weight: 700; font-size: 14px; letter-spacing: 0.3px; }
              #${ROOT_ID} .__cgptwv_tabs { display: flex; gap: 8px; }
              #${ROOT_ID} .__cgptwv_tab { padding: 6px 10px; border-radius: 8px; cursor: pointer; font-size: 13px; background: rgba(255,255,255,0.06); border: 1px solid transparent; }
              #${ROOT_ID} .__cgptwv_tab.active { background: rgba(255,255,255,0.12); border-color: rgba(255,255,255,0.2); }
              #${ROOT_ID} .__cgptwv_actions { display: flex; gap: 6px; align-items: center; }
              #${ROOT_ID} button.__cgptwv_btn { background: rgba(255,255,255,0.08); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 6px 10px; cursor: pointer; font-size: 12px; }
              #${ROOT_ID} button.__cgptwv_btn:hover { background: rgba(255,255,255,0.16); }
              #${ROOT_ID} .__cgptwv_content { flex: 1; display: flex; flex-direction: column; padding: 10px; gap: 8px; overflow: hidden; }
              #${ROOT_ID} .__cgptwv_output { flex: 1; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; padding: 10px; overflow: auto; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; line-height: 1.4; }
              #${ROOT_ID} .__cgptwv_entry { margin-bottom: 8px; }
              #${ROOT_ID} .__cgptwv_entry .time { color: #9ca3af; margin-right: 6px; }
              #${ROOT_ID} .__cgptwv_entry .error { color: #fca5a5; }
              #${ROOT_ID} textarea.__cgptwv_input { width: 100%; min-height: 72px; max-height: 140px; background: rgba(255,255,255,0.06); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 8px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; resize: vertical; }
              #${ROOT_ID} .__cgptwv_status { display: flex; gap: 8px; align-items: center; font-size: 12px; color: #d1d5db; }
              #${ROOT_ID} .__cgptwv_status .pill { padding: 4px 8px; border-radius: 999px; border: 1px solid rgba(255,255,255,0.2); }
              #${ROOT_ID} .__cgptwv_status .on { background: rgba(16,185,129,0.15); border-color: rgba(16,185,129,0.5); color: #a7f3d0; }
              #${ROOT_ID} .__cgptwv_status .off { background: rgba(239,68,68,0.1); border-color: rgba(239,68,68,0.4); color: #fecdd3; }
              #${ROOT_ID} .__cgptwv_row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
              #${ROOT_ID} .__cgptwv_network { flex: 1; overflow: hidden; display: flex; flex-direction: column; }
              #${ROOT_ID} .__cgptwv_network_filters { display: flex; gap: 8px; align-items: center; margin-bottom: 6px; flex-wrap: wrap; }
              #${ROOT_ID} .__cgptwv_network_list { flex: 1; overflow: auto; border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; background: rgba(255,255,255,0.04); padding: 8px; }
              #${ROOT_ID} .__cgptwv_net_item { border-bottom: 1px solid rgba(255,255,255,0.06); padding: 6px 0; }
              #${ROOT_ID} .__cgptwv_net_item:last-child { border-bottom: none; }
              #${ROOT_ID} .__cgptwv_net_meta { font-size: 11px; color: #e5e7eb; display: flex; gap: 8px; flex-wrap: wrap; }
              #${ROOT_ID} .__cgptwv_net_url { font-size: 12px; color: #bfdbfe; word-break: break-all; }
              #${ROOT_ID} .__cgptwv_badge { padding: 2px 6px; border-radius: 6px; font-size: 10px; text-transform: uppercase; letter-spacing: 0.4px; }
              #${ROOT_ID} .__cgptwv_badge.fetch { background: rgba(96,165,250,0.2); border: 1px solid rgba(96,165,250,0.5); }
              #${ROOT_ID} .__cgptwv_badge.xhr { background: rgba(244,114,182,0.2); border: 1px solid rgba(244,114,182,0.4); }
              #${ROOT_ID} .__cgptwv_badge.ws { background: rgba(52,211,153,0.2); border: 1px solid rgba(52,211,153,0.5); }
              #${ROOT_ID} .__cgptwv_net_body { margin-top: 4px; white-space: pre-wrap; color: #d1d5db; font-size: 11px; }
              #${ROOT_ID} .__cgptwv_small { font-size: 11px; color: #9ca3af; }
              #${ROOT_ID} .__cgptwv_toggle { display: inline-flex; gap: 4px; align-items: center; font-size: 12px; }
              #${ROOT_ID} .__cgptwv_toggle input { accent-color: #22c55e; }
              #${ROOT_ID} .__cgptwv_filter_input { padding: 6px 8px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.15); background: rgba(255,255,255,0.06); color: #f8f9fa; font-size: 12px; }
              #${ROOT_ID} .__cgptwv_corner { position: absolute; top: 8px; right: 8px; }
              #${ROOT_ID} .__cgptwv_toggle_btn { position: fixed; bottom: 16px; left: 16px; z-index: 2147483000; background: rgba(12,12,12,0.92); color: #f8f9fa; border: 1px solid rgba(255,255,255,0.15); border-radius: 10px; padding: 8px 10px; font-size: 13px; cursor: pointer; }
              `;
              document.head.appendChild(style);
            }

            function safeStringify(value) {
              const seen = new WeakSet();
              return JSON.stringify(value, function(key, val) {
                if (typeof val === 'object' && val !== null) {
                  if (seen.has(val)) return '[circular]';
                  seen.add(val);
                }
                if (typeof val === 'function') return `[Function ${val.name || 'anonymous'}]`;
                if (typeof val === 'bigint') return `${val.toString()}n`;
                return val;
              }, 2);
            }
            window.__cgptwv_safeStringify = safeStringify;

            function formatOutput(value) {
              if (value === undefined) return 'undefined';
              if (value === null) return 'null';
              if (typeof value === 'string') return value;
              if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') return String(value);
              try { return safeStringify(value); } catch (e) { return `[unserializable: ${e.message}]`; }
            }

            function appendConsole({ text, isError }) {
              const output = document.getElementById('__cgptwv_console_output');
              if (!output) return;
              const div = document.createElement('div');
              div.className = '__cgptwv_entry';
              const time = document.createElement('span');
              time.className = 'time';
              time.textContent = `[${ts()}]`;
              const body = document.createElement('span');
              body.className = isError ? 'error' : 'normal';
              body.textContent = text;
              div.append(time, body);
              output.appendChild(div);
              output.scrollTop = output.scrollHeight;
            }

            function exportLogs() {
              const output = document.getElementById('__cgptwv_console_output');
              if (!output) return;
              const lines = Array.from(output.querySelectorAll('.__cgptwv_entry')).map(el => el.textContent || '').join('\n');
              navigator.clipboard?.writeText(lines).catch(() => {});
              appendConsole({ text: 'Logs copied to clipboard', isError: false });
            }
            window.__cgptwv_exportLogs = exportLogs;

            function renderNetwork() {
              const list = document.getElementById('__cgptwv_network_list');
              if (!list) return;
              const filterInput = document.getElementById('__cgptwv_filter_text');
              const types = {
                fetch: document.getElementById('__cgptwv_filter_fetch')?.checked,
                xhr: document.getElementById('__cgptwv_filter_xhr')?.checked,
                ws: document.getElementById('__cgptwv_filter_ws')?.checked,
              };
              const onlyErrors = document.getElementById('__cgptwv_filter_errors')?.checked;
              const needle = (filterInput?.value || '').toLowerCase();

              list.innerHTML = '';
              networkEntries
                .filter(entry => {
                  if (onlyErrors && entry.ok) return false;
                  if (types[entry.type] === false) return false;
                  if (needle && !(`${entry.method || ''} ${entry.url}`.toLowerCase().includes(needle))) return false;
                  return true;
                })
                .slice(-MAX_NETWORK)
                .forEach(entry => {
                  const item = document.createElement('div');
                  item.className = '__cgptwv_net_item';
                  const header = document.createElement('div');
                  header.className = '__cgptwv_net_meta';

                  const type = document.createElement('span');
                  type.className = `__cgptwv_badge ${entry.type}`;
                  type.textContent = entry.type;
                  const method = document.createElement('span');
                  method.textContent = entry.method || '';
                  const status = document.createElement('span');
                  status.textContent = entry.status ? `status: ${entry.status}` : 'pending';
                  const dur = document.createElement('span');
                  dur.textContent = entry.durationMs != null ? `${entry.durationMs} ms` : '';

                  const url = document.createElement('div');
                  url.className = '__cgptwv_net_url';
                  url.textContent = entry.url;

                  const body = document.createElement('div');
                  body.className = '__cgptwv_net_body';
                  body.textContent = entry.bodyPreview || '';

                  header.append(type, method, status, dur);
                  item.append(header, url);
                  if (entry.bodyPreview) {
                    item.append(body);
                  }
                  list.appendChild(item);
                });
            }

            function truncateBody(str) {
              if (typeof str !== 'string') return str;
              if (str.length > BODY_LIMIT) return str.slice(0, BODY_LIMIT) + '\n...[truncated]';
              return str;
            }

            function logNetwork(entry) {
              networkEntries.push(entry);
              if (networkEntries.length > MAX_NETWORK) networkEntries.shift();
              renderNetwork();
            }

            let hooksEnabled = { fetch: ${hooksDefault}, xhr: ${hooksDefault}, ws: ${hooksDefault} };
            const original = { fetch: window.fetch, xhrOpen: XMLHttpRequest.prototype.open, xhrSend: XMLHttpRequest.prototype.send, ws: window.WebSocket };

            function updateStatusPills() {
              ['fetch','xhr','ws'].forEach(type => {
                const pill = document.getElementById(`__cgptwv_status_${type}`);
                if (!pill) return;
                pill.textContent = `${type.toUpperCase()}: ${hooksEnabled[type] ? 'ON' : 'OFF'}`;
                pill.className = `pill ${hooksEnabled[type] ? 'on' : 'off'}`;
              });
            }

            function toggleHook(type, enabled) {
              hooksEnabled[type] = enabled;
              updateStatusPills();
            }
            window.__cgptwv_toggleHook = toggleHook;

            function setHooksEnabled(all) {
              hooksEnabled = { fetch: all, xhr: all, ws: all };
              updateStatusPills();
            }
            window.__cgptwv_setHooksEnabled = setHooksEnabled;

            function recordRequest(type, meta) {
              logNetwork({ type, ...meta });
            }

            function captureResponseBody(resp) {
              try {
                const clone = resp.clone();
                return clone.text().then(text => truncateBody(text)).catch(() => '[unavailable]');
              } catch (_) {
                return Promise.resolve('[unavailable]');
              }
            }

            window.fetch = function(...args) {
              const start = performance.now();
              const url = (args[0] && args[0].url) || args[0];
              const opts = args[1] || {};
              const method = (opts.method || 'GET').toUpperCase();
              const reqBody = opts.body;

              const shouldLog = hooksEnabled.fetch;
              const maybeBody = typeof reqBody === 'string' ? truncateBody(reqBody) : (reqBody ? '[unavailable]' : '');
              const requestMeta = { type: 'fetch', method, url: String(url), status: null, durationMs: null, bodyPreview: maybeBody, ok: false };

              return original.fetch.apply(this, args).then(resp => {
                if (shouldLog) {
                  return captureResponseBody(resp).then(body => {
                    const durationMs = Math.round(performance.now() - start);
                    recordRequest('fetch', { ...requestMeta, status: resp.status, durationMs, ok: resp.ok, bodyPreview: body });
                    return resp;
                  });
                }
                return resp;
              }).catch(err => {
                if (shouldLog) {
                  const durationMs = Math.round(performance.now() - start);
                  recordRequest('fetch', { ...requestMeta, status: 'error', durationMs, ok: false, bodyPreview: String(err) });
                }
                throw err;
              });
            };

            XMLHttpRequest.prototype.open = function(method, url, ...rest) {
              this.__cgptwv_meta = { method: (method || 'GET').toUpperCase(), url: String(url), start: null };
              return original.xhrOpen.call(this, method, url, ...rest);
            };

            XMLHttpRequest.prototype.send = function(body) {
              const meta = this.__cgptwv_meta || {};
              const shouldLog = hooksEnabled.xhr;
              meta.start = performance.now();
              if (shouldLog) meta.bodyPreview = typeof body === 'string' ? truncateBody(body) : body ? '[unavailable]' : '';

              this.addEventListener('loadend', () => {
                if (!shouldLog) return;
                const durationMs = Math.round(performance.now() - (meta.start || performance.now()));
                recordRequest('xhr', {
                  type: 'xhr',
                  method: meta.method,
                  url: meta.url,
                  status: this.status,
                  durationMs,
                  ok: this.status >= 200 && this.status < 400,
                  bodyPreview: truncateBody(this.responseText || '')
                });
              });

              return original.xhrSend.call(this, body);
            };

            window.WebSocket = function(url, protocols) {
              const ws = protocols ? new original.ws(url, protocols) : new original.ws(url);
              const shouldLog = () => hooksEnabled.ws;
              const meta = { type: 'ws', url: String(url), method: 'WS', status: 'open', ok: true };
              if (shouldLog()) recordRequest('ws', { ...meta, bodyPreview: 'connected' });
              ws.addEventListener('message', (evt) => {
                if (!shouldLog()) return;
                const data = typeof evt.data === 'string' ? truncateBody(evt.data) : '[binary]';
                recordRequest('ws', { ...meta, bodyPreview: `message: ${data}`, status: 'message', ok: true });
              });
              ws.addEventListener('close', (evt) => {
                if (!shouldLog()) return;
                recordRequest('ws', { ...meta, bodyPreview: `closed (${evt.code})`, status: 'closed', ok: evt.code === 1000 });
              });
              ws.addEventListener('error', () => {
                if (!shouldLog()) return;
                recordRequest('ws', { ...meta, bodyPreview: 'error', status: 'error', ok: false });
              });
              const origSend = ws.send;
              ws.send = function(data) {
                if (shouldLog()) {
                  const preview = typeof data === 'string' ? truncateBody(data) : '[binary]';
                  recordRequest('ws', { ...meta, bodyPreview: `send: ${preview}`, status: 'send', ok: true });
                }
                return origSend.call(this, data);
              };
              return ws;
            };

            function runCommand(code) {
              if (!code || !code.trim()) return;
              history.push(code);
              persistHistory();
              appendConsole({ text: `> ${code}`, isError: false });
              (async () => {
                try {
                  const result = await (async () => eval(code))();
                  appendConsole({ text: formatOutput(result), isError: false });
                } catch (err) {
                  const msg = err && err.stack ? err.stack : String(err);
                  appendConsole({ text: msg, isError: true });
                }
              })();
            }

            window.__cgptwv_onEvalResult = function(id, payload) {
              appendConsole({ text: `[Swift eval #${id}] ${formatOutput(payload)}`, isError: false });
            };

            window.__cgptwv_consoleLog = function(level, message) {
              try {
                window.webkit?.messageHandlers?.__cgptwv_consoleBridge?.postMessage({ type: 'log', level, message });
              } catch (_) {}
            };

            function buildUI() {
              createStyle();
              const root = ensureRoot();
              root.innerHTML = '';

              const toggleBtn = document.createElement('button');
              toggleBtn.className = '__cgptwv_toggle_btn';
              toggleBtn.textContent = state.hidden ? 'Show Console' : 'Hide Console';
              toggleBtn.addEventListener('click', () => {
                state.hidden = !state.hidden;
                persistState();
                root.classList.toggle('hidden', !!state.hidden);
                toggleBtn.textContent = state.hidden ? 'Show Console' : 'Hide Console';
              });
              document.body.appendChild(toggleBtn);

              const header = document.createElement('div');
              header.className = '__cgptwv_header';
              const title = document.createElement('div');
              title.className = '__cgptwv_title';
              title.textContent = 'CGPTWV Console';

              const tabs = document.createElement('div');
              tabs.className = '__cgptwv_tabs';
              const tabNames = ['console', 'network'];
              const tabEls = {};
              tabNames.forEach(name => {
                const btn = document.createElement('div');
                btn.className = '__cgptwv_tab';
                btn.textContent = name === 'console' ? 'Console' : 'Network';
                btn.addEventListener('click', () => switchTab(name));
                tabs.appendChild(btn);
                tabEls[name] = btn;
              });

              const actions = document.createElement('div');
              actions.className = '__cgptwv_actions';
              const btnHide = document.createElement('button');
              btnHide.className = '__cgptwv_btn';
              btnHide.textContent = 'Hide';
              btnHide.addEventListener('click', () => {
                state.hidden = true;
                persistState();
                root.classList.add('hidden');
                toggleBtn.textContent = 'Show Console';
              });

              const btnCopy = document.createElement('button');
              btnCopy.className = '__cgptwv_btn';
              btnCopy.textContent = 'Copy';
              btnCopy.addEventListener('click', exportLogs);

              const btnExport = document.createElement('button');
              btnExport.className = '__cgptwv_btn';
              btnExport.textContent = 'Export';
              btnExport.addEventListener('click', exportLogs);

              actions.append(btnHide, btnCopy, btnExport);

              header.append(title, tabs, actions);

              const content = document.createElement('div');
              content.className = '__cgptwv_content';

              const statusRow = document.createElement('div');
              statusRow.className = '__cgptwv_status';
              ['fetch','xhr','ws'].forEach(type => {
                const pill = document.createElement('span');
                pill.id = `__cgptwv_status_${type}`;
                pill.className = 'pill off';
                pill.textContent = `${type.toUpperCase()}: OFF`;
                statusRow.appendChild(pill);
              });

              const consoleContainer = document.createElement('div');
              consoleContainer.id = '__cgptwv_console';
              consoleContainer.style.flex = '1';
              consoleContainer.style.display = 'flex';
              consoleContainer.style.flexDirection = 'column';
              consoleContainer.style.gap = '8px';

              const output = document.createElement('div');
              output.id = '__cgptwv_console_output';
              output.className = '__cgptwv_output';

              const input = document.createElement('textarea');
              input.className = '__cgptwv_input';
              input.id = '__cgptwv_input';
              input.placeholder = 'Enter JS. Enter=run, Shift+Enter=newline';
              let historyIndex = history.length;

              input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  runCommand(input.value);
                  input.value = '';
                  historyIndex = history.length;
                } else if (e.key === 'ArrowUp') {
                  if (historyIndex > 0) {
                    historyIndex -= 1;
                    input.value = history[historyIndex] || '';
                  }
                  e.preventDefault();
                } else if (e.key === 'ArrowDown') {
                  if (historyIndex < history.length - 1) {
                    historyIndex += 1;
                    input.value = history[historyIndex] || '';
                  } else if (historyIndex === history.length - 1) {
                    historyIndex += 1;
                    input.value = '';
                  }
                  e.preventDefault();
                }
              });

              const row = document.createElement('div');
              row.className = '__cgptwv_row';
              const btnRun = document.createElement('button');
              btnRun.className = '__cgptwv_btn';
              btnRun.textContent = 'Run';
              btnRun.addEventListener('click', () => { runCommand(input.value); input.value = ''; });

              const btnClear = document.createElement('button');
              btnClear.className = '__cgptwv_btn';
              btnClear.textContent = 'Clear';
              btnClear.addEventListener('click', () => { output.innerHTML = ''; });

              row.append(btnRun, btnClear);

              consoleContainer.append(statusRow, output, input, row);

              const networkContainer = document.createElement('div');
              networkContainer.id = '__cgptwv_network';
              networkContainer.className = '__cgptwv_network';
              networkContainer.style.display = 'none';

              const filters = document.createElement('div');
              filters.className = '__cgptwv_network_filters';

              const filterText = document.createElement('input');
              filterText.id = '__cgptwv_filter_text';
              filterText.className = '__cgptwv_filter_input';
              filterText.placeholder = 'Filter URL/method';
              filterText.addEventListener('input', renderNetwork);

              const toggles = ['fetch','xhr','ws'].map(type => {
                const wrap = document.createElement('label');
                wrap.className = '__cgptwv_toggle';
                const cb = document.createElement('input');
                cb.type = 'checkbox';
                cb.id = `__cgptwv_filter_${type}`;
                cb.checked = hooksEnabled[type];
                cb.addEventListener('change', () => {
                  toggleHook(type, cb.checked);
                  renderNetwork();
                });
                wrap.append(cb, document.createTextNode(type));
                return wrap;
              });

              const onlyErrors = document.createElement('label');
              onlyErrors.className = '__cgptwv_toggle';
              const errCb = document.createElement('input');
              errCb.type = 'checkbox';
              errCb.id = '__cgptwv_filter_errors';
              errCb.addEventListener('change', renderNetwork);
              onlyErrors.append(errCb, document.createTextNode('only errors'));

              filters.append(filterText, ...toggles, onlyErrors);

              const netList = document.createElement('div');
              netList.id = '__cgptwv_network_list';
              netList.className = '__cgptwv_network_list';

              networkContainer.append(filters, netList);

              content.append(consoleContainer, networkContainer);
              root.append(header, content);

              function switchTab(name) {
                state.tab = name;
                persistState();
                tabNames.forEach(tab => {
                  tabEls[tab].classList.toggle('active', tab === name);
                });
                consoleContainer.style.display = name === 'console' ? 'flex' : 'none';
                networkContainer.style.display = name === 'network' ? 'flex' : 'none';
              }

              switchTab(state.tab || 'console');
              if (state.hidden) root.classList.add('hidden');
              updateStatusPills();
              renderNetwork();
            }

            buildUI();

            const observer = new MutationObserver(() => {
              if (!document.getElementById(ROOT_ID) && document.body) {
                buildUI();
              }
            });
            observer.observe(document.documentElement || document.body, { childList: true, subtree: true });

          } catch (err) {
            console.error('CGPTWV console init failed', err);
          }
        })();
        """
    }
}
