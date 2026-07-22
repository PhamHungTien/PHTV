# Đóng gói và phát hành PHTV for Linux

## Package layout dự kiến

- `phtv-core`: Swift Core/runtime và resource chung;
- `phtv-ibus`: IBus executable + component/engine metadata;
- `phtv-fcitx5`: Fcitx shared addon + addon/input-method metadata;
- `phtv-settings`: GTK/libadwaita app, desktop file, icon và AppStream metadata;
- `phtv`: meta-package chọn backend phù hợp theo distro/desktop.

Tên package cuối cùng phụ thuộc quy tắc distro. Không cho `phtv-ibus` và
`phtv-fcitx5` tự kích hoạt đồng thời hoặc thay đổi input framework mặc định mà
không có xác nhận người dùng.

## Kênh ưu tiên

1. `.deb` cho Ubuntu/Debian mục tiêu;
2. `.rpm` cho Fedora/openSUSE mục tiêu;
3. PKGBUILD sau khi ABI/package layout ổn định;
4. hợp tác downstream để đưa package vào repository distro.

Flatpak/AppImage/Snap không phải gói chính cho IME vì engine/addon cần tích hợp
host input framework. Có thể dùng Flatpak cho Settings về sau nhưng không được
tách UX update khỏi package sở hữu backend.

## Pipeline dự kiến

1. Build Core và native adapters trong môi trường khóa phiên bản.
2. Chạy Core, ABI, backend và package tests.
3. Tạo `.deb`/`.rpm`, AppStream metadata, SBOM và debug symbols tách riêng.
4. Kiểm tra file ownership, dependency, RPATH/RUNPATH và symbol visibility.
5. Ký package/repository metadata; công bố checksum và provenance.
6. Cài/upgrade/uninstall trên image GNOME/IBus và KDE/Fcitx sạch.
7. Promote đúng artifact đã kiểm thử từ Beta sang Stable.

## Version và update

Semantic version sản phẩm có thể đồng bộ với macOS/Windows khi tính năng tương
ứng phát hành; package revision theo distro độc lập. PHTV không tự cập nhật bằng
Sparkle hoặc binary downloader trên Linux—package manager là nguồn cập nhật.

## Uninstall

Gỡ package phải xóa engine/addon metadata và binary nhưng giữ dữ liệu cá nhân
trừ khi người dùng chọn purge. Sau gỡ, IBus/Fcitx restart/reload phải có hướng
dẫn rõ và không để input source hỏng trong session kế tiếp.

