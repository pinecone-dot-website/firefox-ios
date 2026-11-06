// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import GeckoView
import WebEngine

// Entry points Fennec calls by symbol name, so Client never imports the GeckoEngine or
// GeckoView modules. The matching declarations are in Client/Gecko/GeckoBridge.swift.

@_silgen_name("fxios_gecko_run")
public func fxiosGeckoRun(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>,
    _ appDelegateClassName: String
) {
    GeckoEmbedder.setAppDelegateClassName(appDelegateClassName)
    GeckoRuntime.main(argc: argc, argv: argv)
}

@_silgen_name("fxios_gecko_make_engine")
public func fxiosGeckoMakeEngine() -> AnyObject {
    MainActor.assumeIsolated { GeckoEngine() }
}

@_silgen_name("fxios_gecko_make_session")
public func fxiosGeckoMakeSession() -> AnyObject {
    MainActor.assumeIsolated { GeckoEngineSession() }
}

@_silgen_name("fxios_gecko_will_terminate")
public func fxiosGeckoWillTerminate() {
    GeckoEmbedder.applicationWillTerminate()
}

@_silgen_name("fxios_gecko_memory_warning")
public func fxiosGeckoMemoryWarning() {
    GeckoEmbedder.applicationDidReceiveMemoryWarning()
}
