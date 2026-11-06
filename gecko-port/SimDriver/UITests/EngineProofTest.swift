// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

/// The M2/M3 proof run: load a real site, load the engine check page, follow its link,
/// go back. Saves `1-site.png`, `2-engine.png`, `3-followed.png`, `4-back.png`.
///
/// Environment (pass to xcodebuild with a `TEST_RUNNER_` prefix):
/// - `PROOF_BUNDLE`: bundle id of the browser.
/// - `PROOF_ARGS`: space-separated launch arguments.
/// - `PROOF_SITE_URL`: the real site, e.g. a Wikipedia article.
/// - `PROOF_ENGINE_URL`: `gecko-port/proof/engine.html` as served to the simulator.
/// - `PROOF_LINK_TAP`: where the engine page's link is, as fractions of the screen, e.g. `0.5,0.62`.
/// - `PROOF_BACK_ID`: accessibility identifier of the app's Back button (default `backButton`).
/// - `PROOF_DIR`: folder for the screenshots.
/// - `PROOF_APP_ENV`: optional `KEY=VALUE` pairs (space-separated) for the app's environment.
final class EngineProofTest: XCTestCase {
    func testEngineProof() throws {
        let env = ProcessInfo.processInfo.environment
        guard let bundle = env["PROOF_BUNDLE"] else { throw XCTSkip("PROOF_BUNDLE not set") }
        let site = try XCTUnwrap(env["PROOF_SITE_URL"])
        let engine = try XCTUnwrap(env["PROOF_ENGINE_URL"])
        let dir = try XCTUnwrap(env["PROOF_DIR"])
        func shot(_ name: String) throws { try saveScreenshot(to: dir + "/" + name) }

        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = env["PROOF_ARGS"]?.split(separator: " ").map(String.init) ?? []
        for pair in env["PROOF_APP_ENV"]?.split(separator: " ") ?? [] {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { app.launchEnvironment[parts[0]] = parts[1] }
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(3)

        app.typeIntoFirstField(site)
        sleep(15)
        try shot("1-site.png")

        app.typeIntoFirstField(engine)
        sleep(6)
        try shot("2-engine.png")

        guard let linkTap = env["PROOF_LINK_TAP"], !linkTap.isEmpty else { return }
        app.tap(normalized: linkTap)
        sleep(5)
        try shot("3-followed.png")

        let back = app.buttons[env["PROOF_BACK_ID"] ?? "backButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "no Back button")
        back.tap()
        sleep(5)
        try shot("4-back.png")
    }
}
