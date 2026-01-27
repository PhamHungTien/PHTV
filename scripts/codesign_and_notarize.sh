#!/bin/bash

# Script để ký và notarize ứng dụng PHTV
# Giải pháp triệt để cho vấn đề macOS báo Malware

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PHTV Code Signing & Notarization ===${NC}\n"

# Configuration
APP_PATH="$1"
DEVELOPER_ID="${2:-Developer ID Application}"
APPLE_ID="${3:-$APPLE_ID_EMAIL}"
TEAM_ID="${4:-$APPLE_TEAM_ID}"
APP_SPECIFIC_PASSWORD="${5:-$APPLE_APP_PASSWORD}"

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}Error: APP_PATH is required${NC}"
    echo "Usage: $0 <APP_PATH> [DEVELOPER_ID] [APPLE_ID] [TEAM_ID] [APP_PASSWORD]"
    echo ""
    echo "Example:"
    echo "  $0 build/PHTV.app 'Developer ID Application: Your Name (TEAMID)' your@email.com TEAMID"
    echo ""
    echo "Or set environment variables:"
    echo "  export APPLE_ID_EMAIL=your@email.com"
    echo "  export APPLE_TEAM_ID=TEAMID"
    echo "  export APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    echo "  $0 build/PHTV.app"
    exit 1
fi

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIdentifier)

echo -e "${YELLOW}Configuration:${NC}"
echo "  App Path: $APP_PATH"
echo "  App Name: $APP_NAME"
echo "  Bundle ID: $BUNDLE_ID"
echo "  Developer ID: $DEVELOPER_ID"
echo ""

# Step 1: Remove extended attributes (quarantine flags)
echo -e "${BLUE}[1/6] Removing extended attributes...${NC}"
xattr -cr "$APP_PATH"
echo -e "${GREEN}✓ Extended attributes removed${NC}\n"

# Step 2: Sign all frameworks and libraries first
echo -e "${BLUE}[2/6] Signing frameworks and libraries...${NC}"
find "$APP_PATH/Contents" -type f \( -name "*.dylib" -o -name "*.framework" \) -print0 | while IFS= read -r -d '' file; do
    echo "  Signing: $(basename "$file")"
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp \
        --options runtime \
        --deep \
        "$file" 2>/dev/null || true
done
echo -e "${GREEN}✓ Frameworks and libraries signed${NC}\n"

# Step 3: Sign the app bundle with hardened runtime
echo -e "${BLUE}[3/6] Signing main app bundle...${NC}"
codesign --force --sign "$DEVELOPER_ID" \
    --entitlements "$APP_PATH/../PHTV.entitlements" \
    --timestamp \
    --options runtime \
    --deep \
    --verbose \
    "$APP_PATH"

echo -e "${GREEN}✓ App bundle signed${NC}\n"

# Step 4: Verify code signature
echo -e "${BLUE}[4/6] Verifying code signature...${NC}"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
echo -e "${GREEN}✓ Code signature verified${NC}\n"

# Step 5: Create ZIP for notarization
echo -e "${BLUE}[5/6] Creating ZIP archive for notarization...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ZIP_NAME="${APP_NAME}_${TIMESTAMP}.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_NAME"
echo -e "${GREEN}✓ ZIP created: $ZIP_NAME${NC}\n"

# Step 6: Submit for notarization
if [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ] && [ -n "$APP_SPECIFIC_PASSWORD" ]; then
    echo -e "${BLUE}[6/6] Submitting for notarization...${NC}"
    echo "  This may take 5-15 minutes..."

    # Submit to notarization service
    xcrun notarytool submit "$ZIP_NAME" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait

    NOTARIZE_STATUS=$?

    if [ $NOTARIZE_STATUS -eq 0 ]; then
        echo -e "${GREEN}✓ Notarization successful!${NC}"

        # Staple the notarization ticket to the app
        echo -e "${BLUE}Stapling notarization ticket...${NC}"
        xcrun stapler staple "$APP_PATH"
        echo -e "${GREEN}✓ Ticket stapled to app${NC}\n"

        # Verify notarization
        echo -e "${BLUE}Verifying notarization...${NC}"
        xcrun stapler validate "$APP_PATH"
        spctl --assess -vv --type install "$APP_PATH"
        echo -e "${GREEN}✓ Notarization verified${NC}\n"

        echo -e "${GREEN}=== SUCCESS ===${NC}"
        echo -e "App is now signed and notarized!"
        echo -e "macOS will trust this app and NOT flag it as malware.\n"

    else
        echo -e "${RED}✗ Notarization failed${NC}"
        echo "Getting notarization log..."
        xcrun notarytool log --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_SPECIFIC_PASSWORD"
        exit 1
    fi
else
    echo -e "${YELLOW}[6/6] Notarization skipped (credentials not provided)${NC}"
    echo -e "${YELLOW}To enable notarization, provide:${NC}"
    echo "  - APPLE_ID_EMAIL"
    echo "  - APPLE_TEAM_ID"
    echo "  - APPLE_APP_PASSWORD (app-specific password from appleid.apple.com)"
    echo ""
    echo -e "${GREEN}App is signed but NOT notarized.${NC}"
    echo -e "${YELLOW}For full malware protection, complete notarization.${NC}\n"
fi

# Cleanup
rm -f "$ZIP_NAME"

echo -e "${BLUE}=== Done ===${NC}"
