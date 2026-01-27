#!/bin/bash

# Script nhanh để fix Gatekeeper warning khi phát triển
# Chỉ dùng cho local development, KHÔNG dùng cho distribution

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Quick Fix Gatekeeper Warning ===${NC}\n"

APP_PATH="${1:-build/Release/PHTV.app}"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    echo "Usage: $0 [APP_PATH]"
    exit 1
fi

echo -e "${YELLOW}App: $APP_PATH${NC}\n"

# Step 1: Remove quarantine attribute
echo -e "${BLUE}[1/4] Removing quarantine flag...${NC}"
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH"
echo -e "${GREEN}✓ Quarantine removed${NC}\n"

# Step 2: Ad-hoc code signing (for local dev only)
echo -e "${BLUE}[2/4] Applying ad-hoc code signature...${NC}"
codesign --force --deep --sign - "$APP_PATH"
echo -e "${GREEN}✓ Ad-hoc signed${NC}\n"

# Step 3: Verify signature
echo -e "${BLUE}[3/4] Verifying signature...${NC}"
codesign --verify --deep --strict "$APP_PATH"
echo -e "${GREEN}✓ Signature valid${NC}\n"

# Step 4: Allow app to run
echo -e "${BLUE}[4/4] Allowing app in Gatekeeper...${NC}"
sudo spctl --add --label "PHTV Dev" "$APP_PATH" 2>/dev/null || true
echo -e "${GREEN}✓ App whitelisted${NC}\n"

echo -e "${GREEN}=== Done ===${NC}"
echo -e "${YELLOW}WARNING: This is for LOCAL DEVELOPMENT only!${NC}"
echo -e "${YELLOW}For DISTRIBUTION, use: ./scripts/codesign_and_notarize.sh${NC}\n"

# Try to open the app
if command -v osascript &> /dev/null; then
    read -p "Open the app now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$APP_PATH"
    fi
fi
