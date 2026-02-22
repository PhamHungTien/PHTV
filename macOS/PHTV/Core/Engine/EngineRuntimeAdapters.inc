static vector<Uint8> _charKeyCode = {
    KEY_BACKQUOTE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUALS,
    KEY_LEFT_BRACKET, KEY_RIGHT_BRACKET, KEY_BACK_SLASH,
    KEY_SEMICOLON, KEY_QUOTE, KEY_COMMA, KEY_DOT, KEY_SLASH
};

static vector<Uint8> _breakCode = {
    KEY_ESC, KEY_TAB, KEY_ENTER, KEY_RETURN, KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_COMMA, KEY_DOT,
    KEY_SLASH, KEY_SEMICOLON, KEY_QUOTE, KEY_BACK_SLASH, KEY_MINUS, KEY_EQUALS, KEY_BACKQUOTE, KEY_TAB
};

static vector<Uint8> _macroBreakCode = {
    KEY_RETURN, KEY_COMMA, KEY_DOT, KEY_SLASH, KEY_SEMICOLON, KEY_QUOTE, KEY_BACK_SLASH, KEY_MINUS, KEY_EQUALS
};

// PERFORMANCE OPTIMIZATION: O(1) lookup sets built from vectors above
// Initialized lazily on first use to avoid static initialization order issues
static std::unordered_set<Uint8> _breakCodeSet;
static std::unordered_set<Uint8> _macroBreakCodeSet;
static bool _lookupSetsInitialized = false;
static int runtimeInputTypeSnapshot = vTelex;
static int runtimeCodeTableSnapshot = 0;

static inline void refreshRuntimeLayoutSnapshot() {
    runtimeInputTypeSnapshot = phtvRuntimeInputTypeValue();
    runtimeCodeTableSnapshot = phtvRuntimeCodeTableValue();
}

static inline bool detectorIsEnglishWordFromKeyStates(const Uint32* keyStates, int stateIndex) {
    return phtvDetectorIsEnglishWordFromKeyStates(keyStates, stateIndex) != 0;
}

static inline bool detectorIsVietnameseWordFromKeyStates(const Uint32* keyStates, int stateIndex) {
    return phtvDetectorIsVietnameseWordFromKeyStates(keyStates, stateIndex) != 0;
}

static inline bool detectorShouldRestoreEnglishWord(const Uint32* keyStates, int stateIndex) {
    return phtvDetectorShouldRestoreEnglishWord(keyStates, stateIndex) != 0;
}

static std::string detectorKeyStatesToString(const Uint32* keyStates, int count) {
    if (!keyStates || count <= 0) {
        return std::string();
    }

    std::vector<char> outputBuffer(static_cast<size_t>(count) + 1, '\0');
    const int outputLength = phtvDetectorKeyStatesToAscii(
        keyStates,
        count,
        outputBuffer.data(),
        static_cast<int>(outputBuffer.size())
    );
    if (outputLength <= 0) {
        return std::string();
    }

    return std::string(outputBuffer.data(), static_cast<size_t>(outputLength));
}

static bool findMacro(vector<Uint32>& key, vector<Uint32>& macroContentCode) {
    for (size_t i = 0; i < key.size(); i++) {
        key[i] = getCharacterCode(key[i]);
    }

    const Uint32* keyBuffer = key.empty() ? nullptr : key.data();
    const int keyCount = static_cast<int>(key.size());

    const int requiredLength = phtvFindMacroContentForNormalizedKeys(
        keyBuffer,
        keyCount,
        phtvRuntimeAutoCapsMacroValue(),
        nullptr,
        0
    );
    if (requiredLength < 0) {
        macroContentCode.clear();
        return false;
    }

    if (requiredLength == 0) {
        macroContentCode.clear();
        return true;
    }

    macroContentCode.assign(static_cast<size_t>(requiredLength), 0);
    const int actualLength = phtvFindMacroContentForNormalizedKeys(
        keyBuffer,
        keyCount,
        phtvRuntimeAutoCapsMacroValue(),
        macroContentCode.data(),
        requiredLength
    );
    if (actualLength < 0) {
        macroContentCode.clear();
        return false;
    }

    if (actualLength < requiredLength) {
        macroContentCode.resize(static_cast<size_t>(actualLength));
    }

    return true;
}

