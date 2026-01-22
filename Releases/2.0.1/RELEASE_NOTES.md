# PHTV 2.0.1 Release Notes

## Improvements
- **Terminal Apps**: Removed special handling for terminal emulators (Terminal, iTerm2, Warp, Alacritty, Kitty, WezTerm, Hyper, etc.). They are now treated as standard applications by the input engine.
  - This removes specific input delays previously applied to terminals.
  - Ensures Vietnamese input is fully enabled and behaves consistently with other text editors like Notes or TextEdit.
