# M3 design: Fennec on Gecko

**Status:** proposal. No M3 code is written. Waiting on Eric's go-ahead and the four decisions in
[Decisions for Eric](#decisions-for-eric).

**M3 goal:** Fennec browses on Gecko, with the URL bar, tabs, and back/forward
working. The proof is the same as M2: Wikipedia loads, `engine.html` shows GECKO,
a link opens, and Back works. Everything else may be stubbed, as long as the doc
says so.

Counts are from `gecko-engine` at `66322374b`.

## 1. How deep WebKit goes in Client

| Measure                                                  | Count |
| -------------------------------------------------------- | ----- |
| Swift files in `firefox-ios/Client` with `import WebKit` | 97    |
| Lines that name `WKWebView`                              | 159   |
| `.webView` references (in 51 files)                      | 146   |
| Files that already `import WebEngine`                    | 20    |

The trunk is one line in `TabManagement/TabWebView.swift`:

```swift
class TabWebView: WKWebView, MenuHelperWebViewInterface, ThemeApplicable, Notifiable
```

`Tab.webView` is a `TabWebView`, so it is a `WKWebView`. Every feature reaches the page
through it, through one of three channels:

1. **Properties and calls on the web view.** `url`, `title`, `isLoading`,
   `estimatedProgress`, `canGoBack`, `load`, `go(to:)`, `interactionState`,
   `scrollView`, `createPDF`, `takeSnapshot`, `findInteraction` and so on.
   `BrowserViewController` follows `url`, `title`, `estimatedProgress`, `loading`,
   `canGoBack`, `canGoForward` and `hasOnlySecureContent` with KVO
   (`BrowserViewController.swift:2488`).
2. **`WKNavigationDelegate` and `WKUIDelegate` on BVC.**
   `BrowserViewController+WebViewDelegates.swift` is 1,748 lines. It covers
   navigation policy (external apps, the App Store, universal links, downloads,
   popups, internal URLs), commit and finish, server trust, HTTP auth, JS alerts,
   context menus, new windows and media permissions.
3. **User scripts and message handlers.** `TabContentScript`
   (`Tab.swift:34`) is a `WKScriptMessageHandler` by another name. BVC installs
   15 of them per tab in `tab(_:didCreateWebView:)` (`BrowserViewController.swift:4386`).
   They are injected through `WKUserContentController`, and some run in a custom
   `WKContentWorld`. Fennec's page features run on this channel.

The WebEngine abstraction (`Engine`, `EngineSession`, `EngineView`) exists, but
Client only uses it for configuration types (`WKEngineConfiguration`) and
reader-mode and scheme-handler helpers. No tab in Client is backed by an
`EngineSession` today.

## 2. What Gecko's iOS layer offers

M2 built against `mobile/ios/GeckoTestBrowser/GeckoView/` (Gecko `main` @
`d9bd6be9a67e`). Its Swift API is thin:

- **`GeckoSession`:**
  - `open`, `close`, `load(String)`, `reload`, `stop`
  - `goBack`, `goForward`, `setActive`, `getUserAgent`
- **Delegates:**
  - navigation: location, can-go-back/forward, load request, new session
  - content: title, context menu, crash, fullscreen, first paint
  - progress: page start/stop, progress
  - permission

The Gecko side underneath is the same shared GeckoView JS that Android uses, and
it handles far more messages than the Swift layer sends. A few examples:

- `GeckoView:GotoHistoryIndex`
- `GeckoView:PurgeHistory`
- `GeckoView:RestoreState`
- `GeckoView:FindInPage` / `ClearMatches` / `DisplayMatches`
- `GeckoView:ScrollTo` / `ScrollBy`
- `GeckoView:ZoomToInput`

The modules for those are already enabled, because their handlers (Content,
Navigation, Progress) are registered. `GeckoView:StateUpdated`, the session-history
blob, already arrives; the iOS handler just has a `// TODO` there
(`ProgressDelegate.swift:61`).

Two things make extending it cheap:

- **No Gecko patch needed.** Our xcodegen projects compile the `GeckoView`
  framework _from Gecko's source folder_. A Swift file we own can be added to
  that target and reach `GeckoSession.dispatcher` (which is `internal`). The
  missing calls can be added from this repo.
- **Prompts and WebExtensions are the hard gaps.** The `GeckoViewPrompter`
  module (alert, confirm, auth, select and file pickers) is not enabled, because
  `GeckoSession.open()` builds its module list from its fixed handler array. No
  WebExtension or content-script path is wired on iOS. There is also no
  `evaluateJavaScript` equivalent: GeckoView doesn't have one on Android either,
  where page scripts go through WebExtensions.

So the third channel, Fennec's user scripts, has **no Gecko counterpart for
M3**. Each of those features gets stubbed (off in Gecko mode) until a
WebExtension bridge exists. That bridge is post-M4 work.

## 3. Inventory by feature

Every one of the 97 files is listed once. **Slice** means M3 changes the file.
**Stub** means it stays compiled, and in Gecko mode the feature is off or does
nothing. **Keep WebKit** means the file uses its own private `WKWebView` that
isn't a tab, so it can keep working as-is: Gecko and WebKit run side by side in
one app fine.

### Core: navigation, tabs, URL bar (Slice)

| File                                                                                                       | WebKit use                                                                                    |
| ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `TabManagement/TabWebView.swift`                                                                           | _is a_ `WKWebView`; accessory view, pull-to-refresh, secure-content override                  |
| `TabManagement/Tab.swift`                                                                                  | owns `webView`; load, back/forward, reload, title, progress, restore, find                    |
| `TabManagement/TabManager.swift`, `TabManagerImplementation.swift`                                         | `subscript(webView:)`, popups get a `WKWebViewConfiguration`, `interactionState` save/restore |
| `TabManagement/TabManagerDelegate.swift`                                                                   | delegate signatures take `WKWebView`                                                          |
| `TabManagement/TabConfigurationProvider.swift`                                                             | builds `WKEngineConfiguration`                                                                |
| `TabManagement/BackForwardList.swift`                                                                      | wraps `WKBackForwardList`                                                                     |
| `TabManagement/BlankPageNavigationDelegate.swift`                                                          | awaits `about:blank` loads on offload                                                         |
| `Frontend/Browser/WebView/WebviewViewController.swift`                                                     | hosts the tab's `WKWebView`; PDF screenshot via `createPDF`                                   |
| `Frontend/Browser/WebView/WebViewNavigationHandler.swift`                                                  | navigation-policy helper                                                                      |
| `Frontend/Browser/BrowserViewController/Views/BrowserViewController.swift`                                 | KVO on the web view; per-tab setup and teardown; toolbar state                                |
| `…/Extensions/BrowserViewController+WebViewDelegates.swift`                                                | all of `WKNavigationDelegate` and `WKUIDelegate`                                              |
| `…/State/BrowserViewControllerState.swift`, `…/Actions/GeneralBrowserAction.swift`                         | actions carry a `WKWebView`                                                                   |
| `Coordinators/Browser/BrowserCoordinator.swift`, `BrowserDelegate.swift`, `BrowserNavigationHandler.swift` | show the web view; pass it to sub-coordinators                                                |

### User scripts and page helpers (Stub; channel 3, no Gecko path)

| File                                                                                                 | Feature it powers                           |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `TabManagement/TabContentScriptManager.swift`, `Frontend/TabContentsScripts/UserScriptManager.swift` | script injection and message routing        |
| `Frontend/TabContentsScripts/FocusHelper.swift`                                                      | knowing when a field has focus              |
| `…/ContextMenuHelper.swift`                                                                          | long-press link and image info              |
| `…/LocalRequestHelper.swift`                                                                         | privileged internal-page requests           |
| `…/NightModeHelper.swift`, `…/NoImageModeHelper.swift`                                               | night mode, no-image mode                   |
| `…/PrintHelper.swift`                                                                                | `window.print()`                            |
| `…/BackgroundAudioHelper.swift`                                                                      | keep audio playing in the background        |
| `Frontend/Browser/MetadataParserHelper.swift`                                                        | page metadata (feeds history and top sites) |

### Find in page (Stub; possible M3+ quick win)

| File                                                   | Note                                                                                     |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `Frontend/TabContentsScripts/FindInPageHelper.swift`   | user-script based. Gecko has `GeckoView:FindInPage` natively; a good first post-M3 item. |
| (`Tab.setFindInPage` uses `WKWebView.findInteraction`) |                                                                                          |

### Reader mode (Stub)

| File                                                           | Note                                                    |
| -------------------------------------------------------------- | ------------------------------------------------------- |
| `Frontend/Reader/ReaderMode.swift`, `ReadabilityService.swift` | Readability runs as a user script; a hidden `WKWebView` |
| `Frontend/Reader/SchemeHandler/ReaderModeSchemeHandler.swift`  | `WKURLSchemeHandler` for reader pages                   |

### Internal pages and error pages (Stub; homepage stays native)

| File                                                         | Note                                                    |
| ------------------------------------------------------------ | ------------------------------------------------------- |
| `Frontend/InternalSchemeHandler/InternalSchemeHandler.swift` | serves `internal://`; Gecko can't call it               |
| `Frontend/InternalSchemeHandler/ErrorPageHelper.swift`       | Fennec's error pages; in Gecko mode Gecko shows its own |
| `Frontend/NativeErrorPage/NativeErrorPageMiddleware.swift`   | native error page; keyed on WebKit errors               |

### Content blocking and tracking protection (Stub)

`ContentBlocker/ContentBlocker.swift`, `ContentBlocker+Safelist.swift`,
`TabContentBlocker.swift`, `TabContentBlocker+ContentScript.swift`,
`Frontend/Browser/FirefoxTabContentBlocker.swift`,
`Coordinators/EnhancedTrackingProtectionCoordinator.swift`.

These compile `WKContentRuleList`. Gecko has its own tracking protection (the
`useTrackingProtection` session setting, currently `false`). Turning on
Gecko's ETP is a one-line follow-up, but the shield panel UI reads the WebKit
blocker's stats, so it would show nothing.

### Downloads and documents (Stub)

`Frontend/Browser/DownloadHelper/Download.swift`, `DownloadHelper.swift`,
`Frontend/TabContentsScripts/DownloadContentScript.swift`,
`Frontend/Browser/OpenInHelper/OpenPassBookHelper.swift`,
`TabManagement/Document/TemporaryDocument.swift`,
`TemporaryDocumentBackForwardListItem.swift`.

Needs Gecko's external-response path (`GeckoView:ExternalResponse` arrives, but
the iOS handler ignores it). For M3, Gecko handles a download however it does by
default, and Fennec's download UI doesn't appear.

### Logins, autofill, password generation, Relay (Stub)

`Frontend/TabContentsScripts/LoginsHelper.swift`,
`FormAutofillHelper/FormAutofillHelper.swift`,
`Coordinators/CredentialAutofillCoordinator.swift`,
`AddressAutofillCoordinator.swift`,
`Frontend/PasswordGenerator/` (`PasswordGeneratorAction`, `PasswordGeneratorMiddleware`,
`PasswordGeneratorScriptEvaluator`, `PasswordGeneratorViewController`), `Frontend/Browser/RelayController.swift`,
`Frontend/Autofill/Address/Edit/EditAddressWebViewManager.swift`.

All of these are user-script based. Gecko's equivalent is the
`GeckoViewAutoFill` actor, which is not wired on iOS.

### JS dialogs, context menus, previews (Stub; channel 2)

| File                                                                                                              | Note                                                                                                       |
| ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `Frontend/Browser/BrowserPrompts.swift`                                                                           | `alert`, `confirm`, `prompt` UI for `WKUIDelegate`                                                         |
| `…/Actions/WebContextMenuActionsProvider.swift`                                                                   | long-press menu actions                                                                                    |
| `Frontend/Browser/Tabs/Views/TabPeekViewController.swift`, `Frontend/Browser/BackForwardListViewController.swift` | peek preview, long-press-Back history list. The history list could come from Gecko's `StateUpdated` later. |
| `Frontend/AutoplayAccessors.swift`                                                                                | maps a pref to `WKAudiovisualMediaTypes`                                                                   |

**Risk:** I don't know how Gecko on iOS behaves when a page calls `alert()`
and no prompter module is enabled. If it blocks, that will show up in the M3
proof run on real sites. The fix would be to register the Prompter module from
our own Swift file.

### Translations and Summarize (Stub)

- **Translations** (8 files under `Frontend/Translations/`):
  - `Engine/Bridge`, `BridgeEndpoint`, `TranslationsEngine` and `WebViewBridgeEndpoint`
  - `LanguageDetector/LanguageDetector` and `WebViewLanguageSampleSource`
  - `SchemeHandler/TranslationsSchemeHandler`
  - `Service/TranslationsService`
  - `TranslationsPageStateHelper`
- **Summarize** (`Frontend/Summarizer/` `SummarizeAction`, `SummarizeMiddleware`,
  `SummarizerConfigProvider`, plus `Coordinators/SummarizeCoordinator.swift`)

Both read and rewrite the page DOM through scripts. The translation engine
itself runs in a private hidden `WKWebView`, which can stay. Reading the page
can't, so both are stubbed.

### Telemetry and web compat (Stub)

`Telemetry/AdsTelemetryHelper.swift`, `Telemetry/SearchTelemetry.swift`,
`Frontend/Browser/WebCompat/WebCompatPageContextReader.swift`,
`WebCompatReportDataCollector.swift`.

### Website data, cookies, clearing history (Stub; must not crash)

`Frontend/Settings/Clearables.swift`,
`Frontend/Settings/WebsiteDataManagement/WebsiteDataManagementViewModel.swift`,
`WebsiteDataSearchResultsViewController.swift`,
`Frontend/Library/ClearHistorySheetProvider.swift`,
`Frontend/Library/HistoryPanel/HistoryPanel.swift`,
`Utils/HistoryDeletionUtility.swift`, `Application/UITestAppDelegate.swift`.

These clear `WKWebsiteDataStore`. In Gecko mode that clears nothing in Gecko's
profile: "Clear private data" will look like it worked but won't touch Gecko's
cookies or cache. That's acceptable for a dev build, but it has to be written
down, and it ties into decision 2.

### Screenshots, share, print (Slice for screenshots, Stub for the rest)

| File                                                          | Note                                                                                                                                          |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `Frontend/Browser/ScreenshotHelper.swift`                     | `takeSnapshot`. The tab tray needs _something_: in M3, a UIKit snapshot of the Gecko view, or no thumbnail if Gecko's layer doesn't snapshot. |
| `Frontend/Share/ShareManager.swift`, `HomePageActivity.swift` | print formatter, Add to Home Screen activity (a `WKWebView` subclass by Apple's requirement)                                                  |

### Private `WKWebView`s that aren't tabs (Keep WebKit)

`Frontend/Settings/SettingsContentViewController.swift`,
`Frontend/Onboarding/Views/PrivacyPolicyViewController.swift`,
`Frontend/Browser/TermsOfUse/View/TermsOfUseLinkViewController.swift`,
`Frontend/Autofill/Address/Edit/EditAddressViewController.swift`,
`Coordinators/GoogleLensInterstitialCoordinator.swift`.

These show Mozilla pages in their own web view. There's no reason to move them.

### `import WebKit` with no WebKit use (no change)

`Frontend/AuthenticationManager/AppAuthenticator.swift`,
`Frontend/Browser/TopTabsViewController.swift`,
`Frontend/Browser/RecordVisitObservationManager.swift`,
`Helpers/UserActivityHandler.swift`.

`Frontend/Summarizer/SummarizerConfigProvider.swift` also has no WebKit use; it's
listed with Summarize above. These imports are stale, so leave them alone.

## 4. The slice

### 4.1 Shape: Tab gets an `EngineSession`, and the `WKWebView` stays as a dormant shell

The tempting move is to change `Tab.webView`'s type. That touches 146
references in 51 files, and every one of them is a feature M3 stubs anyway.
Instead:

- `Tab` gains `engineSession: EngineSession?` and `engineView: EngineView?`,
  created from the `Engine` (M2's `GeckoEngine`) when the tab would create its
  web view. They're typed as **WebEngine protocols, not Gecko classes**. Client
  code added in M3 never names Gecko, so it also nudges Client toward the
  existing abstraction, which is the long-term direction anyway.
- In Gecko mode, `Tab.createWebview` **still creates the `TabWebView`**, but
  never loads anything into it and never shows it. All the code that keys on
  `tab.webView != nil` ("this tab is live, not lazily restored") keeps working
  unchanged. So do the 15 content scripts BVC installs: they attach to a web view
  that never loads a page, so they never fire. The cost is one idle
  WebKit view per open tab. That's fine for a dev build, and it goes away later
  as features move over.
- The members of `Tab` that the toolbar and tab tray read get routed in Gecko
  mode:
  - `url` is fed from `onLocationChange`
  - `title`, `isLoading`, `estimatedProgress`, `canGoBack`, `canGoForward`
  - `loadRequest`, `goBack`, `goForward`, `reload`, `stop`

  These members already exist, so call sites don't change.

- `WebviewViewController` hosts `tab.engineView` instead of the `WKWebView` (it
  takes a `UIView`; one `#if`).
- BVC's KVO handlers (`handleURL`, `handleTitleChanged`,
  `handleEstimatedProgress`, `handleLoading`, `handleCanGoBack/ForwardChanged`) get
  called from an `EngineSessionDelegate` adapter instead of from KVO. Two of
  them take a `webView:` parameter they only use to read `url` and
  `estimatedProgress`; those become a `Tab` read. This is a small refactor that
  also works for WebKit mode.
- **Homepage and `internal://` URLs never go to Gecko.** Fennec's homepage is
  native UI above a web view loaded with `internal://local/about/home` through
  a scheme handler. In Gecko mode, `Tab.loadRequest` sees an `InternalURL`, sets
  `tab.url`, and doesn't load anything. BVC's existing
  `updateInContentHomePanel` then shows the native homepage, just as it does
  today.
- **Navigation policy:** the adapter's `onLoadRequest` allows `http`, `https`,
  `about`, `data` and `blob`. It sends `tel:`, `mailto:` and App Store links to
  `UIApplication.open` the way the WebKit path does, and denies everything else.
  That reuses the small URL-classification helpers at the bottom of the
  delegates file. The other 1,700 lines (downloads, popups, auth, server trust)
  stay WebKit-only.
- **New windows** (`target=_blank`, `window.open`): `onNewSession` opens a new
  Fennec tab with the URL. M2 returned `nil`, so these links did nothing.

### 4.2 Session restore

`TabManagerImplementation` saves `webView.interactionState`, an opaque WebKit
blob. In Gecko mode the plan is:

- **M3:** restore tabs from `tab.url` only. Each restored tab reloads its last
  page and loses its back/forward history. Fennec already stores the tab's URL
  separately, so this is a branch in `Tab.restore`.
- **Next:** finish the `StateUpdated` TODO with our own Swift file in the
  GeckoView target, store Gecko's JSON as the tab's session data, and send it
  back with `GeckoView:RestoreState`. WebEngine's `restore(state: Data)` is
  already the right shape for it.

### 4.3 Launch: who owns the app delegate

Gecko's `nsAppShell::Run` calls
`UIApplicationMain(1, argv, nil, @"AppShellDelegate")` (`widget/uikit/nsAppShell.mm:286`).
SampleBrowserGecko got around that by listening for
`didFinishLaunchingNotification`. Fennec can't, because its `AppDelegate` does
real delegate work:

- `willFinish` and `didFinishLaunching` with launch options
- background-task registration
- the scene configuration callback
- push-token callbacks
- orientation lock
- `buildMenu`

Notifications don't cover push tokens or orientation locking. That's
**decision 1** below.

### 4.4 Build plumbing: no pbxproj edits

Fennec's targets live in `Client.xcodeproj`, a 33k-line pbxproj that can't be
regenerated. The proposal:

- **One upstream line**: an optional include at the end of
  `Client/Configuration/Fennec.xcconfig`:
  `#include? "../../../gecko-port/FennecGecko/Gecko.xcconfig"`.
- **`Gecko.xcconfig`** applies nothing unless `GECKO_ENGINE_BUILD=YES` is passed,
  using the `$(VAR_$(SWITCH))` trick. Turned on, it adds `-DGECKO_ENGINE` and
  the framework and library search paths and link flags for Client only. A
  plain Fennec build is byte-for-byte unaffected.
- **`gecko-port/FennecGecko/project.yml`** (xcodegen, like SampleBrowserGecko)
  builds:
  - `GeckoView.framework` (from Gecko source, plus our extension files)
  - the `GeckoEngine` static library
  - the three BrowserEngineKit extensions, with Fennec bundle IDs
- **`gecko-port/FennecGecko/build.sh`**:
  1. builds that project
  2. builds Fennec with `GECKO_ENGINE_BUILD=YES`
  3. copies `GeckoView.framework`, `XUL` and the extensions into `Fennec.app`
  4. re-signs ad-hoc with the BrowserEngineKit entitlements added for the simulator
- **`GeckoEngine` moves into the WebEngine package as an opt-in target?** No:
  it would need XUL to link. It stays a static library that imports
  `WebEngine`.

  **Risk:** the static library is compiled against one build of the WebEngine
  module and Client against another. They come from identical sources, so it
  should link. If it doesn't, the fallback is to compile `GeckoEngine`'s three
  files straight into Client through the xcconfig's search paths. That would
  take some care, but it's still no pbxproj edit.

### 4.5 What M3 does _not_ do

There's no change to WebKit-mode behaviour, and no feature from the Stub groups
is ported. There's also no WebExtension bridge, no device build (that's M4),
and no Gecko patch, unless decision 1 picks one.

### 4.6 Proof

These are the M2 steps, driven by SimDriver against Fennec:

1. type a Wikipedia URL in the address bar
2. load `engine.html`, which shows **GECKO**
3. follow the link
4. tap Back

Plus three tab checks:

- open a second tab, load something else, and switch between them; each keeps
  its page
- close a tab
- relaunch and see the tabs come back (URL only)

Then the control: a plain WebKit Fennec build shows NOT GECKO, and its unit
tests still pass.

Estimated upstream footprint, in Gecko mode only: about 10 files touched
(`Tab`, `TabManagerImplementation`, `WebviewViewController`, BVC and its
delegates, `ScreenshotHelper`, `main.swift`, `Fennec.xcconfig`), each with
small `#if GECKO_ENGINE` branches. New code goes in `gecko-port/FennecGecko/`
and `BrowserKit/Sources/GeckoEngine/`.

## Decisions for Eric

1. **The app delegate.** Gecko hard-codes `AppShellDelegate`.
   - **(a) Recommended:** a small Gecko patch on local branch `ios-gecko-engine`.
     `nsAppShell::Run` reads the delegate class name from an Info.plist key
     (falling back to `AppShellDelegate`). `ApplicationWillTerminate` and the
     memory-pressure call become exported C functions that Fennec's
     `AppDelegate` calls from its own `applicationWillTerminate` and
     memory-warning methods. That's about 20 lines, logged in RESULT.md, and
     Fennec's `AppDelegate` stays fully intact. The cost: we now carry a
     Gecko patch to rebase.
   - **(b)** No Gecko patch. Before launch, use the Objective-C runtime to add
     Fennec's `AppDelegate` methods to `AppShellDelegate` and chain the three
     methods both implement. That works, but it's swizzling: fragile, and
     confusing to read later.
   - **(c)** Notifications only, like SampleBrowserGecko. This loses push-token
     callbacks, orientation lock and the menu builder. It's the least work and
     the most broken.
2. **Private tabs.** I couldn't find where iOS Gecko marks a session as
   private. The Android path sets it when the window opens, and the iOS
   `open()` settings have no such key. Without it, a "private" tab in Gecko
   mode would write normal history and cookies, and Clear Data can't wipe
   Gecko's profile anyway (section 3).
   - **Recommended:** in Gecko mode, private tabs use WebKit (the dormant web
     view, made live), so private browsing keeps working and stays private.
     Only normal tabs use Gecko.
   - Alternative: hide private browsing in Gecko builds.
3. **The dormant `WKWebView` per tab** (4.1) versus giving tabs no web view at
   all in Gecko mode. Dormant is much less code. No web view at all is cleaner,
   but it means auditing every `webView == nil` check (lazy restore, popups,
   tab offload).
   - **Recommended:** dormant.
4. **Build plumbing** (4.4): an optional `#include?` in `Fennec.xcconfig` plus a
   build script, or a real `FennecGecko` target added to `Client.xcodeproj`.
   - **Recommended:** the xcconfig. It's one upstream line instead of hundreds
     of pbxproj lines.

Once you've decided these, M3 is built in this order:

1. launch (decision 1)
2. the build plumbing, proven with an empty Gecko build of Fennec
3. Tab routing
4. BVC events
5. tabs and restore
6. the proof run

Each step gets its own commit.
