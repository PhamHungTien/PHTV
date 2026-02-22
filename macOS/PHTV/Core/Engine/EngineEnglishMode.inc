void vEnglishMode(const vKeyEventState& state, const Uint16& data, const bool& isCaps, const bool& otherControlKey) {
    refreshRuntimeLayoutSnapshot();
    hCode = vDoNothing;
    if (state == vKeyEventState::MouseDown || (otherControlKey && !isCaps)) {
        hMacroKey.clear();
        _hasHandledMacro = false;  // Reset when starting new word
        _willTempOffEngine = false;
    } else if (data == KEY_SPACE || isMacroBreakCode(data)) {
        // Check macro for SPACE and other macro break codes (Enter, comma, dot, etc.)
        if (!_hasHandledMacro && findMacro(hMacroKey, hMacroData)) {
            hCode = vReplaceMaro;
            hBPC = (Byte)hMacroKey.size();
        }
        hMacroKey.clear();
        _hasHandledMacro = false;  // Reset when starting new word
        _willTempOffEngine = false;
    } else if (data == KEY_DELETE) {
        if (hMacroKey.size() > 0) {
            hMacroKey.pop_back();
        } else {
            _willTempOffEngine = false;
        }
    } else {
        if (isWordBreak(vKeyEvent::Keyboard, state, data) &&
            std::find(_charKeyCode.begin(), _charKeyCode.end(), data) == _charKeyCode.end()) {
            hMacroKey.clear();
            _hasHandledMacro = false;  // Reset when starting new word
            _willTempOffEngine = false;
        } else {
            if (!_willTempOffEngine)
                hMacroKey.push_back(data | (isCaps ? CAPS_MASK : 0));
        }
    }
}
