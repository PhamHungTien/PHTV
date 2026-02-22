void handleQuickTelex(const Uint16& data, const bool& isCaps) {
    hCode = vWillProcess;
    hBPC = 1;
    hNCC = 2;
    hData[1] = _quickTelex[data][0] | (isCaps ? CAPS_MASK : 0);
    hData[0] = _quickTelex[data][1] | (isCaps ? CAPS_MASK : 0);
    insertKey(_quickTelex[data][1], isCaps, false);
}

/**
 * Restore to raw keys - restore typed Vietnamese text to original ASCII keys
 * Called when the restore key is pressed (customizable: ESC, Option, Control)
 * Example: "úẻ" (from typing "user" in Telex) → "user"
 */
bool restoreToRawKeys() {
    if (_stateIndex == 0 || _index == 0) {
        return false;
    }

    // Check if any transforms were applied
    bool hasTransforms = false;
    for (ii = 0; ii < _index; ii++) {
        if ((TypingWord[ii] & MARK_MASK) || (TypingWord[ii] & TONE_MASK) ||
            (TypingWord[ii] & TONEW_MASK) || (TypingWord[ii] & STANDALONE_MASK)) {
            hasTransforms = true;
            break;
        }
    }

    if (!hasTransforms) {
        return false;
    }

    // Restore to original key states
    hCode = vRestore;
    hBPC = _index;
    hNCC = _stateIndex;

    for (i = 0; i < _stateIndex; i++) {
        TypingWord[i] = KeyStates[i];
        hData[_stateIndex - 1 - i] = KeyStates[i];
    }
    _index = _stateIndex;

    return true;
}

bool checkRestoreIfWrongSpelling(const int& handleCode) {
    for (ii = 0; ii < _index; ii++) {
        if (!IS_CONSONANT(CHR(ii)) &&
            (TypingWord[ii] & MARK_MASK || TypingWord[ii] & TONE_MASK || TypingWord[ii] & TONEW_MASK)) {
            
            hCode = handleCode;
            hBPC = _index;
            hNCC = _stateIndex;
            for (i = 0; i < _stateIndex; i++) {
                TypingWord[i] = KeyStates[i];
                hData[_stateIndex - 1 - i] = TypingWord[i];
            }
            _index = _stateIndex;
            return true;
        }
    }
    return false;
}

void vTempOffSpellChecking() {
    if (_useSpellCheckingBefore) {
        setSpellCheckingEnabled(!isSpellCheckingEnabled());
    }
}

void vSetCheckSpelling() {
    _useSpellCheckingBefore = isSpellCheckingEnabled();
}

void vTempOffEngine(const bool& off) {
    _willTempOffEngine = off;
}

bool vRestoreToRawKeys() {
    return restoreToRawKeys();
}

bool checkQuickConsonant() {
    if (_index <= 1) return false;
    const bool quickStartConsonantEnabled = phtvRuntimeQuickStartConsonantEnabled() != 0;
    const bool quickEndConsonantEnabled = phtvRuntimeQuickEndConsonantEnabled() != 0;
    l = 0;
    if (_index > 0) {
        if (quickStartConsonantEnabled && _quickStartConsonant.find(CHR(0)) != _quickStartConsonant.end()) {
            hCode = vRestore;
            hBPC = _index;
            hNCC = _index + 1;
            if (_index < MAX_BUFF-1)
                _index++;
            //right shift
            for (i = _index-1; i >= 2; i--) {
                TypingWord[i] = TypingWord[i-1];
            }
            TypingWord[1] = _quickStartConsonant[CHR(0)][1] | ((TypingWord[0] & CAPS_MASK) && (TypingWord[2] & CAPS_MASK) ? CAPS_MASK : 0);
            TypingWord[0] = _quickStartConsonant[CHR(0)][0] | (TypingWord[0] & CAPS_MASK ? CAPS_MASK : 0);
            l = 1;;
        }
        if (quickEndConsonantEnabled &&
            (_index-2 >= 0 && !IS_CONSONANT(CHR(_index-2))) &&
            _quickEndConsonant.find(CHR(_index-1)) != _quickEndConsonant.end()) {
            hCode = vRestore;
            if (l == 1) {
                hNCC++;
            } else {
                hBPC = 1;
                hNCC = 2;
            }
            if (_index < MAX_BUFF-1)
                _index++;
            TypingWord[_index-1] = _quickEndConsonant[CHR(_index-2)][1] | (TypingWord[_index-2] & CAPS_MASK ? CAPS_MASK : 0);
            TypingWord[_index-2] = _quickEndConsonant[CHR(_index-2)][0] | (TypingWord[_index-2] & CAPS_MASK ? CAPS_MASK : 0);
            
            l = 1;
        }
        if (l == 1) {
            _hasHandleQuickConsonant = true;
            for (i = _index - 1; i >= 0; i--) {
                hData[_index - 1 - i] = GET(TypingWord[i]);
            }
            return true;
        }
    }
    return false;
}
