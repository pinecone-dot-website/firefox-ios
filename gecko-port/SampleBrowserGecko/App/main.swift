// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import GeckoView
import UIKit

// Gecko owns the process: GeckoRuntime.main runs XRE_main, which calls UIApplicationMain
// with Gecko's own AppShellDelegate. SampleBrowser's app setup hangs off the launch
// notification instead.
let appDelegate = MainActor.assumeIsolated {
    let delegate = AppDelegate()
    AppDelegate.shared = delegate
    return delegate
}
let launchObserver = NotificationCenter.default.addObserver(
    forName: UIApplication.didFinishLaunchingNotification,
    object: nil,
    queue: .main
) { _ in
    MainActor.assumeIsolated {
        appDelegate.applicationDidFinishLaunching()
    }
}

GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
