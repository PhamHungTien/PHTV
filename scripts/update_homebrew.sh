#!/bin/bash
# Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
#
# Automatically update Homebrew formula with new version
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FORMULA_PATH="$PROJECT_DIR/homebrew/phtv.rb"

echo -e "${GREEN}PHTV Homebrew Formula Updater${NC}"
echo "======================================"

# Get current version from Info.plist
INFO_PLIST="$PROJECT_DIR/PHTV/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not read version from Info.plist${NC}"
    exit 1
fi

echo -e "Current version: ${YELLOW}$VERSION${NC}"

# Find DMG file
DMG_PATH="$PROJECT_DIR/Releases/$VERSION/PHTV-$VERSION.dmg"

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}Error: DMG file not found at $DMG_PATH${NC}"
    exit 1
fi

echo "DMG file found: $DMG_PATH"

# Calculate SHA256
echo "Calculating SHA256..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

if [ -z "$SHA256" ]; then
    echo -e "${RED}Error: Could not calculate SHA256${NC}"
    exit 1
fi

echo -e "SHA256: ${YELLOW}$SHA256${NC}"

# Update formula
echo "Updating Homebrew formula..."

# Check if formula exists
if [ ! -f "$FORMULA_PATH" ]; then
    echo -e "${RED}Error: Formula not found at $FORMULA_PATH${NC}"
    exit 1
fi

# Get current version from formula
CURRENT_VERSION=$(grep -m 1 'version "' "$FORMULA_PATH" | sed 's/.*version "\(.*\)".*/\1/')

echo "Formula current version: $CURRENT_VERSION"
echo "New version: $VERSION"

if [ "$CURRENT_VERSION" == "$VERSION" ]; then
    echo -e "${YELLOW}Warning: Formula is already at version $VERSION${NC}"
    echo "Checking if SHA256 needs update..."
fi

# Create temporary file
TMP_FILE=$(mktemp)

# Read and update formula
while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*version ]]; then
        echo "  version \"$VERSION\"" >> "$TMP_FILE"
    elif [[ $line =~ ^[[:space:]]*sha256 ]]; then
        echo "  sha256 \"$SHA256\"" >> "$TMP_FILE"
    else
        echo "$line" >> "$TMP_FILE"
    fi
done < "$FORMULA_PATH"

# Replace original file
mv "$TMP_FILE" "$FORMULA_PATH"

echo -e "${GREEN}Formula updated successfully!${NC}"

# Run style check
echo "Running style check..."
if brew style --fix "$FORMULA_PATH" 2>&1 | grep -q "offenses detected"; then
    echo -e "${YELLOW}Style issues detected and fixed${NC}"
fi

# Verify syntax
echo "Verifying Ruby syntax..."
if ruby -c "$FORMULA_PATH" > /dev/null 2>&1; then
    echo -e "${GREEN}Syntax OK${NC}"
else
    echo -e "${RED}Syntax error in formula${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Homebrew formula updated successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the changes: cat $FORMULA_PATH"
echo "2. Commit the changes: git add $FORMULA_PATH && git commit -m 'chore: update homebrew formula to v$VERSION'"
echo "3. Push to remote: git push origin main"
echo ""
echo "To publish to Homebrew Cask:"
echo "1. Create a tap repository: homebrew-phtv"
echo "2. Move formula to Casks/ directory in tap repo"
echo "3. Users can install via: brew install phamhungtien/phtv/phtv"
