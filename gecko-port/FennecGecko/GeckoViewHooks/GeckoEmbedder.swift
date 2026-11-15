// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

/// Hooks for an app that brings its own `UIApplicationDelegate` instead of Gecko's
/// `AppShellDelegate`. Needs the `ios-gecko-engine` Gecko patch.
public enum GeckoEmbedder {
    /// Call before `GeckoRuntime.main`.
    public static func setAppDelegateClassName(_ name: String) {
        GeckoSetAppDelegateClassName(name)
    }

    public static func applicationWillTerminate() {
        GeckoAppShellWillTerminate()
    }

    public static func applicationDidReceiveMemoryWarning() {
        GeckoAppShellDidReceiveMemoryWarning()
    }
}
