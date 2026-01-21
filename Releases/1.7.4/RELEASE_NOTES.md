# PHTV 1.7.4 Release Notes

## 🛠 Bug Fixes
* **Fix Spell Checking Sync:** Fixed a critical bug where the internal spell checking state was not synchronized with the user setting in the UI. This caused spell checking to be inadvertently disabled during typing sessions, leading to incorrect VNI/Telex processing for invalid words (e.g., typing "tbhoo123" resulting in "tbhỏo" instead of restoring to "tbhoo123").

## ⚡ Improvements
* **Code Modularization:** Refactored the core engine by splitting `Engine.cpp` into smaller, focused modules (`Macro`, `SmartSwitchKey`, `EnglishWordDetector`) to improve code maintainability and readability.
* **Stability:** Enhanced state synchronization between the UI layer and the C++ engine core.
