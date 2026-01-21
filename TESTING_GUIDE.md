# PHTV Manager Refactoring - Testing Guide

## Status
✅ Build: **SUCCEEDED**
✅ App Launch: **Running (PID 8023)**
✅ No Crashes: **Verified**
✅ All Managers Linked: **Confirmed**

## What Was Refactored
- **5.5/7 managers** extracted (~800+ lines of code)
- **Managers enabled**: Cache, AppDetection, Spotlight, Accessibility, Hotkey (partial)
- All managers use `#ifdef` toggles for rollback safety

## Manual Test Cases

### 1. Basic Vietnamese Typing Test
**Objective**: Verify core Vietnamese input still works

**Steps**:
1. Open any text editor (TextEdit, Notes, etc.)
2. Ensure PHTV is enabled (check menu bar icon)
3. Type: `xin chao viet nam`
4. Expected: `xin chào việt nam`
5. Type: `anh oi dong cua lai`
6. Expected: `anh ơi đóng cửa lại`

**What's being tested**: Basic Telex conversion (core engine + event synthesis)

---

### 2. Spotlight Detection Test
**Objective**: Verify PHTVSpotlightManager detects Spotlight correctly

**Steps**:
1. Press `Cmd+Space` to open Spotlight
2. Type: `viet` in Spotlight search box
3. Expected: Should type `viet` (not converted to Vietnamese)
4. Close Spotlight (Esc)
5. Open TextEdit and type: `viet`
6. Expected: `việt` (should be converted)

**What's being tested**:
- `PHTVSpotlightManager.isSpotlightActive()` with 50ms caching
- Spotlight-like app detection via AX API
- Cache invalidation when Spotlight closes

---

### 3. Terminal App Detection Test
**Objective**: Verify PHTVAppDetectionManager detects Terminal apps

**Steps**:
1. Open Terminal.app or iTerm2
2. Type: `xin chao`
3. Expected: `xin chào` (should work in Terminal)
4. Check if there's any delay
5. Expected: Should have terminal-specific timing (DelayTypeTerminal)

**What's being tested**:
- `PHTVAppDetectionManager.isTerminalApp()` with O(1) NSSet lookup
- Terminal-specific behavior handling
- PID-to-BundleID caching with 60s cleanup

---

### 4. Browser App Detection Test
**Objective**: Verify browser detection and characteristics caching

**Steps**:
1. Open Safari/Chrome/Firefox
2. Go to any input field (e.g., Google search)
3. Type: `viet nam`
4. Expected: `việt nam`
5. Switch to different browser, repeat
6. Expected: Same behavior, no performance degradation

**What's being tested**:
- `PHTVAppDetectionManager.isBrowserApp()` (36+ browsers)
- `PHTVCacheManager.getAppCharacteristics()` caching
- Cross-app switching performance

---

### 5. Hotkey Switching Test
**Objective**: Verify PHTVHotkeyManager hotkey detection

**Steps**:
1. Find your configured hotkey (default often `Cmd+Shift+V` or similar)
2. Press the hotkey to toggle Vietnamese input off
3. Type: `viet nam`
4. Expected: `viet nam` (not converted)
5. Press hotkey again to toggle on
6. Type: `viet nam`
7. Expected: `việt nam` (converted)

**What's being tested**:
- `PHTVHotkeyManager.checkHotKey()` with XOR-based modifier validation
- `hotkeyModifiersAreHeld()` for combo detection
- Modifier-only hotkey detection (0xFE)

---

### 6. Accessibility API Text Replacement Test
**Objective**: Verify PHTVAccessibilityManager text replacement via AX

**Steps**:
1. Open Notes.app
2. Type a long word with accents: `hoaøng`
3. Press backspace to correct
4. Expected: Should delete properly
5. Type correction: `hoàng`
6. Expected: Should replace correctly

**What's being tested**:
- `PHTVAccessibilityManager.replaceFocusedTextViaAX()` (130-line implementation)
- Unicode composed/decomposed character handling
- AX API retry logic (3 attempts with progressive delays)

---

### 7. App Switching Performance Test
**Objective**: Verify caching performance during rapid app switching

**Steps**:
1. Open 3-4 different apps (TextEdit, Safari, Terminal, Notes)
2. Rapidly switch between them (Cmd+Tab)
3. Type Vietnamese in each app immediately after switching
4. Expected: No lag, immediate response, correct behavior per app

**What's being tested**:
- `PHTVCacheManager` thread-safe caching with os_unfair_lock
- PID cache cleanup (60s interval)
- App characteristics cache hit rate
- No race conditions during app switching

---

### 8. Safe Mode Test
**Objective**: Verify Safe Mode fallback for system processes

**Steps**:
1. Try to type in system dialogs (e.g., "Shut Down" confirmation)
2. Expected: Vietnamese input should be disabled automatically
3. Return to normal app
4. Expected: Vietnamese input should work again

**What's being tested**:
- Safe Mode detection in all managers
- Fallback to non-Vietnamese for system processes
- Process name detection via proc_pidpath

---

## Performance Expectations

### Manager Performance Targets (from design):
- **Cache lookups**: < 1μs (os_unfair_lock)
- **App detection**: O(1) NSSet containsObject
- **Spotlight cache**: 50ms TTL (reduces AX API calls by 95%+)
- **PID cache**: 60s cleanup interval
- **AX API**: 3 retries with 0/3ms/8ms delays

### What to watch for:
- No typing lag when switching apps
- Spotlight opens/closes smoothly
- No beach ball cursor during Vietnamese typing
- Memory stable (no leaks from caching)

---

## Known Limitations

1. **EventSynthesis Manager**: NOT extracted (kept in PHTV.mm)
   - Reason: Too many global variable dependencies
   - Functions: Send*() family (SendDeleteKey, SendString, etc.)

2. **Full Hotkey Manager**: Partially extracted
   - ✅ Extracted: checkHotKey, hotkeyModifiersAreHeld, isModifierOnlyHotkey
   - ❌ Kept in PHTV.mm: switchLanguage, handleMacro (appDelegate dependency)

3. **Timing Manager**: Basic implementation
   - Only constants and conversion utilities
   - No complex timing logic

---

## Rollback Plan

If any test fails, you can disable managers individually:

1. Open [PHTV.mm:34-37](PHTV/Core/PHTV.mm#L34-L37)
2. Change `#define USE_NEW_XXX 1` to `#define USE_NEW_XXX 0`
3. Rebuild the project
4. The old code will be used instead

Example:
```objc
#define USE_NEW_CACHE 0           // Disable new cache manager
#define USE_NEW_APP_DETECTION 1   // Keep using new app detection
#define USE_NEW_SPOTLIGHT 1       // Keep using new spotlight
#define USE_NEW_ACCESSIBILITY 1   // Keep using new accessibility
```

---

## Next Steps After Testing

If all tests pass:
1. ✅ Mark Phase 6 as complete
2. Optional Phase 7: Remove `#ifdef` blocks and old code
3. Optional: Extract remaining EventSynthesis manager (if desired)
4. Commit final changes

If tests fail:
1. Document which test failed
2. Use rollback plan to identify which manager has issues
3. Debug and fix the specific manager
4. Re-test

---

## Quick Health Check

Run this command to verify app is still running without crashes:
```bash
ps aux | grep PHTV.app | grep -v grep && echo "✅ App running" || echo "❌ App crashed"
```

Check for crash reports:
```bash
ls -lt ~/Library/Logs/DiagnosticReports/PHTV* 2>/dev/null | head -5
```

---

## Summary

- **Build**: ✅ Success
- **Runtime**: ✅ No crashes
- **Managers**: ✅ All linked
- **Ready for**: Manual functional testing

Please run through the 8 test cases above and report any issues you encounter.
