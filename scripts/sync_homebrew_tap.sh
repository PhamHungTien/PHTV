#!/bin/bash
# Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
#
# Sync updated Homebrew formula to tap repository
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FORMULA_PATH="$PROJECT_DIR/homebrew/phtv.rb"

# Tap repository location (modify this if your tap repo is elsewhere)
TAP_REPO="${TAP_REPO:-$HOME/Documents/homebrew-tap}"
TAP_FORMULA_PATH="$TAP_REPO/Casks/phtv.rb"

echo -e "${BLUE}PHTV Homebrew Tap Sync${NC}"
echo "======================================"
echo ""

# Check if formula exists
if [ ! -f "$FORMULA_PATH" ]; then
    echo -e "${RED}Error: Formula not found at $FORMULA_PATH${NC}"
    exit 1
fi

# Get version from formula
VERSION=$(grep -m 1 'version "' "$FORMULA_PATH" | sed 's/.*version "\(.*\)".*/\1/')
echo -e "Formula version: ${YELLOW}$VERSION${NC}"

# Check if tap repository exists
if [ ! -d "$TAP_REPO" ]; then
    echo -e "${YELLOW}Warning: Tap repository not found at $TAP_REPO${NC}"
    echo ""
    echo "Options:"
    echo "1. Create tap repository first:"
    echo "   ${BLUE}gh repo create phamhungtien/homebrew-tap --public${NC}"
    echo ""
    echo "2. Clone existing tap repository:"
    echo "   ${BLUE}cd ~/Documents && git clone https://github.com/phamhungtien/homebrew-tap.git${NC}"
    echo ""
    echo "3. Specify custom tap location:"
    echo "   ${BLUE}TAP_REPO=/path/to/tap $0${NC}"
    exit 1
fi

echo "Tap repository: $TAP_REPO"

# Create Casks directory if it doesn't exist
mkdir -p "$TAP_REPO/Casks"

# Check if tap repo is a git repository
if [ ! -d "$TAP_REPO/.git" ]; then
    echo -e "${RED}Error: $TAP_REPO is not a git repository${NC}"
    exit 1
fi

# Copy formula to tap repository
echo ""
echo "Copying formula to tap repository..."
cp "$FORMULA_PATH" "$TAP_FORMULA_PATH"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Formula copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy formula${NC}"
    exit 1
fi

# Check if there are changes
cd "$TAP_REPO"

if git diff --quiet Casks/phtv.rb; then
    echo -e "${YELLOW}No changes detected in formula${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Changes detected!${NC}"
echo ""

# Show diff
echo "Diff:"
git diff Casks/phtv.rb

echo ""
echo "Committing changes..."

# Commit changes
git add Casks/phtv.rb

if git diff --staged --quiet; then
    echo -e "${YELLOW}No staged changes${NC}"
    exit 0
fi

# Create commit message
COMMIT_MSG="chore: update PHTV to v$VERSION"

git commit -m "$COMMIT_MSG"

echo -e "${GREEN}✓ Changes committed${NC}"
echo ""

# Check if auto-push mode is enabled
if [ "$AUTO_PUSH" = "yes" ] || [ "$AUTO_PUSH" = "true" ]; then
    SHOULD_PUSH=true
else
    # Ask to push
    read -p "Push changes to remote? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SHOULD_PUSH=true
    else
        SHOULD_PUSH=false
    fi
fi

if [ "$SHOULD_PUSH" = true ]; then
    echo "Pushing to remote..."
    git push origin main || git push origin master

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Changes pushed successfully!${NC}"
        echo ""
        echo "Users can now update PHTV via:"
        echo -e "${BLUE}brew update && brew upgrade --cask phtv${NC}"
    else
        echo -e "${RED}✗ Failed to push changes${NC}"
        echo "You can manually push later with: cd $TAP_REPO && git push"
        exit 1
    fi
else
    echo -e "${YELLOW}Changes committed but not pushed${NC}"
    echo "You can manually push later with:"
    echo -e "${BLUE}cd $TAP_REPO && git push${NC}"
fi

echo ""
echo -e "${GREEN}✓ Sync complete!${NC}"
