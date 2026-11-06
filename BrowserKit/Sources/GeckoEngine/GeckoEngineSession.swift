// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import GeckoView
import UIKit
import WebEngine

struct GeckoHistoryItem: EngineSessionBackForwardListItem {
    let url: URL
    let title: String?
}

/// `EngineSession` wrapping one `GeckoSession`.
///
/// Gecko's iOS embedding doesn't expose the back/forward list, find in page, zoom or
/// tracking protection yet, so those requirements are no-ops for now.
final class GeckoEngineSession: NSObject, EngineSession {
    weak var delegate: EngineSessionDelegate?
    nonisolated(unsafe) weak var telemetryProxy: EngineTelemetryProxy?

    let geckoSession: GeckoSession
    private var currentURL: URL?
    private var currentTitle: String?
    private var canGoBack = false
    private var canGoForward = false
    /// Gecko drops loads sent before a freshly opened window reports its first location,
    /// so earlier loads wait here.
    private var isWindowReady = false
    private var pendingLoad: String?

    /// Schemes Gecko loads itself. Anything else goes to `UIApplication.open`.
    static let webSchemes: Set<String> = ["http", "https", "about", "data", "blob", "file"]

    var isActive = false {
        didSet {
            guard isActive != oldValue, geckoSession.isOpen() else { return }
            geckoSession.setActive(isActive)
        }
    }

    init(geckoSession: GeckoSession = GeckoSession()) {
        self.geckoSession = geckoSession
        super.init()
        geckoSession.contentDelegate = self
        geckoSession.navigationDelegate = self
        geckoSession.progressDelegate = self
        geckoSession.open()
    }

    func load(browserURL: BrowserURL) {
        let url = browserURL.engineURL.absoluteString
        guard isWindowReady else {
            pendingLoad = url
            return
        }
        geckoSession.load(url)
    }

    func stopLoading() {
        geckoSession.stop()
    }

    func reload(bypassCache: Bool) {
        geckoSession.reload()
    }

    func goBack() {
        geckoSession.goBack()
    }

    func goForward() {
        geckoSession.goForward()
    }

    func scrollToTop() {}

    func showFindInPage(withSearchText searchText: String?) {}

    func goToHistory(item: EngineSessionBackForwardListItem) {}

    func currentHistoryItem() -> EngineSessionBackForwardListItem? {
        guard let currentURL else { return nil }
        return GeckoHistoryItem(url: currentURL, title: currentTitle)
    }

    func getBackListItems() -> [EngineSessionBackForwardListItem] {
        return []
    }

    func getForwardListItems() -> [EngineSessionBackForwardListItem] {
        return []
    }

    func restore(state: Data) {}

    func close() {
        geckoSession.contentDelegate = nil
        geckoSession.navigationDelegate = nil
        geckoSession.progressDelegate = nil
        geckoSession.close()
    }

    func switchToStandardTrackingProtection() {}

    func switchToStrictTrackingProtection() {}

    func disableTrackingProtection() {}

    func toggleNoImageMode() {}

    func updatePageZoom(_ change: ZoomChangeValue) {}
}

extension GeckoEngineSession: NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {
        if !isWindowReady {
            isWindowReady = true
            if let pendingLoad {
                self.pendingLoad = nil
                geckoSession.load(pendingLoad)
                return
            }
        }
        guard let url else { return }
        currentURL = URL(string: url)
        delegate?.onLocationChange(url: url)
    }

    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        self.canGoBack = canGoBack
        delegate?.onNavigationStateChange(canGoBack: canGoBack, canGoForward: canGoForward)
    }

    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        self.canGoForward = canGoForward
        delegate?.onNavigationStateChange(canGoBack: canGoBack, canGoForward: canGoForward)
    }

    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        guard let url = URL(string: request.uri) else { return .deny }
        guard GeckoEngineSession.webSchemes.contains(url.scheme?.lowercased() ?? "") else {
            if request.hasUserGesture {
                await UIApplication.shared.open(url)
            }
            return .deny
        }
        if request.target == .new, let newTabDelegate = delegate as? EngineSessionNewTabDelegate {
            newTabDelegate.onRequestOpenNewTab(url: url)
            return .deny
        }
        return .allow
    }

    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        return .allow
    }

    // Gecko's iOS handler can't accept a returned session yet (it asserts the session is
    // open, then opens it again), so new windows go through onLoadRequest's new-tab path.
    func onNewSession(session: GeckoSession, uri: String) async -> GeckoSession? {
        return nil
    }
}

extension GeckoEngineSession: ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {
        delegate?.onLoadingStateChange(loading: true)
    }

    func onPageStop(session: GeckoSession, success: Bool) {
        delegate?.onLoadingStateChange(loading: false)
    }

    func onProgressChange(session: GeckoSession, progress: Int) {
        delegate?.onProgress(progress: Double(progress) / 100)
    }
}

extension GeckoEngineSession: ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String) {
        currentTitle = title
        delegate?.onTitleChange(title: title)
    }

    func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}

    func onFocusRequest(session: GeckoSession) {}

    func onCloseRequest(session: GeckoSession) {}

    func onFullScreen(session: GeckoSession, fullScreen: Bool) {}

    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}

    func onProductUrl(session: GeckoSession) {}

    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}

    func onCrash(session: GeckoSession) {}

    func onKill(session: GeckoSession) {}

    func onFirstComposite(session: GeckoSession) {}

    func onFirstContentfulPaint(session: GeckoSession) {}

    func onPaintStatusReset(session: GeckoSession) {}

    func onWebAppManifest(session: GeckoSession, manifest: Any) {}

    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse {
        return .resume
    }

    func onShowDynamicToolbar(session: GeckoSession) {}
}
