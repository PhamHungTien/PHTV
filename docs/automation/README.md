# Homebrew Automation - Quick Start

Hướng dẫn nhanh để tự động hóa Homebrew release.

## 🚀 TL;DR - Chạy ngay

```bash
# Sau khi build xong
./scripts/release_homebrew.sh
```

Done! Script sẽ tự động:
- ✅ Update formula
- ✅ Commit changes
- ✅ Push to GitHub
- ✅ Sync tap repository

## 📋 Setup lần đầu (5 phút)

### 1. Setup GitHub Token (quan trọng cho automation)

```bash
# Tạo token tại: https://github.com/settings/tokens
# Scopes: repo, workflow
# Copy token

# Thêm vào PHTV repository:
# Settings → Secrets → Actions → New secret
# Name: TAP_REPO_TOKEN
# Value: paste token
```

### 2. Enable GitHub Actions

```bash
# PHTV repository settings
# Settings → Actions → General
# ✅ Allow all actions
# ✅ Read and write permissions
```

### 3. Done! 🎉

Từ giờ, mỗi khi tạo GitHub Release, mọi thứ tự động!

## 🎯 Quy trình mới

### Phương án 1: Tự động hoàn toàn (Khuyến nghị)

```bash
# 1. Build app
xcodebuild -project PHTV.xcodeproj -configuration Release

# 2. Tạo GitHub Release
gh release create v1.2.8 \
  --title "PHTV v1.2.8" \
  --notes "What's new..." \
  Releases/1.2.8/PHTV-1.2.8.dmg

# 3. Xong! GitHub Actions tự động lo:
#    ✅ Update homebrew formula
#    ✅ Sync tap repository
#    ✅ User có thể brew upgrade ngay
```

**Lợi ích**:
- 🚫 Không cần chạy script manual
- 🚫 Không cần commit formula changes
- 🚫 Không cần sync tap
- ✅ Mọi thứ tự động 100%

### Phương án 2: Semi-automatic (Local script)

```bash
# 1. Build app
xcodebuild -project PHTV.xcodeproj -configuration Release

# 2. Chạy master script
./scripts/release_homebrew.sh

# 3. Tạo GitHub Release
gh release create v1.2.8 \
  --notes "..." \
  Releases/1.2.8/PHTV-1.2.8.dmg
```

**Khi nào dùng**: Khi không muốn dùng GitHub Actions

### Phương án 3: Manual (Từng bước)

```bash
# Update formula
./scripts/update_homebrew.sh

# Commit
git add homebrew/phtv.rb
git commit -m "chore: update formula to v1.2.8"
git push

# Sync tap
./scripts/sync_homebrew_tap.sh
```

**Khi nào dùng**: Khi cần kiểm soát từng bước

## 📊 So sánh

| Feature | Auto (Actions) | Semi (Script) | Manual |
|---------|---------------|---------------|--------|
| Setup time | 5 min | 0 min | 0 min |
| Steps per release | 1 | 2 | 4-5 |
| Error prone | ❌ | ⚠️ | ⚠️ |
| Requires local | ❌ | ✅ | ✅ |
| Audit trail | ✅ | ⚠️ | ❌ |

## 🛠️ Scripts chi tiết

### `release_homebrew.sh` - Master script

**Chức năng**:
- Đọc version từ `Info.plist`
- Update formula với SHA256 mới
- Commit và push changes
- Sync với tap repository

**Usage**:
```bash
./scripts/release_homebrew.sh
```

**Output**:
```
╔══════════════════════════════════════════════════════╗
║     PHTV Homebrew Release Automation v1.0           ║
╚══════════════════════════════════════════════════════╝

📦 Version: 1.2.8

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1/4: Updating Homebrew formula
✓ Formula updated successfully

Step 2/4: Committing formula changes
✓ Formula committed

Step 3/4: Pushing to main repository
✓ Pushed to main repository

Step 4/4: Syncing with Homebrew tap
✓ Synced with tap repository

✨ Release automation completed successfully! ✨
```

### `update_homebrew.sh` - Update formula only

**Chức năng**:
- Tìm DMG file
- Tính SHA256
- Update `homebrew/phtv.rb`
- Run style checks

**Usage**:
```bash
./scripts/update_homebrew.sh
```

### `sync_homebrew_tap.sh` - Sync tap only

**Chức năng**:
- Copy formula to tap repo
- Commit changes
- Push to GitHub

**Usage**:
```bash
# Interactive
./scripts/sync_homebrew_tap.sh

# Auto-push (no prompt)
AUTO_PUSH=yes ./scripts/sync_homebrew_tap.sh

# Custom tap location
TAP_REPO=/path/to/tap ./scripts/sync_homebrew_tap.sh
```

## 🔍 Verify

### Kiểm tra formula đã update chưa:

```bash
# Local
cat homebrew/phtv.rb | grep version

# Tap
cat ~/Documents/homebrew-tap/Casks/phtv.rb | grep version

# Remote tap
curl -s https://raw.githubusercontent.com/phamhungtien/homebrew-tap/main/Casks/phtv.rb | grep version
```

### Kiểm tra GitHub Actions:

```bash
# Via CLI
gh run list --workflow=update-homebrew.yml --limit 5

# Via browser
open https://github.com/PhamHungTien/PHTV/actions
```

### Test user update:

```bash
brew update
brew upgrade --cask phtv --dry-run
```

## 🐛 Common Issues

### "DMG file not found"

```bash
# Check DMG exists
ls -la Releases/1.2.8/PHTV-1.2.8.dmg

# Check version in Info.plist matches folder
agvtool what-marketing-version
```

### "Permission denied" khi push

```bash
# Check git credentials
git config user.name
git config user.email

# Re-authenticate
gh auth login
```

### Formula syntax error

```bash
# Fix style issues
brew style --fix homebrew/phtv.rb

# Check syntax
ruby -c homebrew/phtv.rb
```

### Tap repository không sync

```bash
# Check tap exists
ls -la ~/Documents/homebrew-tap

# Clone if not exists
cd ~/Documents
git clone https://github.com/phamhungtien/homebrew-tap.git

# Sync manually
./scripts/sync_homebrew_tap.sh
```

## 📚 Chi tiết hơn

- **GitHub Actions Setup**: `docs/GITHUB_ACTIONS_SETUP.md`
- **Full Workflow**: `docs/HOMEBREW_WORKFLOW.md`
- **Homebrew Setup**: `homebrew/SETUP_GUIDE.md`

## 🎓 Best Practices

### ✅ DO

1. **Test local trước khi release**:
   ```bash
   ./scripts/release_homebrew.sh
   # Kiểm tra output, verify changes
   ```

2. **Dùng semantic versioning**: `v1.2.3`

3. **Write clear release notes**: Người dùng sẽ thấy trong `brew upgrade`

4. **Verify formula sau mỗi update**:
   ```bash
   brew style homebrew/phtv.rb
   ruby -c homebrew/phtv.rb
   ```

5. **Monitor GitHub Actions**: Xem logs nếu có lỗi

### ❌ DON'T

1. **Không skip test**: Luôn test local trước

2. **Không edit formula manual khi dùng automation**: Dùng scripts

3. **Không commit trực tiếp vào tap repo**: Để automation sync

4. **Không dùng version trùng**: Mỗi release 1 version mới

5. **Không share GitHub token**: Giữ bí mật

## 🚦 Release Checklist

```bash
☐ Build app successfully
☐ Create DMG file
☐ Test app functionality
☐ Update version in Info.plist
☐ Update CHANGELOG.md
☐ Run: ./scripts/release_homebrew.sh
☐ Create GitHub Release with DMG
☐ Wait for GitHub Actions to complete
☐ Verify formula updated on both repos
☐ Test: brew upgrade --cask phtv --dry-run
☐ Announce release
```

## 🎉 Success!

Khi setup xong, quy trình release chỉ còn:

```bash
# Build → Release → Done!
xcodebuild && gh release create v1.2.8 ...
```

GitHub Actions lo phần còn lại! 🤖✨
