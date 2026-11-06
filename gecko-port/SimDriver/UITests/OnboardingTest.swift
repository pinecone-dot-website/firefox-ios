// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

/// Fresh launch with no test flags: taps the buttons labelled in `ONBOARD_TAPS` in order,
/// screenshotting before the first tap (`o0.png`) and after each (`o1.png`, …).
/// Environment: `ONBOARD_BUNDLE`, `ONBOARD_TAPS` (space-separated labels), `ONBOARD_DIR`.
final class OnboardingTest: XCTestCase {
    func testOnboardingTap() throws {
        let env = ProcessInfo.processInfo.environment
        guard let bundle = env["ONBOARD_BUNDLE"] else { throw XCTSkip("ONBOARD_BUNDLE not set") }
        let dir = try XCTUnwrap(env["ONBOARD_DIR"])
        let labels = (env["ONBOARD_TAPS"] ?? "Continue Skip").split(separator: " ").map(String.init)
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(8)
        try saveScreenshot(to: dir + "/o0.png")
        for (index, label) in labels.enumerated() {
            print("ONBOARD buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
            let button = app.buttons[label].firstMatch
            guard button.waitForExistence(timeout: 10) else { return XCTFail("no \(label) button") }
            button.tap()
            sleep(5)
            try saveScreenshot(to: dir + "/o\(index + 1).png")
        }
    }
}
