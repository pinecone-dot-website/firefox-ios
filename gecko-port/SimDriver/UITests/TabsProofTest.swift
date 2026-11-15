// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

/// The M3 tab checks in Fennec: two tabs keep their own pages, switching between them works,
/// closing one works, and tabs come back after a relaunch. Saves `t1-second-tab.png`,
/// `t2-tray.png`, `t3-first-tab.png`, `t4-closed.png`, `t5-relaunch.png`,
/// `t6-relaunch-tray.png`.
///
/// Environment (pass to xcodebuild with a `TEST_RUNNER_` prefix):
/// - `TABS_ARGS`: launch arguments for the first launch (space-separated).
/// - `TABS_RELAUNCH_ARGS`: launch arguments for the relaunch (no profile clearing).
/// - `TABS_URL_1`, `TABS_URL_2`: pages for the two tabs, typed into the address bar.
/// - `TABS_DIR`: folder for the screenshots.
final class TabsProofTest: XCTestCase {
    private enum ID {
        static let newTab = "TabToolbar.addNewTabButton"
        static let tabs = "TabToolbar.tabsButton"
        static let cell = "TabDisplayView.tabCell"
        static let close = "tabCloseButton"
        static let done = "doneButtonTabTray"
    }

    func testTabs() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["TABS_URL_1"] != nil else { throw XCTSkip("TABS_URL_1 not set") }
        let first = try XCTUnwrap(env["TABS_URL_1"])
        let second = try XCTUnwrap(env["TABS_URL_2"])
        let dir = try XCTUnwrap(env["TABS_DIR"])
        let app = XCUIApplication(bundleIdentifier: "org.mozilla.ios.Fennec")
        func shot(_ name: String) throws { try saveScreenshot(to: dir + "/" + name) }
        func element(_ id: String) -> XCUIElement {
            app.descendants(matching: .any)[id].firstMatch
        }
        func tap(_ id: String) {
            let target = element(id)
            XCTAssertTrue(target.waitForExistence(timeout: 10), "no \(id)")
            target.tap()
        }

        app.launchArguments = env["TABS_ARGS"]?.split(separator: " ").map(String.init) ?? []
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(3)

        app.typeIntoFirstField(first)
        sleep(6)
        tap(ID.newTab)
        sleep(2)
        app.typeIntoFirstField(second)
        sleep(6)
        try shot("t1-second-tab.png")

        tap(ID.tabs)
        sleep(2)
        try shot("t2-tray.png")
        tap("\(ID.cell)_0_0")
        sleep(4)
        try shot("t3-first-tab.png")

        tap(ID.tabs)
        sleep(2)
        let secondCell = element("\(ID.cell)_0_1")
        XCTAssertTrue(secondCell.waitForExistence(timeout: 10), "no second tab cell")
        secondCell.descendants(matching: .button)[ID.close].firstMatch.tap()
        sleep(2)
        try shot("t4-closed.png")
        tap(ID.done)
        sleep(2)

        // Background first, as a user's swipe-away would: Fennec saves its tabs then, and
        // terminate() alone kills it before the save.
        XCUIDevice.shared.press(.home)
        sleep(5)
        app.terminate()
        app.launchArguments = env["TABS_RELAUNCH_ARGS"]?.split(separator: " ").map(String.init) ?? []
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(10)
        try shot("t5-relaunch.png")
        tap(ID.tabs)
        sleep(2)
        try shot("t6-relaunch-tray.png")
    }
}
