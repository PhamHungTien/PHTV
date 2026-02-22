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

