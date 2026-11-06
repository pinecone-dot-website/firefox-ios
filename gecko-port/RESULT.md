# Firefox iOS on Gecko: Results

Verified evidence per milestone, newest at the bottom. Each entry: date, what was
built, exact commands, what worked, what didn't, screenshots (saved in this
folder). See `PLAN.md` for the milestone definitions.

## Setup (2026-11-06)

- Forked `mozilla-mobile/firefox-ios` to `eaglstun/firefox-ios`, cloned blobless to
  `~/Documents/dev/firefox-ios`, branch `gecko-engine`, remote `upstream` added.
- Cloned Gecko source (`mozilla-firefox/firefox`, blobless) to
  `~/Documents/dev/mozilla-firefox`, and `minh-ton/reynard-browser` to
  `~/Documents/dev/reynard-browser` for reference.
- Toolchain at setup: Xcode 27.0 (27A266a); upstream README asks for 27.1.
  xcodegen is installed; upstream's `fxios` CLI is not.
- Nothing built yet.

## M0 attempt 1: blocked (2026-11-06)

Neither app builds unmodified with Xcode 27.0. Stopped here per PLAN.md.

- Toolchain: Xcode 27.0 (27A266a), Swift 6.4 (swiftlang-6.4.0.34.1), iOS Simulator SDK 27.0.
  Simulator: iPhone 17 Pro (80EE4CC0-6644-43B1-AB10-393347B3A114).
- Bootstrap: `sh ./bootstrap.sh` succeeded in 16 s and left the tree clean.
  (`fxios` was not installed; the bootstrap skill wants it from a brew tap. Skipped, because it's a new system tool.)
- Build command (both apps, run from the repo root):
  `xcodebuild -project <proj> -scheme <scheme> -destination 'platform=iOS Simulator,id=80EE4CC0-…' -skipMacroValidation -skipPackagePluginValidation build`

**Fennec** (`firefox-ios/Client.xcodeproj`, scheme `Fennec`): failed after 172 s.
The iPhone Duo code uses iOS 27.1 SDK symbols (`UIVerticalBarBehavior`,
`UITraitCollection.verticalBarEdge`, `systemTraitsAffectingVerticalBarEdge`) inside
`#if compiler(>=6.4)` plus `@available(iOS 27.1, *)`. Xcode 27.0 already ships Swift 6.4,
so the compiler gate passes, but the 27.0 SDK doesn't have the symbols. 6 Swift files reference them
(the errors were in `BrowserViewController.swift` and `RustFxA/FxAWebViewController.swift`).
This is the Xcode 27.1 requirement.

**SampleBrowser** (`SampleBrowser/SampleBrowser.xcodeproj`, scheme `SampleBrowser`): failed after 46 s.
This failure is unrelated to the Xcode version. SampleBrowser has fallen behind BrowserKit's ToolbarKit:
`AddressToolbarState` now takes `borderConfiguration:` instead of `borderPosition:`,
`CompactBrowserAddressToolbar` no longer exists, and `RootViewController` no longer
satisfies `AddressToolbarDelegate`. It needs source fixes on any Xcode version.
