#!/bin/bash
# Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
#
# Master script for complete Homebrew release automation
# Runs: update formula → commit → sync tap → push
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${MAGENTA}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     PHTV Homebrew Release Automation v1.0           ║"
echo "║     Complete workflow: Update → Commit → Sync       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get version from Info.plist
INFO_PLIST="$PROJECT_DIR/PHTV/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")

if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ Error: Could not read version from Info.plist${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Version: ${YELLOW}$VERSION${NC}"
echo ""

# Check if DMG exists
DMG_PATH="$PROJECT_DIR/Releases/$VERSION/PHTV-$VERSION.dmg"
if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}❌ Error: DMG file not found at $DMG_PATH${NC}"
    echo ""
    echo "Please build and create the DMG first using:"
    echo -e "${BLUE}  xcodebuild -project PHTV.xcodeproj -configuration Release${NC}"
    echo -e "${BLUE}  # Then create DMG${NC}"
    exit 1
fi

echo -e "${GREEN}✓ DMG file found${NC}"
echo ""

# Step 1: Update formula
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1/4: Updating Homebrew formula${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if "$SCRIPT_DIR/update_homebrew.sh"; then
    echo -e "${GREEN}✓ Formula updated successfully${NC}"
else
    echo -e "${RED}❌ Failed to update formula${NC}"
    exit 1
fi

echo ""

# Step 2: Check git status
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2/4: Committing formula changes${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd "$PROJECT_DIR"

# Check if there are changes
if git diff --quiet homebrew/phtv.rb; then
    echo -e "${YELLOW}⚠ No changes detected in formula${NC}"
else
    echo "Changes detected:"
    git diff homebrew/phtv.rb
    echo ""

    # Commit changes
    git add homebrew/phtv.rb
    git commit -m "chore: update homebrew formula to v$VERSION"

    echo -e "${GREEN}✓ Formula committed${NC}"
fi

echo ""

# Step 3: Push to main repo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3/4: Pushing to main repository${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if git push origin main; then
    echo -e "${GREEN}✓ Pushed to main repository${NC}"
else
    echo -e "${RED}❌ Failed to push to main repository${NC}"
    exit 1
fi

echo ""

# Step 4: Sync with tap
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4/4: Syncing with Homebrew tap${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if tap repo exists
TAP_REPO="${TAP_REPO:-$HOME/Documents/homebrew-tap}"

if [ ! -d "$TAP_REPO" ]; then
    echo -e "${YELLOW}⚠ Tap repository not found at $TAP_REPO${NC}"
    echo ""
    echo "Skipping tap sync. To sync manually later:"
    echo -e "${BLUE}  ./scripts/sync_homebrew_tap.sh${NC}"
else
    # Auto-push to tap
    export AUTO_PUSH=yes

    if "$SCRIPT_DIR/sync_homebrew_tap.sh"; then
        echo -e "${GREEN}✓ Synced with tap repository${NC}"
    else
        echo -e "${RED}❌ Failed to sync tap${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Release automation completed successfully! ✨${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓ Homebrew formula updated to v$VERSION${NC}"
echo -e "${GREEN}✓ Changes committed and pushed${NC}"
echo -e "${GREEN}✓ Tap repository synchronized${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Create GitHub Release:"
echo -e "   ${YELLOW}gh release create v$VERSION \\${NC}"
echo -e "   ${YELLOW}  --title \"PHTV v$VERSION\" \\${NC}"
echo -e "   ${YELLOW}  --notes-file CHANGELOG.md \\${NC}"
echo -e "   ${YELLOW}  \"$DMG_PATH\"${NC}"
echo ""
echo "2. Users can now update PHTV via:"
echo -e "   ${BLUE}brew update && brew upgrade --cask phtv${NC}"
echo ""
