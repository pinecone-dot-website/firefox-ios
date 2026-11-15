// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import WebEngine

/// `Engine` backed by Gecko through Mozilla's iOS `GeckoView` framework.
///
/// Gecko must already be running: the host app's `main.swift` calls `GeckoRuntime.main`.
public final class GeckoEngine: Engine {
    public init() {}

    public func createView() -> EngineView {
        return GeckoEngineView(frame: .zero)
    }

    public func createSession(dependencies: EngineSessionDependencies) throws -> EngineSession {
        return GeckoEngineSession()
    }

    public func warmEngine() {}

    public func idleEngine() {}

    public func clearCaches() {}

    public func clearCookies() {}

    public func clearOfflineWebsiteData() {}

    public func clearTrackingProtection() {}
}
