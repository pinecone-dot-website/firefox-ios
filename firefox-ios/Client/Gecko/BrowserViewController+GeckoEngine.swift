// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

#if GECKO_ENGINE
import Foundation
import Shared

extension BrowserViewController {
    func observeEngine(of tab: Tab) {
        tab.engine?.onEvent = { [weak self, weak tab] event in
            guard let self, let tab else { return }
            self.handleEngineEvent(event, tab: tab)
        }
        tab.engine?.onOpenNewTab = { [weak self, weak tab] url in
            guard let self, let tab else { return }
            self.addTab(rURL: url, isPrivate: false, currentTab: tab)
        }
    }

    /// The parts of `webView(_:didCommit:)` that don't depend on WebKit scripts. Gecko reports a
    /// location on commit and on same-document changes, so both land here.
    func handleEngineLocationChange(url: URL, tab: Tab) {
        tab.url = url
        navigateInTab(tab: tab, webViewStatus: .url)
        guard tab === tabManager.selectedTab else { return }
        updateUIForReaderHomeStateForTab(tab, focusUrlBar: true)
        updateInContentHomePanel(tab.url, focusUrlBar: true)
    }

    /// The parts of `webView(_:didFinish:)` that don't depend on WebKit.
    func handleEngineLoadFinished(tab: Tab) {
        guard let url = tab.url, InternalURL(url) == nil else { return }
        if let title = tab.title, tab === tabManager.selectedTab {
            tab.lastTitle = title
            tabManager.notifyCurrentTabDidFinishLoading()
        }
        tabManager.commitChanges()
        navigateInTab(tab: tab, webViewStatus: .finishedNavigation)
    }
}
#endif
