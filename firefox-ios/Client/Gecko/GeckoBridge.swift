// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

#if GECKO_ENGINE
import Foundation
import WebEngine

// Implemented in gecko-port/FennecGecko/Bridge/FennecGeckoBridge.swift, linked in from
// libGeckoEngine.a. Client calls them by symbol so it never imports the Gecko modules.
@_silgen_name("fxios_gecko_run")
private func fxiosGeckoRun(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>,
    _ appDelegateClassName: String
)

@_silgen_name("fxios_gecko_make_engine")
private func fxiosGeckoMakeEngine() -> AnyObject

@_silgen_name("fxios_gecko_make_session")
private func fxiosGeckoMakeSession() -> AnyObject

@_silgen_name("fxios_gecko_will_terminate")
private func fxiosGeckoWillTerminate()

@_silgen_name("fxios_gecko_memory_warning")
private func fxiosGeckoMemoryWarning()

/// Fennec's way into the Gecko engine (`GECKO_ENGINE` builds only).
enum GeckoBridge {
    /// Starts Gecko, which runs `UIApplicationMain` with `appDelegateClassName`. Never returns.
    static func run(appDelegateClassName: String) -> Never {
        fxiosGeckoRun(CommandLine.argc, CommandLine.unsafeArgv, appDelegateClassName)
        fatalError("Gecko's UIApplicationMain returned")
    }

    @MainActor
    static let engine: Engine = {
        guard let engine = fxiosGeckoMakeEngine() as? Engine else {
            fatalError("GeckoEngine does not conform to WebEngine.Engine")
        }
        return engine
    }()

    @MainActor
    static func makeSession() -> EngineSession {
        guard let session = fxiosGeckoMakeSession() as? EngineSession else {
            fatalError("GeckoEngineSession does not conform to WebEngine.EngineSession")
        }
        return session
    }

    static func applicationWillTerminate() {
        fxiosGeckoWillTerminate()
    }

    static func applicationDidReceiveMemoryWarning() {
        fxiosGeckoMemoryWarning()
    }
}
#endif
