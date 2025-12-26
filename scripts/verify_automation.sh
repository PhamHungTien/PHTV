#!/bin/bash
# Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
#
# Verify automation results after GitHub Actions run
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PHTV Automation Verification                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Get expected version
INFO_PLIST="PHTV/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")

echo -e "${BLUE}Expected version: ${YELLOW}$VERSION${NC}"
echo ""

# Check main repo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Main Repository (PHTV)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Pull latest
echo "Pulling latest changes..."
git pull origin main --quiet

# Check formula version
FORMULA_VERSION=$(grep -m 1 'version "' homebrew/phtv.rb | sed 's/.*version "\(.*\)".*/\1/')
echo -e "Formula version: ${YELLOW}$FORMULA_VERSION${NC}"

if [ "$FORMULA_VERSION" = "$VERSION" ]; then
    echo -e "${GREEN}✓ Formula version matches!${NC}"
else
    echo -e "${RED}✗ Formula version mismatch!${NC}"
    echo -e "  Expected: $VERSION"
    echo -e "  Got: $FORMULA_VERSION"
fi

# Check latest commit
echo ""
echo "Latest commit:"
git log -1 --oneline | head -1

COMMIT_MSG=$(git log -1 --pretty=%B | head -1)
if [[ $COMMIT_MSG == *"homebrew formula"* ]] || [[ $COMMIT_MSG == *"update"* ]]; then
    echo -e "${GREEN}✓ Recent commit looks like automation${NC}"
fi

# Check commit author
AUTHOR=$(git log -1 --pretty=%an)
echo -e "Commit author: ${YELLOW}$AUTHOR${NC}"

if [[ $AUTHOR == *"github-actions"* ]] || [[ $AUTHOR == *"Phạm Hùng Tiến"* ]]; then
    echo -e "${GREEN}✓ Author verified${NC}"
fi

echo ""

# Check tap repo
TAP_REPO="${TAP_REPO:-$HOME/Documents/homebrew-tap}"

if [ ! -d "$TAP_REPO" ]; then
    echo -e "${YELLOW}⚠ Tap repository not found at $TAP_REPO${NC}"
    echo "Skipping tap verification"
else
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Tap Repository (homebrew-tap)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    cd "$TAP_REPO"

    # Pull latest
    echo "Pulling latest changes..."
    git pull origin main --quiet

    # Check cask version
    TAP_VERSION=$(grep -m 1 'version "' Casks/phtv.rb | sed 's/.*version "\(.*\)".*/\1/')
    echo -e "Cask version: ${YELLOW}$TAP_VERSION${NC}"

    if [ "$TAP_VERSION" = "$VERSION" ]; then
        echo -e "${GREEN}✓ Tap version matches!${NC}"
    else
        echo -e "${RED}✗ Tap version mismatch!${NC}"
        echo -e "  Expected: $VERSION"
        echo -e "  Got: $TAP_VERSION"
    fi

    # Check latest commit
    echo ""
    echo "Latest commit:"
    git log -1 --oneline | head -1

    TAP_COMMIT_MSG=$(git log -1 --pretty=%B | head -1)
    if [[ $TAP_COMMIT_MSG == *"PHTV"* ]] && [[ $TAP_COMMIT_MSG == *"$VERSION"* ]]; then
        echo -e "${GREEN}✓ Commit message looks correct${NC}"
    fi

    # Check commit author
    TAP_AUTHOR=$(git log -1 --pretty=%an)
    echo -e "Commit author: ${YELLOW}$TAP_AUTHOR${NC}"

    if [[ $TAP_AUTHOR == *"github-actions"* ]] || [[ $TAP_AUTHOR == *"Phạm Hùng Tiến"* ]]; then
        echo -e "${GREEN}✓ Author verified${NC}"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓ Main repo formula: v$FORMULA_VERSION${NC}"
if [ -d "$TAP_REPO" ]; then
    echo -e "${GREEN}✓ Tap repo cask: v$TAP_VERSION${NC}"
fi
echo ""
echo -e "${BLUE}Users can now update via:${NC}"
echo -e "${YELLOW}  brew update && brew upgrade --cask phtv${NC}"
echo ""
