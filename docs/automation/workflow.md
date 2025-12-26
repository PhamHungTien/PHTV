# Homebrew Release Workflow

Quy trình tự động hóa cập nhật Homebrew formula khi release version mới.

## Tổng quan

```
Build → Create DMG → GitHub Release → Update Formula → Sync Tap
```

## Quy trình chi tiết

### 1. Build và Release

Sau khi build version mới (ví dụ: 1.2.7):

```bash
# Build app trong Xcode
# DMG file sẽ được tạo tại: Releases/1.2.7/PHTV-1.2.7.dmg

# Tạo GitHub Release
gh release create v1.2.7 \
  --title "PHTV v1.2.7" \
  --notes "Release notes here" \
  Releases/1.2.7/PHTV-1.2.7.dmg
```

### 2. Cập nhật Homebrew Formula

#### Tự động (Khuyến nghị)

```bash
# Script tự động đọc version từ Info.plist và cập nhật formula
./scripts/update_homebrew.sh
```

Script này sẽ:
- ✓ Đọc version từ `PHTV/Info.plist`
- ✓ Tìm DMG file tương ứng
- ✓ Tính SHA256 checksum
- ✓ Cập nhật `homebrew/phtv.rb`
- ✓ Chạy style check (`brew style`)
- ✓ Kiểm tra syntax (`ruby -c`)

#### Thủ công

```bash
# Tính SHA256
shasum -a 256 Releases/1.2.7/PHTV-1.2.7.dmg

# Cập nhật homebrew/phtv.rb
# - version "1.2.7"
# - sha256 "..."
```

### 3. Commit Formula Changes

```bash
git add homebrew/phtv.rb
git commit -m "chore: update homebrew formula to v1.2.7"
git push origin main
```

### 4. Sync với Tap Repository

#### Tự động (Khuyến nghị)

```bash
# Script tự động copy formula và commit changes
./scripts/sync_homebrew_tap.sh
```

Script này sẽ:
- ✓ Copy `homebrew/phtv.rb` → `~/Documents/homebrew-tap/Casks/phtv.rb`
- ✓ Commit changes
- ✓ Push lên GitHub (nếu xác nhận)

#### Thủ công

```bash
# Copy formula
cp homebrew/phtv.rb ~/Documents/homebrew-tap/Casks/phtv.rb

# Commit và push
cd ~/Documents/homebrew-tap
git add Casks/phtv.rb
git commit -m "chore: update PHTV to v1.2.7"
git push origin main
```

### 5. Người dùng cập nhật

```bash
# Cập nhật Homebrew
brew update

# Upgrade PHTV
brew upgrade --cask phtv
```

## Script tự động hóa

### update_homebrew.sh

Cập nhật formula trong repo chính:

```bash
./scripts/update_homebrew.sh
```

**Input**:
- Version từ `Info.plist`
- DMG file từ `Releases/VERSION/`

**Output**:
- Cập nhật `homebrew/phtv.rb`
- Style check và syntax validation

### sync_homebrew_tap.sh

Đồng bộ formula với tap repository:

```bash
./scripts/sync_homebrew_tap.sh
```

**Input**:
- Formula từ `homebrew/phtv.rb`

**Output**:
- Copy và commit vào `~/Documents/homebrew-tap/Casks/phtv.rb`

**Biến môi trường**:
```bash
# Sử dụng tap repo ở vị trí khác
TAP_REPO=/path/to/tap ./scripts/sync_homebrew_tap.sh
```

## One-liner cho toàn bộ quy trình

```bash
# Build → Update Formula → Sync Tap
./scripts/update_homebrew.sh && \
git add homebrew/phtv.rb && \
git commit -m "chore: update homebrew formula to $(agvtool what-marketing-version | grep 'Found' | awk '{print $NF}' | tr -d '\"')" && \
git push && \
./scripts/sync_homebrew_tap.sh
```

## GitHub Actions (Tương lai)

Tự động hóa hoàn toàn với GitHub Actions:

```yaml
name: Update Homebrew

on:
  release:
    types: [published]

jobs:
  update:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update formula
        run: ./scripts/update_homebrew.sh

      - name: Commit formula
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add homebrew/phtv.rb
          git commit -m "chore: update homebrew formula to ${{ github.event.release.tag_name }}"
          git push

      - name: Sync to tap
        env:
          GH_TOKEN: ${{ secrets.TAP_REPO_TOKEN }}
        run: |
          git clone https://github.com/phamhungtien/homebrew-tap.git /tmp/tap
          cp homebrew/phtv.rb /tmp/tap/Casks/phtv.rb
          cd /tmp/tap
          git add Casks/phtv.rb
          git commit -m "chore: update PHTV to ${{ github.event.release.tag_name }}"
          git push
```

## Kiểm tra và debug

### Kiểm tra formula syntax

```bash
# Style check
brew style --fix homebrew/phtv.rb

# Ruby syntax
ruby -c homebrew/phtv.rb

# Audit (nếu đã tap)
brew audit --cask phtv
```

### Test installation locally

```bash
# Install từ local formula
brew install --cask homebrew/phtv.rb

# Hoặc test dry-run
brew install --cask phtv --dry-run
```

### Xem version hiện tại

```bash
# Formula trong repo chính
grep 'version "' homebrew/phtv.rb

# Formula trong tap
grep 'version "' ~/Documents/homebrew-tap/Casks/phtv.rb

# Version đã install
brew info phtv
```

## Troubleshooting

### Formula outdated

```bash
# Force update formula
./scripts/update_homebrew.sh

# Sync lại tap
./scripts/sync_homebrew_tap.sh
```

### SHA256 mismatch

```bash
# Tính lại SHA256
shasum -a 256 Releases/VERSION/PHTV-VERSION.dmg

# Cập nhật lại formula
./scripts/update_homebrew.sh
```

### Tap không sync

```bash
# Kiểm tra tap repo
ls -la ~/Documents/homebrew-tap

# Sync thủ công
cp homebrew/phtv.rb ~/Documents/homebrew-tap/Casks/phtv.rb
cd ~/Documents/homebrew-tap
git add Casks/phtv.rb
git commit -m "chore: update PHTV"
git push
```

## Best practices

1. **Luôn chạy `update_homebrew.sh` sau khi release**: Đảm bảo formula luôn sync với version mới nhất

2. **Test formula trước khi sync**: Kiểm tra syntax và style trước khi push

3. **Commit formula riêng**: Đừng gộp formula update với code changes khác

4. **Sync tap ngay sau khi update formula**: Người dùng sẽ có thể update ngay lập tức

5. **Sử dụng semantic commit messages**:
   - `chore: update homebrew formula to v1.2.7`
   - `chore: update PHTV to v1.2.7`

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Creating Homebrew Taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
