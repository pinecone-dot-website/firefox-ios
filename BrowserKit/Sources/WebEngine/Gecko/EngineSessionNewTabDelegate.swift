// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Optional extra for an `EngineSessionDelegate`: a page asked for a new window
/// (`target=_blank`, `window.open`) and the engine wants the app to open `url` in a new tab
/// instead of handing it a new session.
@MainActor
public protocol EngineSessionNewTabDelegate: AnyObject {
    func onRequestOpenNewTab(url: URL)
}
