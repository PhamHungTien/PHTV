# PHTV Automation Scripts

Automation scripts for Homebrew formula updates and releases.

## 📜 Scripts

### `release_homebrew.sh` - Master Release Script
**Complete automation workflow**: Update formula → Commit → Push → Sync tap

```bash
./scripts/release_homebrew.sh
```

**What it does**:
1. ✅ Reads version from `Info.plist`
2. ✅ Updates `homebrew/phtv.rb` with new version and SHA256
3. ✅ Commits and pushes formula changes
4. ✅ Syncs with tap repository
5. ✅ Pushes to `homebrew-tap`

**When to use**: After building a new version

---

### `update_homebrew.sh` - Update Formula Only
**Updates Homebrew formula** without committing

```bash
./scripts/update_homebrew.sh
```

**What it does**:
1. ✅ Reads version from `Info.plist`
2. ✅ Finds DMG file in `Releases/VERSION/`
3. ✅ Calculates SHA256 checksum
4. ✅ Updates `homebrew/phtv.rb`
5. ✅ Runs style check and syntax validation

**When to use**: To update formula without committing

---

### `sync_homebrew_tap.sh` - Sync Tap Repository
**Syncs formula to tap repository**

```bash
# Interactive mode
./scripts/sync_homebrew_tap.sh

# Auto-push mode (no prompts)
AUTO_PUSH=yes ./scripts/sync_homebrew_tap.sh

# Custom tap location
TAP_REPO=/path/to/tap ./scripts/sync_homebrew_tap.sh
```

**What it does**:
1. ✅ Copies `homebrew/phtv.rb` to tap repository
2. ✅ Commits changes
3. ✅ Pushes to GitHub (if confirmed)

**When to use**: After manually updating formula

---

### `verify_automation.sh` - Verify Results
**Verifies automation results**

```bash
./scripts/verify_automation.sh
```

**What it does**:
1. ✅ Pulls latest changes from both repos
2. ✅ Checks formula versions match
3. ✅ Verifies commit messages
4. ✅ Shows summary

**When to use**: After GitHub Actions run

---

### `sign_update.sh` - Sign DMG for Sparkle
**Signs DMG file for Sparkle updates**

```bash
./scripts/sign_update.sh path/to/PHTV.dmg
```

**What it does**:
1. ✅ Signs DMG with EdDSA key
2. ✅ Generates signature for appcast.xml

**When to use**: When creating release with Sparkle auto-update

---

## 🚀 Common Workflows

### Complete Release (Recommended)
```bash
# One command does everything
./scripts/release_homebrew.sh
```

### Manual Step-by-Step
```bash
# 1. Update formula
./scripts/update_homebrew.sh

# 2. Review changes
git diff homebrew/phtv.rb

# 3. Commit
git add homebrew/phtv.rb
git commit -m "chore: update homebrew formula to vX.X.X"
git push

# 4. Sync tap
./scripts/sync_homebrew_tap.sh
```

### GitHub Actions (Fully Automated)
Just create a GitHub Release - automation handles everything:

```bash
gh release create vX.X.X \
  --title "PHTV vX.X.X" \
  --notes-file CHANGELOG.md \
  Releases/X.X.X/PHTV-X.X.X.dmg
```

---

## 📝 Script Requirements

All scripts require:
- macOS
- Git configured
- Xcode command line tools
- Ruby (for brew style checks)

For GitHub Actions:
- `TAP_REPO_TOKEN` secret configured
- Tap repository at `~/Documents/homebrew-tap`

## 🐛 Troubleshooting

Common issues:
- **DMG not found**: Check `Releases/VERSION/PHTV-VERSION.dmg` exists
- **Permission denied**: Run `gh auth login` to re-authenticate
- **Formula syntax error**: Run `brew style --fix homebrew/phtv.rb`
- **Tap not syncing**: Check `~/Documents/homebrew-tap` exists

---

**Note**: All scripts are designed to be idempotent - safe to run multiple times.
