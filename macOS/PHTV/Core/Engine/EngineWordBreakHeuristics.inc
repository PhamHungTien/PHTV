bool isWordBreak(const vKeyEvent& event, const vKeyEventState& state, const Uint16& data) {
    if (event == vKeyEvent::Mouse)
        return true;

    // PERFORMANCE OPTIMIZATION: Lazy init lookup set for O(1) instead of O(n)
    if (!_lookupSetsInitialized) {
        _breakCodeSet.insert(_breakCode.begin(), _breakCode.end());
        _macroBreakCodeSet.insert(_macroBreakCode.begin(), _macroBreakCode.end());
        _lookupSetsInitialized = true;
    }

    return _breakCodeSet.count(data) > 0;
}

bool isMacroBreakCode(const int& data) {
    // PERFORMANCE OPTIMIZATION: Use O(1) set lookup instead of O(n) vector scan
    if (!_lookupSetsInitialized) {
        _breakCodeSet.insert(_breakCode.begin(), _breakCode.end());
        _macroBreakCodeSet.insert(_macroBreakCode.begin(), _macroBreakCode.end());
        _lookupSetsInitialized = true;
    }

    return _macroBreakCodeSet.count(data) > 0;
}

static inline bool isBracketPunctuationBreak(const Uint16& data) {
    return data == KEY_LEFT_BRACKET || data == KEY_RIGHT_BRACKET;
}

static inline bool isShiftedNumericPunctuationBreak(const Uint16& data, const Uint8& capsStatus) {
    if (capsStatus != 1) {
        return false;
    }

    // Shift+1 => !, Shift+9 => (, Shift+0 => )
    return data == KEY_1 || data == KEY_9 || data == KEY_0;
}

static inline bool isAutoRestoreWordBreak(const vKeyEvent& event,
                                          const vKeyEventState& state,
                                          const Uint16& data,
                                          const Uint8& capsStatus) {
    return isWordBreak(event, state, data) ||
           isBracketPunctuationBreak(data) ||
           isShiftedNumericPunctuationBreak(data, capsStatus);
}

static inline bool isLikelyUppercaseAbbreviation(const Uint32* keyStates, int count) {
    if (count <= 0) return false;
    if (count > 12) return false;

    // Numeric token like "3." -> not a sentence break (decimal or list)
    bool allDigits = true;
    for (int i = 0; i < count; i++) {
        Uint16 kc = keyStates[i] & 0x3F;
        if (!IS_NUMBER_KEY(kc)) {
            allDigits = false;
            break;
        }
    }
    if (allDigits) return true;

    // Single-letter initials like "A." or "U."
    if (count == 1) return true;

    // Small abbreviation list (lowercase)
    if (count <= 5) {
        std::string word = detectorKeyStatesToString(keyStates, count);
        if ((int)word.size() == count) {
            static const std::unordered_set<std::string> kAbbrev = {
                "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st",
                "vs", "etc", "eg", "ie",
                "tp", "q", "p", "ths", "ts", "gs", "pgs"
            };
            if (kAbbrev.count(word)) return true;
        }
    }

    return false;
}

static inline bool isSentenceTerminator(const Uint16& data, const Uint8& capsStatus) {
    if (data == KEY_ENTER || data == KEY_RETURN) {
        return true;
    }

    // '.' should not trigger when Shift is held (">")
    if (data == KEY_DOT && capsStatus != 1) {
        if (isLikelyUppercaseAbbreviation(KeyStates, _stateIndex)) {
            return false;
        }
        return true;
    }

    // Shift + '/' => '?', Shift + '1' => '!'
    if (capsStatus == 1 && (data == KEY_SLASH || data == KEY_1)) {
        return true;
    }

    return false;
}

static inline bool isUppercaseSkippablePunctuation(const Uint16& data, const Uint8& capsStatus) {
    if (data == KEY_QUOTE) { // ' or "
        return true;
    }

    if (data == KEY_LEFT_BRACKET || data == KEY_RIGHT_BRACKET) { // [ ] or { }
        return true;
    }

    if (capsStatus == 1 && (data == KEY_9 || data == KEY_0)) { // ( or )
        return true;
    }

    return false;
}

static inline bool isEnglishLetterKeyCode(const Uint16& keyCode) {
    switch (keyCode) {
        case KEY_A: case KEY_B: case KEY_C: case KEY_D: case KEY_E:
        case KEY_F: case KEY_G: case KEY_H: case KEY_I: case KEY_J:
        case KEY_K: case KEY_L: case KEY_M: case KEY_N: case KEY_O:
        case KEY_P: case KEY_Q: case KEY_R: case KEY_S: case KEY_T:
        case KEY_U: case KEY_V: case KEY_W: case KEY_X: case KEY_Y:
        case KEY_Z:
            return true;
        default:
            return false;
    }
}

static inline bool isDigitKeyCode(const Uint16& keyCode) {
    switch (keyCode) {
        case KEY_0: case KEY_1: case KEY_2: case KEY_3: case KEY_4:
        case KEY_5: case KEY_6: case KEY_7: case KEY_8: case KEY_9:
            return true;
        default:
            return false;
    }
}

static inline int getEnglishLookupStateLength() {
    int lookupLen = _stateIndex;
    // Defensive trim: if a non-letter key was ever appended to KeyStates,
    // do not include it in English dictionary lookup.
    while (lookupLen > 0) {
        Uint16 keyCode = static_cast<Uint16>(KeyStates[lookupLen - 1] & CHAR_MASK);
        if (isEnglishLetterKeyCode(keyCode)) {
            break;
        }
        lookupLen--;
    }
    return lookupLen;
}

static inline bool hasOnlyTrailingDigitKeyStates(const int startIndex) {
    if (startIndex < 0 || startIndex >= _stateIndex) return false;
    for (int idx = startIndex; idx < _stateIndex; idx++) {
        Uint16 keyCode = static_cast<Uint16>(KeyStates[idx] & CHAR_MASK);
        if (!isDigitKeyCode(keyCode)) {
            return false;
        }
    }
    return true;
}

static inline bool hasOnlyEnglishLetterKeyStates(const int length) {
    if (length <= 0) return false;
    for (int idx = 0; idx < length; idx++) {
        Uint16 keyCode = static_cast<Uint16>(KeyStates[idx] & CHAR_MASK);
        if (!isEnglishLetterKeyCode(keyCode)) {
            return false;
        }
    }
    return true;
}

static inline bool hasVietnameseTransformsInTypingWord(const int length) {
    if (length <= 0) return false;
    for (int idx = 0; idx < length && idx < MAX_BUFF; idx++) {
        if (TypingWord[idx] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
            return true;
        }
    }
    return false;
}

