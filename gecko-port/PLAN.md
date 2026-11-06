# Firefox iOS on Gecko: Plan

**Branch:** `gecko-engine` (fork: `eaglstun/firefox-ios`, upstream: `mozilla-mobile/firefox-ios`)
**Status:** M0 done (Xcode 27.2). Next: M1.
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
| M0  | **Baseline.** Build `SampleBrowser` and `Fennec` unmodified in the iOS Simulator. Record the exact Xcode, simulator, and command lines. Note: upstream's README asks for Xcode 27.1; this Mac has 27.0. If 27.0 can't build it, stop and tell Eric. Don't upgrade Xcode yourself.                                                                                                                                                         | Both apps load a page. Screenshots.                                                                                                                                                                                                             |
| M1  | **Gecko on its own.** Build libxul for the iOS Simulator from `mozilla-firefox/` and run GeckoTestBrowser. No Firefox iOS code involved. Record the mozconfig, build time, and objdir size.                                                                                                                                                                                                                                               | GeckoTestBrowser renders a live page in the simulator. Screenshot.                                                                                                                                                                              |
| M2  | **`GeckoEngine` in SampleBrowser.** Add `GeckoEngine`, `GeckoEngineSession`, and `GeckoEngineView` conforming to the `WebEngine` protocols, backed by the Gecko build from M1. Switch it in at `EngineProvider.swift` behind a compile-time flag, so the WKEngine path still builds. Keep the Gecko implementation in its own folder or target, next to `WKWebview/`, not mixed into it.                                                  | SampleBrowser loads Wikipedia, follows a link, goes back. Prove it's Gecko, not WebKit, with a page that reports `navigator.userAgent` and something only Gecko answers, such as `CSS.supports("-moz-appearance", "none")`. Screenshot of both. |
| M3  | **Design checkpoint, then the real app.** _Before writing code_, write `gecko-port/M3-DESIGN.md`: every place Client depends on WebKit types, grouped by feature (navigation, tabs, find, reader mode, user scripts, content blocking, downloads, auth...). Propose the smallest slice that gets Fennec browsing on Gecko and what gets stubbed. **Stop and get Eric's go-ahead on it.** Then build it behind the same compile-time flag. | Fennec browses on Gecko: URL bar, tabs, back/forward. Same proof page as M2.                                                                                                                                                                    |
| M4  | **On the phone.** Dev-signed build on Eric's iPhone via Xcode. Expect no JIT: iOS only grants it through Apple's BrowserEngineKit entitlements, and a personal dev build doesn't have those. Find Gecko's switch for interpreter-only JavaScript and use it. Measure how it feels against WebKit Firefox on a few real sites.                                                                                                             | Running on device. Notes on what's slow.                                                                                                                                                                                                        |

Past M4 is open: content blocking, add-ons, Sync. Don't start any of it without
Eric picking it.

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
