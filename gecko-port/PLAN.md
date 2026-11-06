# Firefox iOS on Gecko: Plan

**Branch:** `gecko-engine` (fork: `eaglstun/firefox-ios`, upstream: `mozilla-mobile/firefox-ios`)
**Status:** M0, M1, M2 done. Next: M3 design (`M3-DESIGN.md`), then stop for Eric's go-ahead.
**Evidence log:** `RESULT.md` in this folder. Every milestone ends with proof there.

## The goal

Firefox for iOS with Gecko, Firefox's own engine, rendering the pages instead of
WebKit. This is a personal, dev-signed build on Eric's own devices. It never goes
to the App Store, and nothing here is meant to be upstreamed.

Why it's possible: Apple's App Store rules require WebKit for browsers outside
the EU and Japan, but those rules govern _distribution_, not what compiles.
Mozilla keeps an iOS port prototype of Gecko in its own source tree
(`mobile/ios/` in mozilla-firefox), and a community browser, Reynard, ships
Gecko on iOS through sideloading. So the engine has been on an iPhone before.
The new part is putting it inside the real Firefox iOS app.

## The workspace (all siblings in `~/Documents/dev/`)

| Path               | What                                                                 | Rules                                                                                                                                                                              |
| ------------------ | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `firefox-ios/`     | **This repo.** The fork. All app-side work happens here.             | Work on `gecko-engine`. Commit freely. Push only when asked.                                                                                                                       |
| `mozilla-firefox/` | Gecko source (`github.com/mozilla-firefox/firefox`), blobless clone. | Read and build. If Gecko itself needs patching, do it on a local branch `ios-gecko-engine` and log every patch in `RESULT.md`. There's no fork of it yet; ask before creating one. |
| `reynard-browser/` | `minh-ton/reynard-browser`, a working Gecko-on-iOS browser.          | **Reference only. GPL-3.0. Never copy code from it.** See Licensing.                                                                                                               |

## The seam

Firefox iOS already has the abstraction this needs, half-adopted:

- **`BrowserKit/Sources/WebEngine/`** defines `Engine`, `EngineSession`, and
  `EngineView` (all `@MainActor` protocols), plus `EngineSessionDelegate` and
  friends. `WebEngine/WKWebview/` is the only implementation: `WKEngine`,
  `WKEngineSession`, `WKEngineView`.
- **`SampleBrowser/`** is a small browser built _entirely_ on `WebEngine`. It
  picks its engine on one line: `SampleBrowser/Engine/EngineProvider.swift:16`,
  `WKEngine.factory(...)`. This is the cheapest place to prove a Gecko engine.
- **The real app (`firefox-ios/Client/`, scheme `Fennec`) mostly bypasses it.**
  `Tab` holds a `TabWebView`, and `TabWebView` _is a_ `WKWebView` subclass
  (`Client/TabManagement/TabWebView.swift`). At setup time: 1,109 Swift files in
  Client, 96 `import WebKit`, 51 mention `WKWebView` (176 lines), and 20
  `import WebEngine`. Getting the app onto Gecko means finishing that migration,
  which is the big job (M3).

On the Gecko side, read `mozilla-firefox/mobile/ios/README` first. Gecko's core
(libxul) builds with `./mach build` and a mozconfig containing
`ac_add_options --enable-application=mobile/ios`. Then an Xcode project
(`mobile/ios/GeckoTestBrowser/GeckoTestBrowser.xcodeproj`) wraps it in a minimal
app. GeckoTestBrowser has its own Swift `GeckoView` layer (`GeckoView/`,
`Networking/`, `Rendering/`, `WebContent/`). That's the API you'll adapt to the
`WebEngine` protocols.

## Milestones

Each one ends with something you can see, a screenshot saved in this folder, and
an entry in `RESULT.md`. Simulator first, device last.

| #   | Milestone                                                                                                                                                                                                                                                                                                                                                                                                                                 | Proof                                                                                                                                                                                                                                           |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M0  | **Baseline.** Build `SampleBrowser` and `Fennec` unmodified in the iOS Simulator. Record the exact Xcode, simulator, and command lines. Done on Xcode 27.2 (27.0 couldn't build Fennec). Don't upgrade Xcode yourself.                                                                                                                                                                        | Both apps load a page. Screenshots.                                                                                                                                                                                                             |
| M1  | **Gecko on its own.** Build libxul for the iOS Simulator from `mozilla-firefox/` and run GeckoTestBrowser. No Firefox iOS code involved. Record the mozconfig, build time, and objdir size.                                                                                                                                                                                                                                               | GeckoTestBrowser renders a live page in the simulator. Screenshot.                                                                                                                                                                              |
| M2  | **`GeckoEngine` in SampleBrowser.** Add `GeckoEngine`, `GeckoEngineSession`, and `GeckoEngineView` conforming to the `WebEngine` protocols, backed by the Gecko build from M1. Switch it in at `EngineProvider.swift` behind a compile-time flag, so the WKEngine path still builds. Keep the Gecko implementation in its own folder or target, next to `WKWebview/`, not mixed into it.                                                  | SampleBrowser loads Wikipedia, follows a link, goes back. Prove it's Gecko, not WebKit, with a page that reports `navigator.userAgent` and something only Gecko answers, such as `CSS.supports("-moz-appearance", "none")`. Screenshot of both. |
| M3  | **Design checkpoint, then the real app.** _Before writing code_, write `gecko-port/M3-DESIGN.md`: every place Client depends on WebKit types, grouped by feature (navigation, tabs, find, reader mode, user scripts, content blocking, downloads, auth...). Propose the smallest slice that gets Fennec browsing on Gecko and what gets stubbed. **Stop and get Eric's go-ahead on it.** Then build it behind the same compile-time flag. | Fennec browses on Gecko: URL bar, tabs, back/forward. Same proof page as M2.                                                                                                                                                                    |
| M4  | **On the phone.** Dev-signed build on Eric's iPhone via Xcode. Expect no JIT: iOS only grants it through Apple's BrowserEngineKit entitlements, and a personal dev build doesn't have those. Find Gecko's switch for interpreter-only JavaScript and use it. Measure how it feels against WebKit Firefox on a few real sites.                                                                                                             | Running on device. Notes on what's slow.                                                                                                                                                                                                        |

Past M4 is open: content blocking, add-ons, Sync. Don't start any of it without
Eric picking it.

## Working notes

Practical facts learned along the way. Keep this current; details and history live in `RESULT.md`.

- **Xcode 27.2** (27B52). This install has no Simulator.app, so simulators run headless.
  The default simulator is the iPhone 18 Pro on **iOS 27.2**, `D30C6397-DF3A-4D34-ACB7-3E4C9DF97F02`.
  There's also an iPhone Duo on a separate 27.2 runtime (`FC56A158-C7CB-4643-B916-D1EBB53A48CC`),
  for Fennec's foldable code paths. Older runtimes (27.0, 26.5, 18.4) are still installed.
- **Builds:** pass `-skipMacroValidation -skipPackagePluginValidation` to `xcodebuild`. After an
  Xcode upgrade, delete `DerivedData/<Project>-*/Build` if Swift macros fail to load
  `SwiftSyntax`.
- **Screenshots and proof runs:** `gecko-port/SimDriver/` is a standalone XCUITest project that
  opens a URL in any app (through a URL scheme with `DRIVER_URL`, or by typing into the first
  text field with `DRIVER_TYPE`), taps iOS's "Open in …?" prompt, and saves a PNG. Usage is in
  `SimDriver/UITests/OpenURLTest.swift`. For Fennec, pass the UI-test launch flags
  (`FIREFOX_TEST FIREFOX_SKIP_INTRO …`; the full list is in `RESULT.md`, M0) and open
  `fennec://open-url?url=<encoded>`. SampleBrowser opens a URL with
  `-SampleBrowserStartURL <url>`.
- **Gecko build:** the mozconfig is `gecko-port/mozconfig-ios-sim`, used via
  `MOZCONFIG=<that path> ./mach build` from `mozilla-firefox/`. The objdir is
  `mozilla-firefox/obj-ios-sim`. Gecko's toolchains (clang etc.) download themselves into
  `~/.mozbuild` during configure.
- **GeckoTestBrowser:** build it with ad-hoc signing and an explicit objdir:
  `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual GECKO_TOPOBJDIR=<objdir>`.
  The full command is in `RESULT.md`, M1. It has no URL scheme; drive it with SimDriver's
  `DRIVER_TYPE`.
- **Gecko SampleBrowser:** `gecko-port/SampleBrowserGecko/` (xcodegen). `GeckoEngine` sources live in
  `BrowserKit/Sources/GeckoEngine/`, are not a SwiftPM target, and are built as a static library by
  that project. The `GECKO_ENGINE` compile flag selects Gecko in `EngineProvider.swift`.
  `SampleBrowser.xcodeproj` stays on WebKit.
- **Embedding Gecko, the gotchas** (details in `RESULT.md`, M2):
  - `GeckoRuntime.main` replaces the app delegate with Gecko's `AppShellDelegate`.
  - Loads sent before the first location event are dropped; `GeckoEngineSession` queues them.
  - The extensions need `@executable_path/../../Frameworks` in their runpath, and version keys
    in their Info.plists.
- **Proof run:** serve `gecko-port/proof/` on `localhost:8765`, then run SimDriver's
  `EngineProofTest`. Type `localhost:8765/engine.html` without `http://`; with it,
  SampleBrowser's URL formatter turns it into a search.
- **Machine load:** a clean Gecko build takes about 15 min and swaps hard, and can kill a
  booted simulator. Boot it again with `xcrun simctl boot <udid>` before driving it.
- **Rust:** Gecko main needs Rust 1.95 or newer. `mozilla-firefox/` has a rustup directory
  override to 1.95 (with the `aarch64-apple-ios-sim` target). The machine default stays on
  stable 1.94.1; don't change it without asking.
- **GeckoTestBrowser uses BrowserEngineKit.** It's a host app plus Networking, Rendering and
  WebContent process extensions, with `com.apple.developer.web-browser-engine.*` entitlements.
  The simulator doesn't enforce entitlements; a personal dev certificate can't get them. Plan for
  that at M4: Gecko would need to run without those extensions, or we learn how Reynard
  sideloads it.

## Rules for the agent

- **Commit at every working step** on `gecko-engine`, with clear messages. Never
  push, open PRs, or touch the GitHub fork's settings unless Eric asks. Never
  open anything against `mozilla-mobile/firefox-ios` or Mozilla's Bugzilla.
- **Keep the WebKit path building.** The Gecko engine is opt-in behind a flag.
  If you break the default build, fix it before moving on.
- **Prefer adding over editing upstream files.** New engine code lives in new
  files. When an upstream file must change, keep the change small. This fork has
  to keep merging `upstream/main`, and every edited line is a future conflict.
- **Upstream's `AGENTS.md` rules still apply to code you write** (minimal
  comments, tests where sensible, SwiftLint).
- **Licensing:** firefox-ios and Gecko are MPL-2.0. Reynard is GPL-3.0. Read
  Reynard to understand _how_ it solved something (build flags, JIT handling,
  process model), then write your own implementation. Copying its code would put
  GPL obligations on the result. If copying ever looks like the right call,
  stop and ask Eric; it's a licensing decision, not a technical one.
- **Big builds go in the background.** A Gecko build takes a long time and the
  objdir runs to tens of GB. Disk is fine (over 1 TB free at setup). Log
  build times in `RESULT.md`.
- **Stop and ask** before: upgrading Xcode or system tools, creating new GitHub
  repos or forks, anything that spends money, the M3 design, and any change to
  how code is licensed.
- **Report honestly.** If a milestone half-works, `RESULT.md` says which half.
  A screenshot of a failure is worth logging too.

## Authorship

Eric directs this project and judges the behavior. The agents write the code.
`RESULT.md` and commit messages should read that way: they describe what was
built and verified, not a person typing it.
