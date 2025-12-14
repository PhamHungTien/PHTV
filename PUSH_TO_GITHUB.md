# 🚀 Push PHTV lên GitHub

Hướng dẫn này sẽ giúp bạn push PHTV lên GitHub.

## ✅ Sẵn sàng

Project đã được chuẩn bị hoàn toàn:

- ✅ Tất cả documentation files
- ✅ GitHub templates
- ✅ Links được update
- ✅ Structure sạch sẽ

## 📋 Các bước

### 1. Kiểm tra git config

```bash
git config --global user.name
git config --global user.email
```

Nếu chưa config, thêm:

```bash
git config --global user.name "Phạm Hùng Tiến"
git config --global user.email "your.email@example.com"
```

### 2. Vào project folder

```bash
cd /Users/phamhungtien/Desktop/PHTV
```

### 3. Khởi tạo git repository (nếu chưa có)

```bash
git init
```

### 4. Thêm remote repository

```bash
git remote add origin https://github.com/PhamHungTien/PHTV.git
```

Kiểm tra:

```bash
git remote -v
```

### 5. Add tất cả files

```bash
git add .
```

Xem lại những file sẽ commit:

```bash
git status
```

### 6. Commit

```bash
git commit -m "initial: PHTV - Vietnamese Input Method for macOS

Vietnamese input method for macOS with support for:
- Telex, VNI, Simple Telex input methods
- Multiple character encodings (Unicode, TCVN3, VNI, etc.)
- Spell checking, macros, Quick Telex, Smart Switch Key
- Dark Mode support
- Complete documentation and contribution guidelines

This project extends the OpenKey engine with modern macOS integration,
SwiftUI interface, and GPL-3.0 license."
```

### 7. Đổi branch name thành main

```bash
git branch -M main
```

### 8. Push lên GitHub

```bash
git push -u origin main
```

Lệnh này sẽ:

- Push code lên GitHub
- Set `origin main` làm upstream default

## ✅ Xác minh

Sau khi push, kiểm tra:

1. Mở https://github.com/PhamHungTien/PHTV
2. Verify:
   - [ ] Code có ở đó
   - [ ] README.md hiển thị đúng
   - [ ] LICENSE file có hiển thị trong repo header
   - [ ] .gitignore đang hoạt động (không có build/ folder)
   - [ ] Commit message đúng

## 🆘 Troubleshooting

### Remote đã tồn tại

```bash
git remote remove origin
git remote add origin https://github.com/PhamHungTien/PHTV.git
```

### Authentication lỗi

- Nếu dùng HTTPS: Cần personal access token từ GitHub
- Hoặc dùng SSH nếu setup sẵn

### Muốn edit commit message

```bash
git commit --amend
```

## 📚 Tài liệu

Sau khi push, bạn có thể:

1. **Setup branch protection** (Settings > Branches)

   - Require PR reviews trước merge
   - Require status checks

2. **Enable GitHub Pages** (Settings > Pages)

   - Để host documentation

3. **Setup GitHub Actions** (Add `.github/workflows/`)

   - CI/CD cho Swift builds

4. **Create Releases**
   - Đi Releases > Create new release
   - Tag: v1.0.0
   - Copy content từ CHANGELOG.md

## 🎉 Done!

Project PHTV giờ đã lên GitHub public! 🚀

Bạn có thể:

- Share link với mọi người: https://github.com/PhamHungTien/PHTV
- Nhận contributions từ cộng đồng
- Track issues & feature requests
- Release new versions

---

**Need help?** Check the documentation files:

- [README.md](./README.md) - Project overview
- [CONTRIBUTING.md](./CONTRIBUTING.md) - How to contribute
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) - Community standards
