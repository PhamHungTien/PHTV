#!/bin/bash

echo "🔧 PHTV Accessibility Permission Fix Script"
echo "=========================================="
echo ""

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Kiểm tra app đang chạy
echo "📍 Bước 1: Kiểm tra PHTV đang chạy..."
if pgrep -x "PHTV" > /dev/null; then
    echo -e "${YELLOW}⚠️  PHTV đang chạy (PID: $(pgrep -x PHTV))${NC}"
    echo "   Sẽ dừng app để reset quyền..."
    killall PHTV 2>/dev/null
    sleep 2
    echo -e "${GREEN}✅ Đã dừng PHTV${NC}"
else
    echo -e "${GREEN}✅ PHTV không chạy${NC}"
fi
echo ""

# 2. Kiểm tra binary architecture
echo "📍 Bước 2: Kiểm tra binary architecture..."
ARCH_INFO=$(file /Applications/PHTV.app/Contents/MacOS/PHTV)
echo "   $ARCH_INFO"
if echo "$ARCH_INFO" | grep -q "2 architectures"; then
    echo -e "${GREEN}✅ Universal Binary (arm64 + x86_64)${NC}"
elif echo "$ARCH_INFO" | grep -q "1 architecture"; then
    echo -e "${YELLOW}⚠️  Chỉ có 1 kiến trúc (đã bị CleanMyMac gỡ bỏ)${NC}"
    echo -e "${YELLOW}   Khuyến nghị: Cài đặt lại app từ bản gốc${NC}"
else
    echo -e "${RED}❌ Không xác định được architecture${NC}"
fi
echo ""

# 3. Kiểm tra code signature
echo "📍 Bước 3: Kiểm tra code signature..."
if codesign --verify --deep --strict /Applications/PHTV.app 2>/dev/null; then
    echo -e "${GREEN}✅ Code signature hợp lệ${NC}"
    codesign -vv -d /Applications/PHTV.app 2>&1 | grep "Authority=" | head -1
else
    echo -e "${RED}❌ Code signature KHÔNG hợp lệ${NC}"
    echo -e "${RED}   Cần cài đặt lại app!${NC}"
    exit 1
fi
echo ""

# 4. Reset TCC permissions
echo "📍 Bước 4: Reset TCC permissions..."
if tccutil reset Accessibility com.phamhungtien.phtv 2>/dev/null; then
    echo -e "${GREEN}✅ Đã reset TCC entry cho PHTV${NC}"
else
    echo -e "${YELLOW}⚠️  Không thể reset TCC (cần quyền cao hơn)${NC}"
fi
echo ""

# 5. Xóa cache hệ thống
echo "📍 Bước 5: Xóa cache hệ thống..."
echo "   Đang xóa Launch Services cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null
sleep 1
echo -e "${GREEN}✅ Đã xóa cache${NC}"
echo ""

# 6. Hướng dẫn cấp lại quyền
echo "📍 Bước 6: Cấp lại quyền Accessibility"
echo "=========================================="
echo ""
echo -e "${YELLOW}🔔 QUAN TRỌNG: Làm theo các bước sau:${NC}"
echo ""
echo "1️⃣  Mở System Settings (Cài đặt Hệ thống)"
echo "2️⃣  Vào: Privacy & Security > Accessibility"
echo "3️⃣  Nếu thấy PHTV trong danh sách:"
echo "    - TẮT checkbox của PHTV"
echo "    - Đợi 2 giây"
echo "    - BẬT lại checkbox"
echo "4️⃣  Nếu KHÔNG thấy PHTV:"
echo "    - Nhấn nút '+' để thêm"
echo "    - Chọn /Applications/PHTV.app"
echo "    - Bật checkbox"
echo ""
echo "5️⃣  Khởi động lại PHTV"
echo ""

# 7. Tự động mở System Settings
echo "Bạn có muốn mở System Settings ngay bây giờ? (y/N)"
read -t 10 -n 1 RESPONSE
echo ""
if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo "Đang mở System Settings..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    sleep 2
fi

echo ""
echo -e "${GREEN}✅ Hoàn thành! Hãy cấp quyền Accessibility và khởi động PHTV.${NC}"
echo ""

# 8. Thông tin debug
echo "📊 Thông tin debug:"
echo "   Bundle ID: com.phamhungtien.phtv"
echo "   App Path: /Applications/PHTV.app"
echo "   Binary: $(file /Applications/PHTV.app/Contents/MacOS/PHTV | cut -d: -f2)"
echo ""
