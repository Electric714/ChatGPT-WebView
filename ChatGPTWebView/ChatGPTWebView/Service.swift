import Foundation

struct InjectedJavaScript {
    let documentStart: String?
    let documentEnd: String?
    let didFinish: String?
}

enum Service: CaseIterable {
    case chatgpt
    case gemini
    case grok

    var homeURL: URL {
        switch self {
        case .chatgpt:
            return URL(string: "https://chatgpt.com/")!
        case .gemini:
            return URL(string: "https://gemini.google.com/")!
        case .grok:
            return URL(string: "https://grok.com/")!
        }
    }

    var title: String {
        switch self {
        case .chatgpt:
            return "ChatGPT"
        case .gemini:
            return "Gemini"
        case .grok:
            return "Grok"
        }
    }

    var tabIconSystemName: String {
        switch self {
        case .chatgpt:
            return "sparkles"
        case .gemini:
            return "globe"
        case .grok:
            return "bolt.horizontal.circle"
        }
    }

    var userAgentOverride: String? {
        switch self {
        case .chatgpt:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        case .gemini, .grok:
            return nil
        }
    }

    var injectedJavaScript: InjectedJavaScript? {
        switch self {
        case .chatgpt:
            return InjectedJavaScript(
                documentStart: """
                try {
                  localStorage.setItem('sidebar-expanded-state', 'false');
                  console.log('💥 Injected: sidebar-expanded-state set to false BEFORE hydration');
                } catch (e) {
                  console.log('⚠️ Failed to set sidebar state early:', e);
                }
                """,
                documentEnd: """
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0';
                document.head.appendChild(meta);
                """,
                didFinish: """
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
            )
        case .gemini, .grok:
            return nil
        }
    }

    var zoomDefaultsKey: String {
        switch self {
        case .chatgpt:
            return "zoomScale.chatgpt"
        case .gemini:
            return "zoomScale.gemini"
        case .grok:
            return "zoomScale.grok"
        }
    }

    var websiteDataDomain: String {
        switch self {
        case .chatgpt:
            return "chatgpt.com"
        case .gemini:
            return "gemini.google.com"
        case .grok:
            return "grok.com"
        }
    }
}
