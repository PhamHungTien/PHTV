#!/bin/bash
# Create DMG for PHTV release
# Usage: ./create_dmg.sh [version]

set -e

# Get version from Info.plist if not provided
if [ -z "$1" ]; then
    VERSION=$(defaults read "$(pwd)/PHTV/Info.plist" CFBundleShortVersionString 2>/dev/null)
    if [ -z "$VERSION" ]; then
        echo "Error: Could not read version from Info.plist"
        exit 1
    fi
else
    VERSION="$1"
fi

echo "================================"
echo "PHTV DMG Builder"
echo "================================"
echo "Version: $VERSION"
echo ""

# Build paths
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/PHTV-epinbnlkxirxlwftmlcslwkdwqjs/Build/Products/Release"
APP_PATH="$BUILD_DIR/PHTV.app"
DMG_NAME="PHTV-$VERSION.dmg"
DMG_PATH="$HOME/Desktop/$DMG_NAME"
TEMP_DMG="$HOME/Desktop/temp-PHTV.dmg"
VOLUME_NAME="PHTV"

# Clean old DMG
if [ -f "$DMG_PATH" ]; then
    echo "Removing old DMG..."
    rm "$DMG_PATH"
fi

if [ -f "$TEMP_DMG" ]; then
    rm "$TEMP_DMG"
fi

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: PHTV.app not found at $APP_PATH"
    echo "Please build the app first with:"
    echo "  xcodebuild -scheme PHTV -configuration Release clean build"
    exit 1
fi

echo "✓ Found PHTV.app"

# Verify code signature
echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH" || {
    echo "Warning: App is not properly code signed"
    echo "Continuing anyway..."
}

# Create temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo "✓ Created temp directory: $TEMP_DIR"

# Copy app to temp directory
echo "Copying PHTV.app..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$TEMP_DIR/Applications"

echo "✓ DMG contents ready"
echo ""

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
               -srcfolder "$TEMP_DIR" \
               -ov \
               -format UDZO \
               -imagekey zlib-level=9 \
               "$TEMP_DMG"

echo "✓ DMG created"

# Convert to final DMG
echo "Converting to final DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH"
rm "$TEMP_DMG"

echo "✓ Converted to final format"

# Clean up temp directory
rm -rf "$TEMP_DIR"
echo "✓ Cleaned up temp files"
echo ""

# Get file size and checksum
FILE_SIZE=$(stat -f%z "$DMG_PATH")
CHECKSUM=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

echo "================================"
echo "✅ DMG created successfully!"
echo "================================"
echo ""
echo "Location: $DMG_PATH"
echo "Size: $FILE_SIZE bytes ($(echo "scale=2; $FILE_SIZE/1024/1024" | bc) MB)"
echo "SHA-256: $CHECKSUM"
echo ""
echo "================================"
echo "Next steps:"
echo "================================"
echo "1. Test the DMG:"
echo "   - Mount it and verify Applications symlink"
echo "   - Drag PHTV.app to Applications"
echo "   - Launch and test basic functionality"
echo ""
echo "2. Sign the update package:"
echo "   ./scripts/sign_update.sh \"$DMG_PATH\""
echo ""
echo "3. Create GitHub release:"
echo "   - Tag: v$VERSION"
echo "   - Upload DMG"
echo "   - Add release notes"
echo ""
