# ✅ Setup Automation - Làm ngay trong 5 phút

## 🎯 Bước 1: Tạo GitHub Token (2 phút)

### 1.1 Tạo token:
```bash
# Mở link này trong browser:
open https://github.com/settings/tokens/new
```

### 1.2 Điền thông tin:
- **Note**: `PHTV Homebrew Automation`
- **Expiration**: `No expiration` (hoặc 1 year)
- **Select scopes**: ✅ Tick 2 ô này:
  - ✅ `repo` (Full control of private repositories)
  - ✅ `workflow` (Update GitHub Action workflows)

### 1.3 Generate:
- Click **"Generate token"**
- **QUAN TRỌNG**: Copy token ngay (chỉ hiện 1 lần!)
- Token sẽ có dạng: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 🎯 Bước 2: Thêm Token vào Repository (1 phút)

### 2.1 Mở settings:
```bash
# Mở link này trong browser:
open https://github.com/PhamHungTien/PHTV/settings/secrets/actions
```

### 2.2 Tạo secret:
- Click **"New repository secret"**
- **Name**: `TAP_REPO_TOKEN` (phải đúng tên này!)
- **Secret**: Paste token vừa copy
- Click **"Add secret"**

✅ Done! Sẽ thấy secret `TAP_REPO_TOKEN` trong danh sách.

## 🎯 Bước 3: Enable GitHub Actions (1 phút)

### 3.1 Mở Actions settings:
```bash
# Mở link này trong browser:
open https://github.com/PhamHungTien/PHTV/settings/actions
```

### 3.2 Cấu hình:
**Actions permissions**:
- Chọn: ✅ **"Allow all actions and reusable workflows"**

**Workflow permissions**:
- Chọn: ✅ **"Read and write permissions"**
- ✅ Tick: **"Allow GitHub Actions to create and approve pull requests"**

- Click **"Save"**

## 🎯 Bước 4: Test Workflow (1 phút)

### Option A: Test Manual (Khuyến nghị)

```bash
# Mở Actions tab:
open https://github.com/PhamHungTien/PHTV/actions

# Hoặc dùng CLI:
gh workflow run update-homebrew.yml
```

**Trên web**:
1. Chọn workflow **"Update Homebrew Formula"**
2. Click **"Run workflow"**
3. Branch: `main`
4. Click **"Run workflow"**

### Option B: Test với Release thật

```bash
# Tạo test release (hoặc re-release v1.2.7)
gh release create v1.2.7 \
  --title "PHTV v1.2.7" \
  --notes "Test automation" \
  Releases/1.2.7/PHTV-1.2.7.dmg
```

## ✅ Kiểm tra kết quả

### Check workflow status:

```bash
# Via CLI
gh run list --workflow=update-homebrew.yml --limit 3

# Via web
open https://github.com/PhamHungTien/PHTV/actions
```

### Workflow sẽ chạy qua các bước:

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

### Kết quả mong đợi:

**Trong PHTV repo**:
- Commit mới: `chore: update homebrew formula to v1.2.7`
- Author: `github-actions[bot]`

**Trong tap repo**:
- Commit mới: `chore: update PHTV to v1.2.7`
- Author: `github-actions[bot]`

## 🎉 Hoàn tất!

Từ giờ, mỗi khi bạn tạo GitHub Release:

```bash
gh release create v1.2.8 \
  --title "PHTV v1.2.8" \
  --notes-file CHANGELOG.md \
  Releases/1.2.8/PHTV-1.2.8.dmg
```

→ Workflow tự động:
- ✅ Update `homebrew/phtv.rb`
- ✅ Sync `homebrew-tap`
- ✅ User có thể `brew upgrade --cask phtv` ngay!

## 🐛 Troubleshooting

### ❌ Workflow bị lỗi "Resource not accessible"

**Fix**:
```bash
# Settings → Actions → General
# ✅ Enable "Read and write permissions"
```

### ❌ "TAP_REPO_TOKEN not found"

**Fix**:
```bash
# Settings → Secrets → Actions
# Kiểm tra có secret "TAP_REPO_TOKEN" chưa
```

### ❌ "Permission denied" khi push tap

**Fix**:
```bash
# Token cần có scope "repo"
# Tạo lại token và update secret
```

### ❌ Workflow không chạy khi release

**Fix**:
```bash
# Kiểm tra workflow file đã được push:
git log --oneline | grep automation

# Kiểm tra Actions có enabled không:
open https://github.com/PhamHungTien/PHTV/settings/actions
```

## 📚 Tài liệu chi tiết

- **Quick Start**: `docs/HOMEBREW_QUICKSTART.md`
- **GitHub Actions Setup**: `docs/GITHUB_ACTIONS_SETUP.md`
- **Full Workflow**: `docs/HOMEBREW_WORKFLOW.md`

## 🚀 Next Steps

Sau khi setup xong, thử tạo release mới:

```bash
# 1. Update version trong Xcode
# 2. Build app
# 3. Tạo release:
gh release create v1.2.8 \
  --title "PHTV v1.2.8" \
  --notes "New features..." \
  Releases/1.2.8/PHTV-1.2.8.dmg

# 4. Xong! Đợi 1-2 phút, check:
open https://github.com/PhamHungTien/PHTV/actions
```

Enjoy automation! 🤖✨
