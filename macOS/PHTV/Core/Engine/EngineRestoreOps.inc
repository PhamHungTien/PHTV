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

