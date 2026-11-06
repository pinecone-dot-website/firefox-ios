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

## M0: done (2026-11-06)

Both apps build and load a live page in the iOS Simulator on Xcode 27.2. Fennec needed no
source changes. SampleBrowser needed a catch-up fix (below).

- Toolchain: Xcode 27.2 (27B52), Swift 6.4.2 (swiftlang-6.4.2.1.9), iOS Simulator SDK 27.2.
  Simulator: iPhone 18 Pro, iOS 27.0 runtime (24A434), `632AEFF1-AFF8-44B0-A707-1BFD55CCCDEF`.
- Xcode upgrade fallout:
  - Fennec's `ModifiedCopy` macro failed with "Unable to resolve Swift module dependency …
    'SwiftSyntax'" because the build products came from Swift 6.4. Deleting
    `DerivedData/Client-*/Build` (packages kept) fixed it.
  - Simulator.app is missing from this Xcode 27.2 install. It isn't in
    `Contents/Developer/Applications`, and Spotlight can't find it anywhere. The sims run
    headless; screenshots come from `simctl io` or XCUITest.
  - The first `simctl` call after the upgrade ran the first-launch component install itself.
- Build command (from the repo root, scheme `Fennec` / `SampleBrowser`):
  `xcodebuild -project <proj> -scheme <scheme> -destination 'platform=iOS Simulator,id=<udid>' -skipMacroValidation -skipPackagePluginValidation build`
  - Fennec, cold (empty `Build/`, cached packages and compilation cache): 182 s. Built
    for the iOS 26.5 sim, installed on the iOS 27.0 one.
  - SampleBrowser, incremental after the fix: under 10 s.

**SampleBrowser** (commit `e7ce2128e`): updated to the current ToolbarKit API. It now uses the
single `RegularBrowserAddressToolbar`, the `borderConfiguration` it now requires, the new
delegate method, and the `moreHorizontalRound` menu icon. It also gained a
`-SampleBrowserStartURL <url>` launch argument:
`xcrun simctl launch <udid> org.mozilla.ios.SampleBrowser -SampleBrowserStartURL 'https://…'`.
Two cosmetic glitches remain in its address bar: a blank white square left of the URL, and a
clipped icon above the bar. They don't block M2.
Screenshot: `m0-samplebrowser.png`.

**Fennec**: unmodified, loaded through `fennec://open-url?url=…`. iOS 27 shows an "Open in
Fennec?" prompt for every `simctl openurl`, and with no Simulator window nothing can tap it.
That's the reason `SimDriver/` exists: a standalone XCUITest project (xcodegen, not part of any
upstream project) that launches an app, opens a URL, taps the system prompt, and saves a
screenshot. The Fennec run uses the UI-test launch flags (`FIREFOX_TEST`,
`FIREFOX_SKIP_INTRO`, …) to skip onboarding. Usage is in the header of
`SimDriver/UITests/OpenURLTest.swift`; the exact command is below.
Screenshot: `m0-fennec.png`.

```
cd gecko-port/SimDriver && xcodegen generate
TEST_RUNNER_DRIVER_BUNDLE=org.mozilla.ios.Fennec \
TEST_RUNNER_DRIVER_ARGS="FIREFOX_TEST FIREFOX_CLEAR_PROFILE FIREFOX_SKIP_INTRO FIREFOX_SKIP_WHATS_NEW FIREFOX_SKIP_ETP_COVER_SHEET FIREFOX_SKIP_CONTEXTUAL_HINTS FIREFOX_SKIP_TERMS_OF_USE SKIP_DEFAULT_BROWSER_ONBOARDING SKIP_APPLE_INTELLIGENCE DISABLE_ANIMATIONS" \
TEST_RUNNER_DRIVER_URL='fennec://open-url?url=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FGecko_(software)' \
TEST_RUNNER_DRIVER_SHOT=$PWD/../m0-fennec.png \
xcodebuild test -project SimDriver.xcodeproj -scheme SimDriver -destination 'platform=iOS Simulator,id=<udid>'
```

## M1: done (2026-11-06)

Gecko built from source for the iOS Simulator. Mozilla's GeckoTestBrowser renders a live page
with it. No Firefox iOS code was involved, and Gecko itself needed no patches.

- Gecko source: `mozilla-firefox` `main` @ `d9bd6be9a67e`, unmodified.
- Mozconfig: `gecko-port/mozconfig-ios-sim`:
  ```
  ac_add_options --enable-application=mobile/ios
  ac_add_options --target=aarch64-apple-ios-sim
  mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-ios-sim
  ```
  (`aarch64-apple-ios-sim` is already the default on Apple Silicon; it's spelled out so nobody
  has to know that.)
- Toolchain:
  - configure fetched Gecko's own clang etc. into `~/.mozbuild`; no `mach bootstrap` run.
  - Rust: Gecko main requires at least 1.95.0, and the machine default is stable 1.94.1. I
    installed `1.95` side by side (`rustup toolchain install 1.95 --profile minimal --target
    aarch64-apple-ios-sim`) and pinned it to the checkout with `rustup override set 1.95`. The
    default toolchain is unchanged.
- Commands, from `mozilla-firefox/`:
  - `MOZCONFIG=…/gecko-port/mozconfig-ios-sim ./mach --no-interactive configure`, 43 s.
  - `MOZCONFIG=… ./mach --no-interactive build`, **887 s (14 m 47 s)** wall time. It was a clean
    build with 216 compiler warnings and no errors. The Mac swapped heavily (about 50 GB of
    swap-in), and the iPhone simulator shut itself down partway through.
- Output:
  - **Objdir 17 GB.**
  - `dist/bin/XUL` is a 248 MB arm64 Mach-O dylib, alongside the NSS, mozglue, codec and
    lgpllibs dylibs.
  - `dist/include/GeckoView/` holds `GeckoViewSwiftSupport.h` and `IOSBootstrap.h`.
- GeckoTestBrowser, from `mobile/ios/GeckoTestBrowser/`, built in 14 s:
  ```
  xcodebuild -project GeckoTestBrowser.xcodeproj -scheme GeckoTestBrowser \
    -destination 'platform=iOS Simulator,id=632AEFF1-…' \
    CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual \
    GECKO_TOPOBJDIR=…/mozilla-firefox/obj-ios-sim build
  ```
  - Ad-hoc signing replaces Mozilla's team ID.
  - `GECKO_TOPOBJDIR` is set explicitly. Otherwise `GeckoView/AddGecko.sh` asks `mach environment`
    for the objdir, and mach doesn't know our `MOZCONFIG`.
  - The app is 327 MB. It's a BrowserEngineKit host app with Networking, Rendering and
    WebContent `.appex` extensions; Gecko's XUL is embedded via `GeckoView.framework`.
- Run: SimDriver typed `https://en.wikipedia.org/wiki/Gecko_(software)` into the search bar.
  That needed a fix: GeckoTestBrowser's bar is a `UISearchBar`, which XCUITest reports as a
  `searchField`, so `DRIVER_TYPE` now matches text and search fields.
  The page rendered fully: text, links, infobox and logo.
  Screenshot: `m1-geckotestbrowser.png`.
- Observations for M2:
  - GeckoTestBrowser's `UI/RootViewController.swift` is a sibling of SampleBrowser's (same
    `browse(to:)`, same structure), loading through `geckoview.session?.load(_:)`.
  - Its Swift `GeckoView` layer (`GeckoView/*.swift`: `GeckoSession`, `ProgressDelegate`,
    `EventDispatcher`, …) is what `GeckoEngine` will adapt.
