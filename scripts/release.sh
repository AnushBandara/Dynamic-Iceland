#!/bin/zsh
# Builds a Developer ID signed, notarized release and publishes it to GitHub Releases: a DMG to
# install from, and the zip + Sparkle appcast.xml the app checks for updates.
#
# One-time setup on the release Mac:
#   1. Install a "Developer ID Application" certificate in the login keychain.
#   2. xcrun notarytool store-credentials dynamic-island --apple-id <id> --team-id <team> --password <app-specific password>
#   3. The Sparkle private key in the login keychain (generate_keys -f <backup> to import it).
# Per release: bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml, commit, then
#   TEAM_ID=XXXXXXXXXX scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${TEAM_ID:?Set TEAM_ID to the Apple Developer team ID}"
NOTARY_PROFILE=${NOTARY_PROFILE:-dynamic-island}
REPO=${REPO:-oleeai/dynamic-island} # must match SUFeedURL in project.yml
VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
DIST=dist/$VERSION

IDENTITY=$(security find-identity -v -p codesigning | grep -o "Developer ID Application: .*($TEAM_ID)" | head -1)
[[ -n $IDENTITY ]] || { echo "No Developer ID Application certificate for team $TEAM_ID in the keychain" >&2; exit 1; }
git diff --quiet HEAD || { echo "Commit your changes first" >&2; exit 1; }

rm -rf "$DIST" && mkdir -p "$DIST"
xcodegen generate -q
xcodebuild -project DynamicIsland.xcodeproj -scheme DynamicIsland -configuration Release -derivedDataPath build \
    -archivePath "$DIST/DynamicIsland.xcarchive" archive \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID" -quiet

# Export re-signs Sparkle's helpers and the embedded framework with Developer ID and a timestamp.
cat > "$DIST/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>developer-id</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>Developer ID Application</string>
    <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$DIST/DynamicIsland.xcarchive" -exportPath "$DIST" \
    -exportOptionsPlist "$DIST/ExportOptions.plist" -quiet

APP=$DIST/DynamicIsland.app
DMG=$DIST/DynamicIsland-$VERSION.dmg
ZIP=$DIST/DynamicIsland-$VERSION.zip

# The DMG installs (drag to Applications); notarizing it also notarizes the app inside.
mkdir "$DIST/dmg-root"
ditto "$APP" "$DIST/dmg-root/DynamicIsland.app"
ln -s /Applications "$DIST/dmg-root/Applications"
hdiutil create -quiet -volname "Dynamic Island" -srcfolder "$DIST/dmg-root" -fs HFS+ -format UDZO "$DMG"
codesign --timestamp -s "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"
spctl --assess --type execute -v "$APP"
spctl --assess --type open --context context:primary-signature -v "$DMG"

# Sparkle updates from a zip of the stapled app. generate_appcast signs it with the Sparkle key
# from the keychain and writes appcast.xml beside it.
mkdir "$DIST/updates"
ditto -c -k --keepParent "$APP" "$DIST/updates/$(basename "$ZIP")"
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" "$DIST/updates"

git tag "v$VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" "$DMG" "$DIST/updates/"*.zip "$DIST/updates/appcast.xml" --repo "$REPO" --title "$VERSION" --generate-notes
