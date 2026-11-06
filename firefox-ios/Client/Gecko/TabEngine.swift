// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

#if GECKO_ENGINE
import Shared
import UIKit
import WebEngine

/// Page changes a Gecko-backed tab reports. Mirrors the `WKWebView` KVO keys BVC observes.
enum TabEngineEvent {
    case url(URL)
    case title
    case loading(Bool)
    case progress(Double)
    case canGoBack(Bool)
    case canGoForward(Bool)
}

/// The Gecko half of a `Tab`: its engine session, the view rendering it, and the page state
/// `Tab` reports in place of its dormant `WKWebView`.
@MainActor
final class TabEngine {
    let session: EngineSession
    let view: EngineView

    private(set) var url: URL?
    private(set) var title: String?
    private(set) var isLoading = false
    private(set) var estimatedProgress: Double = 0
    private(set) var canGoBack = false
    private(set) var canGoForward = false

    var onEvent: ((TabEngineEvent) -> Void)?
    var onOpenNewTab: ((URL) -> Void)?

    init(session: EngineSession, view: EngineView) {
        self.session = session
        self.view = view
        session.delegate = self
        view.render(session: session)
    }

    static func make() -> TabEngine {
        return TabEngine(session: GeckoBridge.makeSession(), view: GeckoBridge.engine.createView())
    }

    /// Loads `url` in Gecko. Internal pages (homepage, error pages) aren't Gecko's: they are only
    /// reported back as the tab's location, so the browser shows its native UI for them.
    func load(_ url: URL) {
        if InternalURL(url) != nil {
            report(url: url)
            return
        }
        let context = BrowsingContext(type: .internalNavigation, url: url)
        guard let browserURL = BrowserURL(browsingContext: context) else { return }
        session.load(browserURL: browserURL)
    }

    func close() {
        session.close()
        view.removeFromSuperview()
    }

    private func report(url: URL) {
        self.url = url
        onEvent?(.url(url))
    }
}

extension TabEngine: @preconcurrency EngineSessionDelegate {
    func onTitleChange(title: String) {
        self.title = title
        onEvent?(.title)
    }

    func onLocationChange(url: String) {
        // A new Gecko window reports about:blank before its first real load.
        guard url != "about:blank", let url = URL(string: url) else { return }
        report(url: url)
    }

    func onHasOnlySecureContentChanged(secure: Bool) {}

    func onProgress(progress: Double) {
        estimatedProgress = progress
        onEvent?(.progress(progress))
    }

    func onHideProgressBar() {}

    func onNavigationStateChange(canGoBack: Bool, canGoForward: Bool) {
        if canGoBack != self.canGoBack {
            self.canGoBack = canGoBack
            onEvent?(.canGoBack(canGoBack))
        }
        if canGoForward != self.canGoForward {
            self.canGoForward = canGoForward
            onEvent?(.canGoForward(canGoForward))
        }
    }

    func onLoadingStateChange(loading: Bool) {
        isLoading = loading
        if loading {
            estimatedProgress = 0
        }
        onEvent?(.loading(loading))
    }

    func didLoad(pageMetadata: EnginePageMetadata) {}

    func onErrorPageRequest(error: NSError) {}

    func findInPage(with selection: String) {}

    func search(with selection: String) {}

    func onProvideContextualMenu(linkURL: URL?) -> UIContextMenuConfiguration? {
        return nil
    }

    func onWillDisplayAccessoryView() -> EngineInputAccessoryView {
        return .default
    }

    func adsSearchProviderModels() -> [EngineSearchProviderModel] {
        return []
    }

    func requestMediaCapturePermission() -> Bool {
        return false
    }

    func onRequestOpenNewSession(_ session: EngineSession) {}
}

extension TabEngine: EngineSessionNewTabDelegate {
    func onRequestOpenNewTab(url: URL) {
        onOpenNewTab?(url)
    }
}
#endif
