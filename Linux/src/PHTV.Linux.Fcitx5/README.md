# PHTV.Linux.Fcitx5

Fcitx 5 shared-library addon C++20 dự kiến triển khai
`fcitx::InputMethodEngineV2` và gọi `Shared/PHTVCore` qua C ABI.

Addon phải dùng RAII, chặn exception tại framework boundary và không blocking
trong key callback. Không log key/preedit/surrounding text và không gọi mạng vì
lỗi trong addon có thể ảnh hưởng toàn bộ tiến trình Fcitx.

