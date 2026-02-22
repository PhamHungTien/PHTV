static inline bool isSpellCheckingEnabled() {
    return phtvRuntimeCheckSpellingValue() != 0;
}

static inline void setSpellCheckingEnabled(const bool enabled) {
    phtvRuntimeSetCheckSpellingValue(enabled ? 1 : 0);
}

void vPrimeUpperCaseFirstChar() {
    if (phtvRuntimeUpperCaseFirstCharEnabled() && !phtvRuntimeUpperCaseExcludedForCurrentApp()) {
        _upperCaseStatus = 2; // Ready to uppercase the next valid character
    }
}

void* vKeyInit() {
    refreshRuntimeLayoutSnapshot();
    _index = 0;
    _stateIndex = 0;
    _useSpellCheckingBefore = isSpellCheckingEnabled();
    _typingStatesData.clear();
    _typingStates.clear();
    _longWordHelper.clear();
    vPrimeUpperCaseFirstChar();
    return &HookState;
}

#include "EngineWordBreakHeuristics.inc"
void setKeyData(const Byte& index, const Uint16& keyCode, const bool& isCaps) {
    if (index < 0 || index >= MAX_BUFF)
        return;
    TypingWord[index] = keyCode | (isCaps ? CAPS_MASK : 0);
}

