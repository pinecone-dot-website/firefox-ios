#!/bin/zsh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Builds Fennec on Gecko for an iPhone, signs it with a development profile and installs it.
#   1. the Gecko pieces (GeckoView framework, libGeckoEngine.a) for iphoneos,
#   2. Fennec with GECKO_ENGINE_BUILD=YES, unsigned,
#   3. assembles the app: its own bundle ID, no app extensions, no BrowserEngineKit process
#      extensions (Gecko then runs single-process, see Bridge/), Gecko's test tools stripped,
#   4. signs every binary and installs with devicectl.
# Needs mozilla-firefox/obj-ios-device built with gecko-port/mozconfig-ios-device.
#
# Environment:
#   DEVICE      device UDID (default: Eric's iPhone)
#   BUNDLE_ID   default com.rackandpinecone.FennecGecko; never a stock Firefox ID
#   PROFILE     .mobileprovision covering BUNDLE_ID (default: the team's wildcard profile)
#   IDENTITY    signing identity SHA-1 (default: first identity in PROFILE found in the keychain)
#   NO_INSTALL  set to build and sign only

set -euo pipefail

HERE=${0:A:h}
ROOT=${HERE:h:h}
DEVICE=${DEVICE:-00008150-000455420C20401C}
BUNDLE_ID=${BUNDLE_ID:-com.rackandpinecone.FennecGecko}
PROFILE=${PROFILE:-$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/d3df3aef-db7c-447b-a8c1-add1bcf923e8.mobileprovision}
FLAGS=(-skipMacroValidation -skipPackagePluginValidation -quiet)
NOSIGN=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)

case $BUNDLE_ID in
    org.mozilla.ios.Firefox*|org.mozilla.ios.FirefoxBeta*) echo "refusing stock bundle ID $BUNDLE_ID"; exit 1;;
esac

cd "$HERE"
WORK=build/device
mkdir -p "$WORK"
security cms -D -i "$PROFILE" > "$WORK/profile.plist"
TEAM=$(plutil -extract Entitlements.com\\.apple\\.developer\\.team-identifier raw -o - "$WORK/profile.plist")
if [[ -z ${IDENTITY:-} ]]; then
    IDENTITIES=$(security find-identity -v -p codesigning)
    for i in 0 1 2 3 4 5; do
        cert=$(plutil -extract DeveloperCertificates.$i raw -o - "$WORK/profile.plist" 2>/dev/null) || break
        sha=$(print -r -- "$cert" | base64 -d | shasum | cut -c1-40 | tr a-z A-Z)
        if print -r -- "$IDENTITIES" | grep -q "$sha"; then IDENTITY=$sha; break; fi
    done
fi
[[ -n ${IDENTITY:-} ]] || { echo "no signing identity for $PROFILE"; exit 1; }

xcodegen generate -q
xcodebuild -project FennecGecko.xcodeproj -scheme FennecGeckoDevice -configuration Debug \
    -destination generic/platform=iOS -derivedDataPath build "${FLAGS[@]}" EXPANDED_CODE_SIGN_IDENTITY=- build

xcodebuild -project "$ROOT/firefox-ios/Client.xcodeproj" -scheme Fennec -configuration Debug \
    -destination generic/platform=iOS -derivedDataPath build/FennecDevice "${FLAGS[@]}" "${NOSIGN[@]}" \
    GECKO_ENGINE_BUILD=YES build

PRODUCTS=build/Build/Products/Debug-iphoneos
APP=$WORK/Client.app
rsync -a --delete build/FennecDevice/Build/Products/Debug-iphoneos/Client.app/ "$APP/"
rm -rf "$APP/PlugIns" "$APP/Extensions" "$APP/_CodeSignature"
rsync -a --delete "$PRODUCTS/GeckoView.framework" "$APP/Frameworks/"

GRE=$APP/Frameworks/GeckoView.framework/Frameworks
rm -rf "$GRE"/{gtest,gmp-fake,gmp-fakeopenh264,.lldbinit,fix_stacks.py,dependentlibs.list.gtest}
for tool in BadCertAndPinningServer DelegatedCredentialsServer EncryptedClientHelloServer \
    FaultyServer GenerateOCSPResponse OCSPStaplingServer SanctionsTestServer ShowSSEConfig \
    WriteArgument ZeroRttAcceptServer certutil http3server logalloc-replay pingsender pk12util \
    ssltunnel xpcshell plugin-container; do
    rm -f "$GRE/$tool"
done
cp Prefs/fennec-single-process.js "$GRE/defaults/pref/"

plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Info.plist"
plutil -replace CFBundleDisplayName -string "Fennec Gecko" "$APP/Info.plist"
cp "$PROFILE" "$APP/embedded.mobileprovision"

cat > "$WORK/app.entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>application-identifier</key>
	<string>$TEAM.$BUNDLE_ID</string>
	<key>com.apple.developer.team-identifier</key>
	<string>$TEAM</string>
	<key>get-task-allow</key>
	<true/>
	<key>keychain-access-groups</key>
	<array>
		<string>$TEAM.$BUNDLE_ID</string>
	</array>
</dict>
</plist>
EOF

# Inside out: every Mach-O that isn't the main executable, then frameworks, then the app.
find "$APP" -type f ! -path "$APP/Client" | while read -r f; do
    if file -b "$f" | grep -q "Mach-O"; then
        codesign --force --sign "$IDENTITY" --timestamp=none "$f"
    fi
done
find "$APP" -depth -type d -name "*.framework" | while read -r fw; do
    codesign --force --sign "$IDENTITY" --timestamp=none "$fw"
done
codesign --force --sign "$IDENTITY" --timestamp=none --entitlements "$WORK/app.entitlements" "$APP"
codesign --verify --deep --strict "$APP"

if [[ -z ${NO_INSTALL:-} ]]; then
    xcrun devicectl device install app --device "$DEVICE" "$APP"
fi
echo "${APP:A}"
