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
