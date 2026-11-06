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

## M2: done (2026-11-06)

SampleBrowser runs on Gecko through the `WebEngine` protocols. It loads Wikipedia, follows a
link and goes back. The proof page reports Gecko; the same page in stock SampleBrowser
reports WebKit. Code: commit `9dfff0af7`.

**Proof** (simulator: iPhone 18 Pro, iOS 27.0; run by `SimDriver` `EngineProofTest`):

| Step | Gecko build | Screenshot |
| --- | --- | --- |
| Load `https://en.wikipedia.org/wiki/Gecko_(software)` | renders fully | `m2-gecko-1-site.png` |
| Load `gecko-port/proof/engine.html` | **GECKO**; `CSS.supports("-moz-appearance","none")` = `true`; UA `Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X; rv:162.0) Gecko/162.0 Firefox/162.0` | `m2-gecko-2-engine.png` |
| Tap "Follow this link" | "Second page"; the server logged `GET /second.html` | `m2-gecko-3-followed.png` |
| Native Back button | back on the engine page; Forward becomes enabled | `m2-gecko-4-back.png` |
| Control: stock SampleBrowser, same page | **NOT GECKO**; `CSS.supports` = `false`; UA `AppleWebKit/605.1.15` | `m2-webkit-2-engine.png` |

**Code layout:**
- `BrowserKit/Sources/GeckoEngine/`: `GeckoEngine`, `GeckoEngineSession`, `GeckoEngineView`.
  - This folder is not a SwiftPM target. It's compiled as a static library by the Gecko project
    below, because it needs `GeckoView`, which only exists after a Gecko build.
  - It has to be its own module. SampleBrowser declares its own `NavigationDelegate` protocol,
    which shadows GeckoView's inside the app module. And `GeckoView.NavigationDelegate` can't
    be written out in full, because `GeckoView` resolves to the class, not the module.
- `gecko-port/SampleBrowserGecko/project.yml` (xcodegen) builds:
  - **SampleBrowserGecko** (`org.eaglstun.geckoport.SampleBrowserGecko`): SampleBrowser's own
    sources with `GECKO_ENGINE` set. `App/` replaces the two files that assume UIKit owns
    launch.
  - **GeckoEngine**, the static library.
  - **GeckoView.framework**, compiled from Gecko's `mobile/ios/GeckoTestBrowser/GeckoView/` by
    path, with `AddGecko.sh` copying `XUL` and the dylibs out of the objdir.
  - **WebContent, Networking, Rendering** ExtensionKit extensions, compiled from Gecko's sources by
    path, with our own entitlements and bundle IDs.
- Upstream edits:
  - `SampleBrowser/…/EngineProvider.swift`: +7 lines, `#if GECKO_ENGINE`.
  - New file `WebEngine/Gecko/BrowserURL+ExternalEngine.swift`, a public `engineURL`, because
    `BrowserURL.url` is internal. It has a new test, `BrowserURLExternalEngineTests`, which
    passes.
- Unchanged and verified after M2: `SampleBrowser.xcodeproj` builds on WebKit (the control
  run above), and Fennec builds (135 s).
- SwiftLint 0.65.0 (pinned) is clean on all new and changed files.

**Findings:**
- **Gecko owns the process.**
  - `GeckoRuntime.main` runs `XRE_main`, which calls `UIApplicationMain(…, @"AppShellDelegate")`,
    so the app's own `AppDelegate` never becomes the delegate. Scenes still come from
    Info.plist.
  - SampleBrowser's `DependencyHelper` calls `fatalError` unless `UIApplication.shared.delegate`
    is its `AppDelegate`. So the Gecko build replaces `AppDelegate.swift` and
    `DependencyHelper.swift` with versions in `App/` that run off
    `didFinishLaunchingNotification`.
  - **M3 will hit the same thing in Fennec, which has a much bigger `AppDelegate`.**
- **Loads sent right after `GeckoSession.open()` are dropped.** `GeckoEngineSession` holds them
  until Gecko reports its first location (about:blank), then sends them.
- **The extensions need `@executable_path/../../Frameworks` in their runpath** to find
  `GeckoView.framework` inside the host app. Without it, WebContent dies at launch ("Library
  missing"), and Gecko logs `Failed to launch tab subprocess` and never fetches anything.
- **iOS also requires version keys in each extension's Info.plist** (`MARKETING_VERSION`,
  `CURRENT_PROJECT_VERSION`). Without them, install fails with "Invalid placeholder attributes".
- **A static library that imports WebEngine needs**
  `-Xcc -fmodule-map-file=$(GENERATED_MODULEMAP_DIR)/GCDWebServers.modulemap` and explicit modules
  turned off, or it can't resolve WebEngine's ObjC dependency.
- **`WebEngine` isn't engine-neutral yet** (an M3 design input):
  - `EngineSessionDependencies` carries `WKWebViewParameters` and `WKReaderModeDelegate`, and
    its fields are internal.
  - `EngineSessionBackForwardListItem.swift` imports WebKit.
  - `URLFormatter` calls `WKInternalURL`.
- **Upstream quirk, not fixed:** `DefaultURLFormatter.handleLocalHost` prefixes `http://`
  to whatever was typed, so typing `http://localhost:…` turns into a search. Type
  `localhost:8765/engine.html` instead.

**What `GeckoEngineSession` doesn't do yet.** These are no-ops, because GeckoView's iOS
embedding doesn't expose them:
- back/forward list items
- `goToHistory`, `restore(state:)`
- find in page
- zoom
- tracking-protection modes, no-image mode
- `scrollToTop`
- clearing data
- popups (`onNewSession` returns nil)

These were wired and seen working: location, title, loading state, progress, and
can-go-back/forward. `reload(bypassCache:)` ignores the flag.

**Reproduce:**
```
python3 -m http.server 8765 --bind 127.0.0.1   # in gecko-port/proof
cd gecko-port/SampleBrowserGecko && xcodegen generate
xcodebuild -project SampleBrowserGecko.xcodeproj -scheme SampleBrowserGecko \
  -destination 'platform=iOS Simulator,id=<udid>' -skipMacroValidation -skipPackagePluginValidation build
xcrun simctl install <udid> <DerivedData>/…/SampleBrowserGecko.app
cd ../SimDriver && xcodegen generate
TEST_RUNNER_PROOF_BUNDLE=org.eaglstun.geckoport.SampleBrowserGecko \
TEST_RUNNER_PROOF_SITE_URL='https://en.wikipedia.org/wiki/Gecko_(software)' \
TEST_RUNNER_PROOF_ENGINE_URL='localhost:8765/engine.html' \
TEST_RUNNER_PROOF_LINK_TAP='0.5,0.567' TEST_RUNNER_PROOF_DIR=<dir> \
xcodebuild test -project SimDriver.xcodeproj -scheme SimDriver \
  -destination 'platform=iOS Simulator,id=<udid>' -only-testing:SimDriverUITests/EngineProofTest
```
The Gecko app needs `mozilla-firefox/obj-ios-sim` from M1. With a warm build, it builds in
about 15 s after a source change.

### M2 rerun on iOS 27.2 (2026-11-06)

The iOS 27.2 simulator runtime was installed after M2, so the same builds were re-run on the
iPhone 18 Pro / iOS 27.2 (`D30C6397-…`):
- SampleBrowserGecko passed all four proof steps: Wikipedia; engine page **GECKO**,
  `CSS.supports` `true`, same `rv:162.0 Gecko/162.0` UA; followed the link; Back.
- Stock SampleBrowser shows **NOT GECKO**, `CSS.supports` `false`.

The committed M2 screenshots are from 27.0; the 27.2 ones were checked and are identical in
content. That run also exposed a harness bug: an empty `PROOF_LINK_TAP` was treated as a
coordinate. `EngineProofTest` now treats empty as unset. 27.2 is the default simulator from now on.

## M3 design (2026-11-06)

`M3-DESIGN.md` is written. No M3 code yet: per the plan it waits for Eric's go-ahead.

What the survey found:
- 97 Client files import WebKit; 146 `.webView` references in 51 files. `TabWebView` *is a*
  `WKWebView`, and features reach the page three ways: web view properties (KVO in BVC),
  the 1,748-line navigation/UI delegate extension, and 15 user scripts installed per tab.
- The user-script channel has no Gecko counterpart on iOS (GeckoView uses WebExtensions for
  that, and none are wired), so every script-based feature is stubbed for M3.
- Gecko's shared GeckoView JS already handles history index, restore state, find in page and
  scroll messages; the iOS Swift layer just doesn't send them. Because our projects compile the
  `GeckoView` framework from Gecko's source folder, Swift files from this repo can add those
  calls without patching Gecko.
- Gecko hard-codes `AppShellDelegate` as the app delegate, which collides with Fennec's
  `AppDelegate`. That and three other choices (private tabs, a dormant `WKWebView` per tab,
  xcconfig vs pbxproj plumbing) are listed as decisions in the doc.
- Five files only show Mozilla pages in their own `WKWebView` and can stay WebKit; four
  import WebKit without using it.

## M3 done (2026-11-06)

**Fennec browses on Gecko** in the iOS 27.2 simulator (iPhone 18 Pro), behind
`GECKO_ENGINE_BUILD=YES`. Eric's design decisions are at the top of `M3-DESIGN.md`.

**Proof** (SimDriver, real Fennec UI, typing into Fennec's own address bar):

| Step | Result | Screenshot |
| ---- | ------ | ---------- |
| Wikipedia article | renders | `m3-fennec-1-site.png` |
| `engine.html` | **GECKO**, `CSS.supports` `true`, UA `rv:162.0 Gecko/162.0 Firefox/162.0`; Fennec's URL bar shows `localhost`, Back lit | `m3-fennec-2-engine.png` |
| follow the link | second page | `m3-fennec-3-followed.png` |
| Back | engine page again, Forward now lit | `m3-fennec-4-back.png` |
| control: stock WebKit Fennec | **NOT GECKO**, `CSS.supports` `false`, AppleWebKit UA | `m3-webkit-2-engine.png` |

Tabs (`TabsProofTest`): opened a second tab and loaded another page; the tray shows both with
their page titles ("Engine check", "Second page"); selecting the first tab shows its GECKO page;
closing the second tab leaves one. Tab thumbnails are blank (screenshots are a stub).

Not shown: **session restore**. After relaunch the tray holds one Homepage tab, but stock WebKit
Fennec does exactly the same under this harness (also with `FIREFOX_ENABLE_SESSION_RESTORE` and
backgrounding the app before terminating), so it's a harness problem I didn't solve, not a
measured Gecko regression. Gecko tabs restore by reloading their saved URL; that path is
untested.

WebKit mode still builds; 179 unit tests (`TabTests`, `TabManagerTests`,
`TabManagerRestoreTabsTests`, `TabManagerPreserveTabsTests`, `BrowserViewControllerTests`,
`TabTrayViewControllerTests`) pass. SwiftLint is clean on every changed file.

**Gecko patch** (local branch `ios-gecko-engine` in `mozilla-firefox`, commit `eb3defcca458`):
`nsAppShell::Run` passes a delegate class set through `GeckoSetAppDelegateClassName` to
`UIApplicationMain` (default `AppShellDelegate`); `GeckoAppShellWillTerminate` and
`GeckoAppShellDidReceiveMemoryWarning` do AppShellDelegate's work for a replacement delegate.
The three functions are added to `libxul.symbols` (without that they link but aren't exported).
Console proof: `GeckoView.Startup` and `nsAppShell::Run`, then Fennec's
`willFinishLaunchingWithOptions`/`didFinishLaunchingWithOptions`.

**How it's built:**
- `gecko-port/FennecGecko/`: xcodegen project for GeckoView (+ `GeckoViewHooks/`),
  `libGeckoEngine.a` (+ `Bridge/`), and the three extensions with `org.mozilla.ios.Fennec.Gecko*`
  IDs; `Gecko.xcconfig`; `build.sh`; entitlements.
- Upstream edits, all inert without the flag: `Fennec.xcconfig` (one include), `Client.xcodeproj`
  (3 lines: a synced `Client/Gecko` folder), `main.swift`, `AppDelegate.swift`, `Tab.swift`,
  `BrowserViewController.swift`, `TabTrayViewController.swift`,
  `BrowserViewController+ToolBarActionMenuDelegate.swift`.
- New in Client: `Gecko/GeckoBridge.swift` (calls libGeckoEngine by symbol name, so Client never
  imports Gecko modules), `Gecko/TabEngine.swift` (a tab's session, view and page state),
  `Gecko/BrowserViewController+GeckoEngine.swift` (the WebKit-free parts of didCommit/didFinish).
- WebEngine: new `Gecko/EngineSessionNewTabDelegate.swift`. GeckoEngine: non-web schemes open
  externally; new-window requests become new Fennec tabs.

**Findings:**
- Gecko's iOS `onNewSession` handler can't work as written: it asserts the returned session is
  open, then calls `open()`, which fatal-errors on an open session.
- Fennec's `navigateInTab` keyed history recording off `webView.url`; it now uses `tab.url` for
  Gecko tabs, otherwise visits would silently never be recorded.
- Fennec's tab tray has an experiment selector besides the segmented control; both needed the
  Private entry disabled.
- The "Class … is implemented in both" console warnings appear in the stock WebKit test run too
  (35 of them); they're from upstream's debug build, not this work.

**Stubbed in Gecko mode** (per the design): all user-script features (logins, autofill, reader
mode, find in page, translations, Summarize, night/no-image mode, context menus), JS dialogs,
downloads, content blocking UI, tab thumbnails, toolbar hide-on-scroll, Clear Data for Gecko's
profile, Gecko session history.

**Reproduce:**
```
cd gecko-port/proof && python3 -m http.server 8765 --bind 127.0.0.1 &
gecko-port/FennecGecko/build.sh            # prints the .app path
xcrun simctl install <udid> <that path>
cd gecko-port/SimDriver && xcodegen generate
TEST_RUNNER_PROOF_BUNDLE=org.mozilla.ios.Fennec \
TEST_RUNNER_PROOF_ARGS="FIREFOX_TEST FIREFOX_CLEAR_PROFILE FIREFOX_SKIP_INTRO FIREFOX_SKIP_WHATS_NEW FIREFOX_SKIP_ETP_COVER_SHEET FIREFOX_SKIP_CONTEXTUAL_HINTS FIREFOX_SKIP_TERMS_OF_USE SKIP_DEFAULT_BROWSER_ONBOARDING SKIP_APPLE_INTELLIGENCE DISABLE_ANIMATIONS" \
TEST_RUNNER_PROOF_SITE_URL='https://en.wikipedia.org/wiki/Gecko_(software)' \
TEST_RUNNER_PROOF_ENGINE_URL='localhost:8765/engine.html' TEST_RUNNER_PROOF_LINK_TAP='0.5,0.4975' \
TEST_RUNNER_PROOF_BACK_ID='TabToolbar.backButton' TEST_RUNNER_PROOF_DIR=<dir> \
xcodebuild test -project SimDriver.xcodeproj -scheme SimDriver \
  -destination 'platform=iOS Simulator,id=<udid>' -only-testing:SimDriverUITests/EngineProofTest
```
`TabsProofTest` takes `TABS_ARGS`, `TABS_RELAUNCH_ARGS`, `TABS_URL_1`, `TABS_URL_2`, `TABS_DIR`.

## M4: on the phone (2026-11-06)

**Result:** Fennec on Gecko runs on Eric's iPhone 17 Pro (iOS 27). Eric loaded his own site,
ai.ericeaglstun.com, and it rendered (`m4-iphone-site.png`). Stock Firefox is still installed
next to it, untouched.

**How Gecko runs without BrowserEngineKit:** single-process. Gecko's iOS port starts its content,
networking and GPU work in BrowserEngineKit process extensions, which need entitlements a dev
certificate can't have. With `MOZ_FORCE_DISABLE_E10S=1` Gecko allows non-e10s (our build isn't
`MOZILLA_OFFICIAL`), but GeckoView's `geckoview.js` hard-coded `remote="true"` on the browser
element, so it still tried to launch a content process (`com.apple.browserEngineKit error 1`).
Gecko patch on `ios-gecko-engine`, `c2950af31193`: only set `remote`/`remoteType`/
`maychangeremoteness` when `browserTabsRemoteAutostart` is true. Proven first in the simulator
with the extensions deleted: engine page GECKO, link, Back. The bridge sets the env var when the
app has no `Extensions` folder, so simulator builds keep multi-process.

**JIT:** `javascript.options.main_process_disable_jit` defaults to true on iOS, and all content
now runs in the main process, so JS is interpreted. Nothing needed switching.

**Device build of Gecko:** `gecko-port/mozconfig-ios-device`, 513 s clean. Xcode 27's iPhone SDK
`.tbd` stubs list only `arm64e, arm64e.x1`; Gecko's lld rejects them ("unknown architecture").
Apple's ld accepts them for arm64, but configure's ld64 probe relied on `LD_PRINT_OPTIONS`, which
ld-prime dropped. Gecko patch `b38ef2b984d9` also accepts "ld: unknown options: --version".

**Signing:** team `EKNXJ2NR3G`, bundle ID `com.rackandpinecone.FennecGecko`. First install used the
team wildcard profile; Fennec then got stuck on the onboarding Skip step, because its prefs,
Nimbus database and tab store live in the app group (`group.<bundle id>`) and a wildcard profile
can't grant one. Needed from Eric: sign Xcode in, accept the updated Program License
Agreement, create the App Group in the portal; the agent linked it to the App ID with his OK.
`device.sh` now signs with that profile (app group, increased memory limit, keychain group).

**Eric's notes:** scrolling stutters a little. Not yet profiled. On UIKit, Gecko's async
scrolling (APZ) stays on without e10s (`gfxPlatform::AsyncPanZoomEnabled`), so the likely costs
are touch handling waiting on a main thread that page layout, interpreted JS and Fennec's UI now
share, and Fennec being a Debug (`-Onone`) build.
It stutters for the whole scroll, on a page with no JavaScript. Likely cause, found in the
source: Gecko on iOS has no hardware vsync. `gfxPlatformMac::CreateGlobalHardwareVsyncSource`
falls back to `GetSoftwareVsyncSource()` with `// TODO: CADisplayLink`, so frames are paced
by a timer that isn't locked to the 120 Hz ProMotion display. Fennec's Info.plist also lacks
`CADisableMinimumFrameDurationOnPhone`, which caps app-driven frame rates at 60 Hz.

**Not yet measured:** speed against WebKit Firefox on real sites, memory use, and whether tabs
restore after a relaunch on the phone. The address bar shows the not-secure icon on an HTTPS
site, because `onHasOnlySecureContentChanged` is still a stub in `TabEngine`.

**Reproduce:**
```
cd mozilla-firefox && MOZCONFIG=../firefox-ios/gecko-port/mozconfig-ios-device ./mach build
firefox-ios/gecko-port/FennecGecko/device.sh     # DEVICE=<udid> to pick a phone
```
