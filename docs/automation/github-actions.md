# GitHub Actions Setup Guide

Hướng dẫn setup GitHub Actions để tự động cập nhật Homebrew formula khi release.

## Tổng quan

Khi bạn tạo GitHub Release, workflow sẽ tự động:
1. ✅ Download DMG từ release assets
2. ✅ Tính SHA256 checksum
3. ✅ Cập nhật `homebrew/phtv.rb`
4. ✅ Commit và push changes
5. ✅ Sync với tap repository
6. ✅ Người dùng có thể update ngay via Homebrew

## Bước 1: Tạo GitHub Personal Access Token

### Tại sao cần token?

GitHub Actions cần quyền để:
- Push changes vào tap repository (`homebrew-tap`)
- Clone private repositories (nếu có)

### Cách tạo token:

1. Đi đến: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Điền thông tin:
   - **Note**: `PHTV Homebrew Automation`
   - **Expiration**: `No expiration` (hoặc 1 năm)
   - **Select scopes**:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)

4. Click **"Generate token"**
5. **QUAN TRỌNG**: Copy token ngay (chỉ hiện 1 lần!)

### Token trông như thế này:
```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Bước 2: Thêm Token vào Repository Secrets

### Repo chính (PHTV):

1. Đi đến: https://github.com/PhamHungTien/PHTV/settings/secrets/actions
2. Click **"New repository secret"**
3. Tạo secret:
   - **Name**: `TAP_REPO_TOKEN`
   - **Secret**: Paste token vừa tạo
4. Click **"Add secret"**

## Bước 3: Enable GitHub Actions

1. Đi đến: https://github.com/PhamHungTien/PHTV/settings/actions
2. Trong **"Actions permissions"**:
   - Chọn: ✅ **"Allow all actions and reusable workflows"**
3. Trong **"Workflow permissions"**:
   - Chọn: ✅ **"Read and write permissions"**
   - ✅ Tick: **"Allow GitHub Actions to create and approve pull requests"**
4. Click **"Save"**

## Bước 4: Test Workflow

### Tạo test release:

```bash
# Tạo release với DMG file
gh release create v1.2.7 \
  --title "PHTV v1.2.7" \
  --notes "Test automated homebrew update" \
  Releases/1.2.7/PHTV-1.2.7.dmg
```

### Kiểm tra workflow:

1. Đi đến: https://github.com/PhamHungTien/PHTV/actions
2. Xem workflow **"Update Homebrew Formula"** đang chạy
3. Click vào workflow run để xem chi tiết

### Kết quả mong đợi:

```
✅ Checkout PHTV repository
✅ Get release version
✅ Download release DMG
✅ Calculate SHA256
✅ Update Homebrew formula
✅ Verify formula syntax
✅ Commit formula changes
✅ Update Homebrew tap
✅ Summary
```

## Bước 5: Verify Results

### Kiểm tra repo chính:

```bash
# Check latest commit
git log -1 --oneline
# Should see: "chore: update homebrew formula to v1.2.7"

# Check formula
cat homebrew/phtv.rb | grep version
# Should show: version "1.2.7"
```

### Kiểm tra tap repository:

```bash
cd ~/Documents/homebrew-tap
git pull

# Check latest commit
git log -1 --oneline
# Should see: "chore: update PHTV to v1.2.7"

# Check formula
cat Casks/phtv.rb | grep version
# Should show: version "1.2.7"
```

### Test user update:

```bash
# Người dùng update
brew update
brew upgrade --cask phtv
```

## Manual Trigger (Nếu cần)

Workflow có thể chạy thủ công:

1. Đi đến: https://github.com/PhamHungTien/PHTV/actions
2. Chọn **"Update Homebrew Formula"**
3. Click **"Run workflow"**
4. Chọn branch `main`
5. Click **"Run workflow"**

## Troubleshooting

### ❌ Error: "Permission denied"

**Nguyên nhân**: Token không có đủ quyền

**Giải pháp**:
1. Tạo token mới với scope `repo` và `workflow`
2. Update secret `TAP_REPO_TOKEN`

### ❌ Error: "Resource not accessible by integration"

**Nguyên nhân**: Workflow permissions chưa được enable

**Giải pháp**:
1. Đi đến Settings → Actions → General
2. Enable "Read and write permissions"

### ❌ Error: "DMG file not found"

**Nguyên nhân**: Release không có DMG asset

**Giải pháp**:
Upload DMG file khi tạo release:
```bash
gh release create v1.2.7 \
  --notes "..." \
  Releases/1.2.7/PHTV-1.2.7.dmg
```

### ❌ Workflow không chạy khi release

**Nguyên nhân**:
- Workflow file không có trong branch main
- GitHub Actions chưa được enable

**Giải pháp**:
1. Commit và push workflow file:
   ```bash
   git add .github/workflows/update-homebrew.yml
   git commit -m "feat: add homebrew auto-update workflow"
   git push
   ```

2. Enable Actions trong Settings

### ❌ Error: "Unable to push to tap repository"

**Nguyên nhân**: Token không có quyền write

**Giải pháp**:
1. Kiểm tra token có scope `repo`
2. Kiểm tra tap repository settings cho phép token push

## Security Best Practices

### ✅ DO:
- Sử dụng GitHub Secrets cho tokens
- Set token expiration (1 năm)
- Giữ token an toàn, không commit vào code
- Review workflow runs định kỳ

### ❌ DON'T:
- Không share token với người khác
- Không commit token vào git
- Không dùng token cá nhân cho production
- Không set "No expiration" nếu không cần thiết

## Alternative: GitHub App

Thay vì Personal Access Token, có thể dùng GitHub App (advanced):

### Ưu điểm:
- ✅ Secure hơn
- ✅ Granular permissions
- ✅ Không expire
- ✅ Audit logs tốt hơn

### Setup:
1. Create GitHub App: https://github.com/settings/apps/new
2. Install app vào repositories
3. Dùng app credentials trong workflow

## Workflow Features

### Auto-trigger on release:
```yaml
on:
  release:
    types: [published]
```

### Manual trigger:
```yaml
on:
  workflow_dispatch:
```

### Scheduled update (nếu cần):
```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at midnight
```

## Monitoring

### Xem workflow status:
```bash
# Via GitHub CLI
gh run list --workflow=update-homebrew.yml

# Xem chi tiết run mới nhất
gh run view
```

### Email notifications:

GitHub sẽ tự động gửi email khi:
- ✅ Workflow thành công
- ❌ Workflow thất bại

## Next Steps

Sau khi setup xong, quy trình release sẽ là:

```bash
# 1. Build app và tạo DMG
xcodebuild -project PHTV.xcodeproj -configuration Release

# 2. Tạo GitHub Release (workflow tự động chạy)
gh release create v1.2.8 \
  --title "PHTV v1.2.8" \
  --notes-file CHANGELOG.md \
  Releases/1.2.8/PHTV-1.2.8.dmg

# 3. Workflow tự động:
#    - Update homebrew/phtv.rb
#    - Sync with tap
#    - User có thể update via brew

# 4. Done! ✨
```

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Creating Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub CLI](https://cli.github.com/)
