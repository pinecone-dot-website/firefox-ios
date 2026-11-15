// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit
import WebEngine

/// Stands in for `SampleBrowser/AppDelegate.swift` in the Gecko build, where Gecko's
/// `AppShellDelegate` is the real application delegate. Same members, no `@main`.
@MainActor
class AppDelegate: NSObject, Notifiable {
    static var shared: AppDelegate?

    var notificationCenter: NotificationProtocol = NotificationCenter.default
    lazy var themeManager: ThemeManager = DefaultThemeManager(
        sharedContainerIdentifier: DependencyHelper.baseBundleIdentifier
    )
    lazy var engineDependencyManager = EngineDependencyManager()
    var engineProvider: EngineProvider?

    func applicationDidFinishLaunching() {
        Task {
            self.engineProvider = await EngineProviderManager.shared.getProvider()
            engineProvider?.warmEngine()
        }
        DependencyHelper().bootstrapDependencies()
        AppLaunchUtil().setUpPreLaunchDependencies()
        startObservingNotifications(withNotificationCenter: notificationCenter,
                                    forObserver: self,
                                    observing: [UIApplication.didBecomeActiveNotification,
                                                UIApplication.didEnterBackgroundNotification])
    }

    nonisolated func handleNotifications(_ notification: Notification) {
        let name = notification.name
        Task { @MainActor in
            switch name {
            case UIApplication.didBecomeActiveNotification:
                engineProvider?.warmEngine()
            case UIApplication.didEnterBackgroundNotification:
                engineProvider?.idleEngine()
            default: break
            }
        }
    }
}
