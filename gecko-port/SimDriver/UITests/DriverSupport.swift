// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

extension XCUIApplication {
    /// Replaces the contents of the first text or search field with `text` and presses Return.
    func typeIntoFirstField(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@", [
                XCUIElement.ElementType.textField.rawValue,
                XCUIElement.ElementType.searchField.rawValue,
            ])
        ).firstMatch
        XCTAssertTrue(
            field.waitForExistence(timeout: 15),
            "no text or search field to type into",
            file: file,
            line: line
        )
        field.tap()
        let existing = (field.value as? String) ?? ""
        let placeholder = field.placeholderValue ?? ""
        if !existing.isEmpty, existing != placeholder {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text + "\n")
    }

    /// Taps a point given as fractions of the app's frame, e.g. `"0.5,0.6"`.
    func tap(normalized spec: String) {
        let parts = spec.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return XCTFail("bad coordinate \(spec)") }
        coordinate(withNormalizedOffset: CGVector(dx: parts[0], dy: parts[1])).tap()
    }
}

func saveScreenshot(to path: String?) throws {
    guard let path else { return }
    try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
}
