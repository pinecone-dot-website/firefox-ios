// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

/// Opens a URL in another app on the simulator and saves a screenshot.
///
/// Environment (pass to xcodebuild with a `TEST_RUNNER_` prefix):
/// - `DRIVER_BUNDLE`: bundle id of the app to drive.
/// - `DRIVER_ARGS`: space-separated launch arguments for that app.
/// - `DRIVER_URL`: URL handed to the system, e.g. `fennec://open-url?url=...`.
/// - `DRIVER_TYPE`: text typed into the app's first text or search field, followed by Return.
///   Use this instead of `DRIVER_URL` for apps without a URL scheme.
/// - `DRIVER_SHOT`: absolute path for the PNG screenshot.
/// - `DRIVER_WAIT`: seconds to wait for the page before the screenshot (default 10).
final class OpenURLTest: XCTestCase {
    func testOpenURL() throws {
        let env = ProcessInfo.processInfo.environment
        guard let bundle = env["DRIVER_BUNDLE"] else { throw XCTSkip("DRIVER_BUNDLE not set") }
        let wait = env["DRIVER_WAIT"].flatMap(Double.init) ?? 10

        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = env["DRIVER_ARGS"]?.split(separator: " ").map(String.init) ?? []
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(3)

        let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if let url = env["DRIVER_URL"].flatMap(URL.init(string:)) {
            XCUIDevice.shared.system.open(url)
            var timeout: TimeInterval = 5
            for _ in 0..<5 where open.waitForExistence(timeout: timeout) {
                open.tap()
                timeout = 2
            }
        } else if let text = env["DRIVER_TYPE"] {
            app.typeIntoFirstField(text)
        } else {
            XCTFail("set DRIVER_URL or DRIVER_TYPE")
        }

        Thread.sleep(forTimeInterval: wait)
        while open.exists {
            open.tap()
            sleep(1)
        }
        try saveScreenshot(to: env["DRIVER_SHOT"])
    }
}
