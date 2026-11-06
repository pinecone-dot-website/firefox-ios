// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest
import WebEngine

final class BrowserURLExternalEngineTests: XCTestCase {
    func testEngineURLGivenExampleURLThenMatchesContextURL() throws {
        let url = URL(string: "https://www.example.com/path?query=1")!
        let context = BrowsingContext(type: .internalNavigation, url: url)
        let subject = try XCTUnwrap(BrowserURL(browsingContext: context))

        XCTAssertEqual(subject.engineURL, url)
    }
}
