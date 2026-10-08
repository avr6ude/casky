#!/bin/sh
# Builds Casky, signs it with Developer ID, notarizes, and packages a DMG.
#
#   TEAM_ID=XXXXXXXXXX scripts/release.sh     signed + notarized release
#   scripts/release.sh --unsigned             local dry run (ad-hoc, no notarization)
#
# One-time setup for signed releases: a "Developer ID Application" certificate
# in the login keychain, and notarytool credentials stored as profile "casky":
#   xcrun notarytool store-credentials casky --apple-id <id> --team-id <team>
set -eu

cd "$(dirname "$0")/.."
unsigned=false
[ "${1:-}" = "--unsigned" ] && unsigned=true

version=$(xcodebuild -project Casky.xcodeproj -scheme Casky -showBuildSettings 2>/dev/null \
  | awk '$1 == "MARKETING_VERSION" { print $3 }')
out=build/release
dmg="$out/casky-$version.dmg"
rm -rf "$out"
mkdir -p "$out"

if $unsigned; then
  xcodebuild -project Casky.xcodeproj -scheme Casky -configuration Release \
    -derivedDataPath "$out/derived" CODE_SIGN_IDENTITY=- build -quiet
  app="$out/derived/Build/Products/Release/Casky.app"
else
  : "${TEAM_ID:?set TEAM_ID to your Apple Developer team ID}"
  xcodebuild -project Casky.xcodeproj -scheme Casky -configuration Release \
    -archivePath "$out/casky.xcarchive" archive -quiet \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application"
  cat > "$out/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$out/casky.xcarchive" -exportOptionsPlist "$out/export.plist" \
    -exportPath "$out/export" -quiet
  app="$out/export/Casky.app"
  # Notarization requires the hardened runtime.
  codesign -dv "$app" 2>&1 | grep -q 'flags=.*runtime' || { echo "Casky.app is not signed with the hardened runtime" >&2; exit 1; }
fi

# The password helper must stay executable inside the bundle.
[ -x "$app/Contents/Resources/askpass" ] || { echo "askpass helper is missing or not executable" >&2; exit 1; }

staging="$out/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname Casky -srcfolder "$staging" -ov -format UDZO "$dmg" -quiet

if ! $unsigned; then
  codesign --sign "Developer ID Application" --timestamp "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile casky --wait
  xcrun stapler staple "$dmg"
  spctl -a -t open --context context:primary-signature -vv "$dmg"
fi

echo "$dmg"
shasum -a 256 "$dmg"
