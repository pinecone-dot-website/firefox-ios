// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit

/// Stands in for `SampleBrowser/Dependency/DependencyHelper.swift` in the Gecko build:
/// finds the app delegate through `AppDelegate.shared` instead of `UIApplication.shared.delegate`.
@MainActor
class DependencyHelper {
    func bootstrapDependencies() {
        guard let appDelegate = AppDelegate.shared else {
            fatalError("Failed to register any dependencies")
        }

        let themeManager: ThemeManager = appDelegate.themeManager
        AppContainer.shared.register(service: themeManager)

        AppContainer.shared.bootstrap()
    }

    func reset() {
        AppContainer.shared.reset()
    }

    static var baseBundleIdentifier: String {
        let bundle = Bundle.main
        let packageType = bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String
        let baseBundleIdentifier = bundle.bundleIdentifier!
        if packageType == "XPC!" {
            let components = baseBundleIdentifier.components(separatedBy: ".")
            return components[0 ..< components.count - 1].joined(separator: ".")
        }
        return baseBundleIdentifier
    }
}
