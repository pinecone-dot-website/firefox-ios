#!/bin/zsh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Builds Fennec on Gecko for the iOS Simulator:
#   1. the Gecko pieces in this folder (GeckoView framework, libGeckoEngine.a, extensions),
#   2. Fennec from Client.xcodeproj with GECKO_ENGINE_BUILD=YES,
#   3. copies GeckoView and the extensions into the app and re-signs it.
# Needs mozilla-firefox/obj-ios-sim (M1) built from the ios-gecko-engine branch.
# Usage: build.sh [simulator-udid]. Prints the app path last.

set -euo pipefail

HERE=${0:A:h}
ROOT=${HERE:h:h}
SIM=${1:-D30C6397-DF3A-4D34-ACB7-3E4C9DF97F02}
DEST="platform=iOS Simulator,id=$SIM"
FLAGS=(-skipMacroValidation -skipPackagePluginValidation -quiet)

cd "$HERE"
xcodegen generate -q
xcodebuild -project FennecGecko.xcodeproj -scheme FennecGecko -configuration Debug \
    -destination "$DEST" -derivedDataPath build "${FLAGS[@]}" build

xcodebuild -project "$ROOT/firefox-ios/Client.xcodeproj" -scheme Fennec -configuration Debug \
    -destination "$DEST" -derivedDataPath build/Fennec "${FLAGS[@]}" \
    GECKO_ENGINE_BUILD=YES build

PRODUCTS=build/Build/Products/Debug-iphonesimulator
APP=build/Fennec/Build/Products/Debug-iphonesimulator/Client.app

rsync -a --delete "$PRODUCTS/GeckoView.framework" "$APP/Frameworks/"
mkdir -p "$APP/Extensions"
for ext in WebContent Networking Rendering; do
    rsync -a --delete "$PRODUCTS/$ext.appex" "$APP/Extensions/"
done
codesign --force --sign - --preserve-metadata=entitlements "$APP"

echo "${APP:A}"
