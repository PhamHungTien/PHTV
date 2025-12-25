#!/bin/bash
# Sign update package for Sparkle
# Usage: ./sign_update.sh <path-to-dmg>

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path-to-dmg>"
    echo "Example: $0 ~/Desktop/PHTV-1.2.5.dmg"
    exit 1
fi

DMG_PATH="$1"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG file not found: $DMG_PATH"
    exit 1
fi

echo "================================"
echo "PHTV Update Package Signing"
echo "================================"
echo ""

# Find Sparkle binaries
SPARKLE_BIN_PATHS=(
    "$HOME/Downloads/Sparkle-for-Swift-Package-Manager/bin"
    "$HOME/Desktop/Sparkle-for-Swift-Package-Manager/bin"
    "/tmp/Sparkle-for-Swift-Package-Manager/bin"
)

SPARKLE_BIN=""
for path in "${SPARKLE_BIN_PATHS[@]}"; do
    if [ -d "$path" ] && [ -f "$path/sign_update" ]; then
        SPARKLE_BIN="$path"
        break
    fi
done

if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle binaries not found!"
    echo ""
    echo "Please download Sparkle first:"
    echo "  cd /tmp"
    echo "  curl -LO https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip"
    echo "  unzip Sparkle-for-Swift-Package-Manager.zip"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✓ Found Sparkle at: $SPARKLE_BIN"
echo ""

# Get version from DMG
echo "Mounting DMG..."
hdiutil attach "$DMG_PATH" -nobrowse -quiet
MOUNT_POINT="/Volumes/PHTV"

if [ ! -d "$MOUNT_POINT" ]; then
    # Try alternative mount point
    MOUNT_POINT=$(hdiutil info | grep "PHTV" | awk '{print $1}' | head -1)
    if [ -z "$MOUNT_POINT" ]; then
        echo "Error: Could not find mounted DMG"
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
        exit 1
    fi
fi

APP_PATH="$MOUNT_POINT/PHTV.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: PHTV.app not found in DMG"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
BUILD=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null)

if [ -z "$VERSION" ]; then
    echo "Error: Could not read version from Info.plist"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

echo "✓ Version: $VERSION"
echo "✓ Build: $BUILD"

hdiutil detach "$MOUNT_POINT" -quiet

# Get file size
FILE_SIZE=$(stat -f%z "$DMG_PATH")
echo "✓ File size: $FILE_SIZE bytes"
echo ""

# Sign DMG with Apple Developer certificate
echo "Signing DMG with Apple Developer certificate..."
codesign --force --deep --sign "Apple Development" "$DMG_PATH" 2>/dev/null || {
    echo "Warning: Code signing failed (certificate not found or invalid)"
    echo "Make sure you have 'Apple Development: hungtien4944@icloud.com' certificate in Keychain"
    echo "The DMG will not be code-signed, but EdDSA signature will still be generated."
    echo ""
}

# Generate EdDSA signature for Sparkle
echo "Generating EdDSA signature..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>/dev/null)

if [ -z "$SIGNATURE" ]; then
    echo "Error: Failed to generate EdDSA signature"
    echo "Make sure you have generated Sparkle keys with:"
    echo "  $SPARKLE_BIN/generate_keys"
    exit 1
fi

echo "✓ EdDSA signature generated"
echo ""

# Get current date in RFC 822 format
PUBDATE=$(date -R 2>/dev/null || date '+%a, %d %b %Y %H:%M:%S %z')

# Output results
echo "================================"
echo "✅ Signed update package ready!"
echo "================================"
echo ""
echo "Version: $VERSION"
echo "Build: $BUILD"
echo "File size: $FILE_SIZE bytes"
echo "Signature: $SIGNATURE"
echo ""
echo "================================"
echo "Add this to appcast.xml:"
echo "================================"
echo ""
cat << EOF
<item>
    <title>PHTV $VERSION</title>
    <link>https://github.com/PhamHungTien/PHTV/releases/tag/v$VERSION</link>
    <sparkle:version>$BUILD</sparkle:version>
    <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
    <description><![CDATA[
        <h3>Tính năng mới</h3>
        <ul>
            <li>TODO: Add release notes here</li>
        </ul>
    ]]></description>
    <pubDate>$PUBDATE</pubDate>
    <enclosure
        url="https://github.com/PhamHungTien/PHTV/releases/download/v$VERSION/PHTV-$VERSION.dmg"
        sparkle:version="$BUILD"
        sparkle:shortVersionString="$VERSION"
        sparkle:edSignature="$SIGNATURE"
        length="$FILE_SIZE"
        type="application/octet-stream"/>
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
</item>
EOF

echo ""
echo "================================"
echo "Next steps:"
echo "================================"
echo "1. Update docs/appcast.xml with the item above"
echo "2. Convert RELEASE_NOTES_$VERSION.md to HTML for <description>"
echo "3. Commit appcast changes: git add docs/appcast.xml && git commit"
echo "4. Create GitHub release with DMG attached"
echo "5. Tag as v$VERSION: git tag v$VERSION && git push --tags"
echo ""
