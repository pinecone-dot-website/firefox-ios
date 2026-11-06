import XCTest

/// Opens a URL in another app on the simulator and saves a screenshot.
///
/// Environment (pass to xcodebuild with a `TEST_RUNNER_` prefix):
/// - `DRIVER_BUNDLE`: bundle id of the app to drive.
/// - `DRIVER_ARGS`: space-separated launch arguments for that app.
/// - `DRIVER_URL`: URL handed to the system, e.g. `fennec://open-url?url=...`.
/// - `DRIVER_SHOT`: absolute path for the PNG screenshot.
/// - `DRIVER_WAIT`: seconds to wait for the page before the screenshot (default 10).
final class OpenURLTest: XCTestCase {
    func testOpenURL() throws {
        let env = ProcessInfo.processInfo.environment
        let bundle = try XCTUnwrap(env["DRIVER_BUNDLE"])
        let url = try XCTUnwrap(env["DRIVER_URL"].flatMap(URL.init(string:)))
        let wait = env["DRIVER_WAIT"].flatMap(Double.init) ?? 10

        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = env["DRIVER_ARGS"]?.split(separator: " ").map(String.init) ?? []
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(3)

        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["Open"]
        var timeout: TimeInterval = 5
        for _ in 0..<5 where open.waitForExistence(timeout: timeout) {
            open.tap()
            timeout = 2
        }

        Thread.sleep(forTimeInterval: wait)
        while open.exists {
            open.tap()
            sleep(1)
        }
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let path = env["DRIVER_SHOT"] {
            try png.write(to: URL(fileURLWithPath: path))
        }
    }
}
