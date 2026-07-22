# PHTV.Linux.IBus

IBus engine process C++20 dự kiến dùng `libibus-1.0` và gọi
`Shared/PHTVCore` qua C ABI.

## Sở hữu

- component/engine registration và session D-Bus;
- key/focus/reset/capability lifecycle;
- preedit, commit và surrounding-text operations;
- ánh xạ input purpose/client identity sang context trung lập.

## Không sở hữu

- quy tắc Telex/VNI/Auto English;
- Settings, update, Clipboard/GIF hoặc network;
- raw keyboard device và event injection toàn cục.

