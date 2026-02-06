# Linux Foundation

This folder contains the Linux-side foundation reusing the shared engine in `Shared/Engine`.

## Layout

- `Runtime/`: engine global setting ownership for Linux process space.
- `Adapter/`: keysym/ASCII mapping into internal engine key ids.
- `Host/`: engine session facade and smoke executable.
- `IBus/`: placeholder bridge for future IBus/Fcitx integration.

## Build (Linux)

```bash
cmake -S . -B build -G Ninja
cmake --build build --target phtv_linux_console
```

## Next Implementation Step

1. Implement IBus/Fcitx event bridge and preedit/commit handling.
2. Add per-app state and process-aware hotkey handling.
3. Package `.deb/.rpm` with input method registration scripts.
