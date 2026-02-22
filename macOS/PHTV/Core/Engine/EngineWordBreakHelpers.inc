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

