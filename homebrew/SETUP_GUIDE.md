# Hướng dẫn thiết lập Homebrew Tap cho PHTV

**Lưu ý**: Repository đã đổi tên từ `homebrew-phtv` → `homebrew-tap` để lệnh cài đặt ngắn gọn hơn:
- Old: `brew install --cask phamhungtien/phtv/phtv` (lặp "phtv")
- New: `brew install --cask phamhungtien/tap/phtv` (ngắn gọn hơn)

## Bước 1: Tạo GitHub Release với PHTV-1.2.6.dmg

Trước tiên, bạn cần tạo một GitHub Release và upload file `PHTV-1.2.6.dmg`:

1. Đi đến: https://github.com/PhamHungTien/PHTV/releases/new
2. Tag version: `v1.2.6`
3. Release title: `PHTV v1.2.6 - Performance & UX Optimization`
4. Description: Copy nội dung từ `RELEASE_NOTES_1.2.6.md`
5. Upload file: `PHTV-1.2.6.dmg` (đã có sẵn)
6. Click **Publish release**

## Bước 2: Tạo repository homebrew-tap

### Trên GitHub:

1. Đi đến: https://github.com/new
2. Repository name: `homebrew-tap`
3. Description: `🍺 Homebrew tap for PHTV - Modern Vietnamese input method for macOS`
4. Public repository
5. **KHÔNG** tick "Add a README file" (chúng ta đã có sẵn)
6. Click **Create repository**

### Trên máy local:

```bash
# Tạo thư mục mới cho homebrew tap
cd ~/Documents
mkdir homebrew-tap
cd homebrew-tap

# Init git repo
git init
git branch -M main

# Copy files từ PHTV/homebrew/
cp ~/Documents/PHTV/homebrew/phtv.rb Casks/phtv.rb
cp ~/Documents/PHTV/homebrew/README.md .

# Tạo cấu trúc thư mục chuẩn Homebrew
mkdir -p Casks

# Move file vào đúng chỗ
mv phtv.rb Casks/

# Commit
git add .
git commit -m "Initial commit: Add PHTV cask"

# Add remote và push
git remote add origin https://github.com/PhamHungTien/homebrew-tap.git
git push -u origin main
```

## Bước 3: Cấu trúc thư mục homebrew-tap

Repo nên có cấu trúc như sau:

```
homebrew-tap/
├── Casks/
│   └── phtv.rb          # Homebrew Cask formula
├── README.md            # Hướng dẫn cài đặt
└── LICENSE              # (Optional) GPL-3.0
```

## Bước 4: Test Homebrew Tap trên máy local

```bash
# Add tap từ local (để test)
brew tap phamhungtien/tap

# Kiểm tra tap đã được thêm
brew tap

# Install PHTV
brew install --cask phtv

# Hoặc test bằng cách dry-run
brew install --cask phtv --dry-run
```

## Bước 5: Cập nhật README.md của PHTV

Thêm phần Homebrew installation vào `README.md` của PHTV:

```markdown
## Cài đặt

### Homebrew (Khuyến nghị)

```bash
brew install --cask phamhungtien/tap/phtv
```

### Tải thủ công

Tải file `.dmg` từ [GitHub Releases](https://github.com/PhamHungTien/PHTV/releases/latest)
```

## Bước 6: Cập nhật Cask cho phiên bản mới (tương lai)

Khi release version mới (ví dụ 1.2.7):

1. Upload file `PHTV-1.2.7.dmg` lên GitHub Release
2. Tính SHA256:
   ```bash
   shasum -a 256 PHTV-1.2.7.dmg
   ```
3. Cập nhật `Casks/phtv.rb`:
   ```ruby
   version "1.2.7"
   sha256 "new_sha256_here"
   ```
4. Commit và push:
   ```bash
   git add Casks/phtv.rb
   git commit -m "Update PHTV to v1.2.7"
   git push
   ```
5. Người dùng sẽ update bằng:
   ```bash
   brew update
   brew upgrade --cask phtv
   ```

## Kiểm tra Cask syntax

```bash
# Kiểm tra syntax
brew audit --cask phtv

# Kiểm tra style
brew style Casks/phtv.rb

# Test installation
brew install --cask phtv --verbose
```

## Lưu ý

- Tên repo PHẢI là `homebrew-*` (ví dụ: `homebrew-tap`)
- Cask files phải nằm trong thư mục `Casks/`
- File name phải match với cask name (ví dụ: `phtv.rb` cho cask "phtv")
- SHA256 checksum phải khớp với file dmg trên GitHub Release
- URL phải trỏ đến file dmg trên GitHub Releases (không phải source code)
- Tên tap ngắn gọn (như `tap`) tốt hơn tên dài (như `phtv`) để tránh lặp trong lệnh cài đặt

## Troubleshooting

### Lỗi: "SHA256 mismatch"
- Tính lại SHA256 của file zip và cập nhật trong `phtv.rb`

### Lỗi: "Could not resolve formula"
- Kiểm tra repo name phải là `homebrew-phtv`
- Kiểm tra file nằm trong thư mục `Casks/`

### Lỗi: "URL not found"
- Kiểm tra đã tạo GitHub Release chưa
- Kiểm tra file PHTV-1.2.6.dmg đã upload lên Release chưa
- URL phải đúng format: `https://github.com/PhamHungTien/PHTV/releases/download/v1.2.6/PHTV-1.2.6.dmg`

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Creating Homebrew Taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
