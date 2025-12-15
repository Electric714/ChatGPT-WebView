# ChatGPT WebView for iOS 16

A lightweight iOS WebView wrapper for ChatGPT’s web app. Built with Swift and WKWebView, optimized for fast performance and speech-to-text microphone support on iOS 16.

## Features
- Persistent login
- Safari 16+ User-Agent spoofing
- Mic input (speech-to-text)
- Dark mode support
- TrollStore compatibility
- Manual or Xcode install

## Build Requirements
- Xcode 14+
- Target iOS 15-16
- Swift 5.0+

## Installation
1. Open this project in Xcode
2. Choose your device or simulator
3. Hit “Run” to build

## GitHub Actions (unsigned IPA)
An automated workflow builds an unsigned IPA on macOS runners:
- Workflow file: `.github/workflows/unsigned-ipa.yml`
- Project path: `ChatGPTWebView/ChatGPTWebView.xcodeproj`
- Triggers: pushes to `main` or manual `workflow_dispatch`
- Output: `ChatGPTWebView-unsigned.ipa` artifact attached to the run

To keep the repository free of binary assets, app icons are generated during the workflow
run via `scripts/generate_app_icons.py`. For local builds, run the script once using a
virtual environment and a PEP 668-safe install (Python 3.11+ recommended):

```bash
python3 -m venv .venv --upgrade-deps
PIP_BREAK_SYSTEM_PACKAGES=1 .venv/bin/python -m pip install pillow
.venv/bin/python scripts/generate_app_icons.py
```

The Xcode project uses **manual code signing with an empty Development Team** to avoid
needing any certificates. The workflow also passes `CODE_SIGNING_ALLOWED=NO`, so the
build succeeds on GitHub-hosted runners without provisioning profiles.

## License
MIT
