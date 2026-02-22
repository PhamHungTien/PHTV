#include "EngineRuntimeAdapters.inc"
static Uint16 ProcessingChar[][11] = {
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z}, //Telex
    {KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0}, //VNI
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z}, //Simple Telex 1
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z} //Simple Telex 2
};

#define IS_KEY_Z(key) (ProcessingChar[runtimeInputTypeSnapshot][10] == key)
#define IS_KEY_D(key) (ProcessingChar[runtimeInputTypeSnapshot][9] == key)
#define IS_KEY_W(key) ((runtimeInputTypeSnapshot != vVNI) ? ProcessingChar[runtimeInputTypeSnapshot][8] == key : \
                                    (runtimeInputTypeSnapshot == vVNI ? (ProcessingChar[runtimeInputTypeSnapshot][8] == key || ProcessingChar[runtimeInputTypeSnapshot][7] == key) : false))
#define IS_KEY_DOUBLE(key) ((runtimeInputTypeSnapshot != vVNI) ? (ProcessingChar[runtimeInputTypeSnapshot][5] == key || ProcessingChar[runtimeInputTypeSnapshot][6] == key || ProcessingChar[runtimeInputTypeSnapshot][7] == key) :\
                                        (runtimeInputTypeSnapshot == vVNI ? ProcessingChar[runtimeInputTypeSnapshot][6] == key : false))
#define IS_KEY_S(key) (ProcessingChar[runtimeInputTypeSnapshot][0] == key)
#define IS_KEY_F(key) (ProcessingChar[runtimeInputTypeSnapshot][1] == key)
#define IS_KEY_R(key) (ProcessingChar[runtimeInputTypeSnapshot][2] == key)
#define IS_KEY_X(key) (ProcessingChar[runtimeInputTypeSnapshot][3] == key)
#define IS_KEY_J(key) (ProcessingChar[runtimeInputTypeSnapshot][4] == key)

#define IS_MARK_KEY(keyCode) (((runtimeInputTypeSnapshot != vVNI) && (keyCode == KEY_S || keyCode == KEY_F || keyCode == KEY_R || keyCode == KEY_J || keyCode == KEY_X)) || \
                                        (runtimeInputTypeSnapshot == vVNI && (keyCode == KEY_1 || keyCode == KEY_2 || keyCode == KEY_3 || keyCode == KEY_5 || keyCode == KEY_4)))
#define IS_BRACKET_KEY(key) (key == KEY_LEFT_BRACKET || key == KEY_RIGHT_BRACKET)

static inline bool isSpecialKeyForCurrentInputType(const Uint16 keyCode) {
    switch (runtimeInputTypeSnapshot) {
    case vTelex:
        return keyCode == KEY_W || keyCode == KEY_E || keyCode == KEY_R || keyCode == KEY_O ||
               keyCode == KEY_LEFT_BRACKET || keyCode == KEY_RIGHT_BRACKET || keyCode == KEY_A ||
               keyCode == KEY_S || keyCode == KEY_D || keyCode == KEY_F || keyCode == KEY_J ||
               keyCode == KEY_Z || keyCode == KEY_X;
    case vVNI:
        return keyCode == KEY_1 || keyCode == KEY_2 || keyCode == KEY_3 || keyCode == KEY_4 ||
               keyCode == KEY_5 || keyCode == KEY_6 || keyCode == KEY_7 || keyCode == KEY_8 ||
               keyCode == KEY_9 || keyCode == KEY_0;
    case vSimpleTelex1:
    case vSimpleTelex2:
        return keyCode == KEY_W || keyCode == KEY_E || keyCode == KEY_R || keyCode == KEY_O ||
               keyCode == KEY_A || keyCode == KEY_S || keyCode == KEY_D || keyCode == KEY_F ||
               keyCode == KEY_J || keyCode == KEY_Z || keyCode == KEY_X;
    default:
        return false;
    }
}

#undef IS_SPECIALKEY
#define IS_SPECIALKEY(keyCode) isSpecialKeyForCurrentInputType(keyCode)

#define VSI vowelStartIndex
#define VEI vowelEndIndex
#define VWSM vowelWillSetMark
#define hBPC HookState.backspaceCount
#define hNCC HookState.newCharCount
#define hCode HookState.code
#define hExt HookState.extCode
#define hData HookState.charData
#define GET getCharacterCode
#define hMacroKey HookState.macroKey
#define hMacroData HookState.macroData

//Data to sendback to main program
vKeyHookState HookState;

//private data
/**
 * data structure of each element in TypingWord (Uint64)
 * first 2 byte is character code or key code.
 * bit 16: has caps or not
 * bit 17: has tone ^ or not
 * bit 18: has tone w or not
 * bit 19 - > 23: has mark or not (Sắc, huyền, hỏi, ngã, nặng)
 * bit 24: is standalone key? (w, [, ])
 * bit 25: is character code or keyboard code; 1: character code; 0: keycode
 */
static Uint32 TypingWord[MAX_BUFF];
static Byte _index = 0;
static vector<Uint32> _longWordHelper; //save the word when _index >= MAX_BUFF
static list<vector<Uint32>> _typingStates; //Aug 28th, 2019: typing helper, save long state of Typing word, can go back and modify the word
vector<Uint32> _typingStatesData;

/**
 * Use for restore key if invalid word
 */
static Uint32 KeyStates[MAX_BUFF];
static Byte _stateIndex = 0;

static bool tempDisableKey = false;

static inline bool isVietnameseWordFromTypingWord(const int length) {
    if (length <= 0) return false;
    Uint32 buf[32];
    int len = length > 30 ? 30 : length;
    for (int i = 0; i < len; i++) {
        buf[i] = TypingWord[i] & 0x3F;
    }
    return detectorIsVietnameseWordFromKeyStates(buf, len);
}

/**
 * Convert TypingWord back to canonical Telex keycodes and check Vietnamese dictionary.
 * This handles ALL alternative Telex typing orders:
 *   - "dods" (d-o-d-s) → canonical "ddos" (đó) ✓
 *   - "wf" (standalone W+f) → canonical "uwf" (ừ) ✓
 *   - Any reordered Telex pattern that the engine processed correctly
 *
 * Returns true if the canonical Telex form is a Vietnamese word.
 */
static bool isVietnameseFromCanonicalTelex(const int length) {
    if (length <= 0) return false;

    Uint32 buf[64]; // Canonical Telex can be longer than TypingWord
    int len = 0;
    Uint32 toneKey = 0; // Tone mark key to append at end (end-tone variant)

    for (int i = 0; i < length && len < 60; i++) {
        Uint32 tw = TypingWord[i];
        Uint32 baseKey = tw & 0x3F;

        // đ: KEY_D with TONE_MASK → "dd"
        if (baseKey == KEY_D && (tw & TONE_MASK)) {
            buf[len++] = KEY_D;
            buf[len++] = KEY_D;
        }
        // Vowel with TONE_MASK (â, ê, ô) → double the vowel
        else if (!(tw & STANDALONE_MASK) && (tw & TONE_MASK) && !IS_CONSONANT(baseKey)) {
            buf[len++] = baseKey;
            buf[len++] = baseKey;
        }
        // Normal character
        else {
            buf[len++] = baseKey;
        }

        // TONEW_MASK (ă, ơ, ư) → append W
        if (tw & (TONEW_MASK | STANDALONE_MASK)) {
            // For standalone ư (KEY_U with STANDALONE), base is already KEY_U
            // For normal aw/ow/uw, base is the vowel
            if (len < 62) buf[len++] = KEY_W;
        }

        // Collect tone mark (only one per word, applied at end)
        if (tw & MARK1_MASK) toneKey = KEY_S;       // sắc
        else if (tw & MARK2_MASK) toneKey = KEY_F;   // huyền
        else if (tw & MARK3_MASK) toneKey = KEY_R;   // hỏi
        else if (tw & MARK4_MASK) toneKey = KEY_X;   // ngã
        else if (tw & MARK5_MASK) toneKey = KEY_J;   // nặng
    }

    // Append tone mark at end (end-tone variant, always in Vietnamese dictionary)
    if (toneKey && len < 62) {
        buf[len++] = toneKey;
    }

    if (len < 2) return false; // Too short for dictionary lookup
    return detectorIsVietnameseWordFromKeyStates(buf, len);
}

static int capsElem;
static int key;
static int markElem;
static bool isCorect = false;
static bool isChanged = false;
static Byte vowelCount = 0;
static Byte vowelStartIndex = 0;
static Byte vowelEndIndex = 0;
static Byte vowelWillSetMark = 0;
static int i, ii, iii;
static int j;
static int k, kk;
static int l;
static bool isRestoredW;
static Uint16 keyForAEO;
static bool isCheckedGrammar;
static bool _isCaps = false;
static int _spaceCount = 0; //add: July 30th, 2019
static bool _hasHandledMacro = false; //for macro flag August 9th, 2019
static volatile Byte _upperCaseStatus = 0; //for Write upper case for the first letter; 2: will upper case (VOLATILE for thread safety)
static bool _upperCaseNeedsSpaceConfirm = false; //true when uppercase was triggered by . ? ! (needs space before capitalizing)
static bool _shouldUpperCaseEnglishRestore = false; //track if English restore should uppercase first char
static volatile Byte _snapshotUpperCaseFirstChar = 0; // snapshot uppercase-first setting at session start (prevents mid-typing setting changes)
static bool _isCharKeyCode;
static vector<Uint32> _specialChar;
static bool _useSpellCheckingBefore;
static bool _hasHandleQuickConsonant;
static bool _willTempOffEngine = false;

//function prototype
void findAndCalculateVowel(const bool& forGrammar=false);
void insertMark(const Uint32& markMask, const bool& canModifyFlag=true);

#include "EngineSessionBootstrap.inc"
#include "EngineSpellingCheck.inc"
#include "EngineGrammarCheck.inc"
#include "EngineSessionStateOps.inc"
#include "EngineCharacterTransform.inc"
#include "EngineMarkHandling.inc"

#include "EngineStandaloneAndCaps.inc"

#include "EngineMainKeyHandling.inc"

#include "EngineRestoreAndQuickConsonant.inc"
/*==========================================================================================================*/

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

void vKeyHandleEvent(const vKeyEvent& event,
                     const vKeyEventState& state,
                     const Uint16& data,
                     const Uint8& capsStatus,
                     const bool& otherControlKey) {
    refreshRuntimeLayoutSnapshot();

    // PERFORMANCE: Debug logging only in debug builds (hot path - called on every keystroke)
    #ifdef DEBUG
    static int lastInputType = -1;
    if (runtimeInputTypeSnapshot != lastInputType) {
        printf("[Engine] vInputType CHANGED TO %d (was %d)\n", runtimeInputTypeSnapshot, lastInputType);
        fflush(stdout);
        lastInputType = runtimeInputTypeSnapshot;
    }
    #endif

    // NEW FEATURE: Restore key - ESC only
    // Note: Modifier keys (Option, Control) are handled in PHTV.mm via kCGEventFlagsChanged
    // We ONLY handle ESC key here to avoid conflicts with typing (e.g. VNI number keys)
    if (phtvRuntimeRestoreOnEscapeEnabled() && _index > 0 && data == KEY_ESC) {
        if (restoreToRawKeys()) {
            // Successfully restored - let the engine handle vRestore code
            // Don't call startNewSession() here as it will clear hCode
            // The vRestore code will be processed and session will be cleared later
            return;
        }
    }

    _isCaps = (capsStatus == 1 || //shift
               capsStatus == 2); //caps lock
    const bool isAutoRestoreBreakKey = isAutoRestoreWordBreak(event, state, data, capsStatus);
    if ((IS_NUMBER_KEY(data) && capsStatus == 1)
        || otherControlKey || isAutoRestoreBreakKey || (_index == 0 && IS_NUMBER_KEY(data))) {
        hCode = vDoNothing;
        hBPC = 0;
        hNCC = 0;
        hExt = 1; //word break
        
        //check macro feature
        if (phtvRuntimeUseMacroEnabled() && isMacroBreakCode(data) && !_hasHandledMacro && findMacro(hMacroKey, hMacroData)) {
            hCode = vReplaceMaro;
            hBPC = (Byte)hMacroKey.size();
            _hasHandledMacro = true;
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] CONFLICT: Macro matched, auto English skipped\n"); fflush(stderr);
            #endif
        } else if (phtvRuntimeAutoRestoreEnglishWordEnabled() && isAutoRestoreBreakKey) {
            // PRIORITY FIX: Check Auto English BEFORE Quick Consonant
            // Auto English should have higher priority to prevent conflicts
            // (e.g., "search." ending in "ch" shouldn't trigger Quick Consonant)
            #ifdef DEBUG
            const char* eventType = (event == vKeyEvent::Mouse) ? "Mouse" : "Keyboard";
            const char* stateType = (state == KeyDown) ? "KeyDown" : (state == KeyUp) ? "KeyUp" : (state == MouseDown) ? "MouseDown" : "MouseUp";
            fprintf(stderr, "[AutoEnglish] WORD BREAK detected: event=%s, state=%s, _stateIndex=%d, _index=%d, data=0x%X\n",
                   eventType, stateType, _stateIndex, _index, data);
            fflush(stderr);
            #endif
            if (isSpellCheckingEnabled()) {
                checkSpelling(true);
            }
            bool shouldRestoreEnglish = false;
            int englishStateIndex = getEnglishLookupStateLength();
            bool isPureLetterToken = (englishStateIndex == _stateIndex) &&
                                     hasOnlyEnglishLetterKeyStates(_stateIndex);
            bool isLetterWithNumericSuffixToken =
                (englishStateIndex > 0 && englishStateIndex < _stateIndex) &&
                hasOnlyEnglishLetterKeyStates(englishStateIndex) &&
                hasOnlyTrailingDigitKeyStates(englishStateIndex);
            bool canAutoRestoreToken = isPureLetterToken || isLetterWithNumericSuffixToken;
            int restoreStateIndex = isLetterWithNumericSuffixToken ? _stateIndex : englishStateIndex;

            if (englishStateIndex > 1 && canAutoRestoreToken) {
                shouldRestoreEnglish = detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex);
                if (!shouldRestoreEnglish) {
                    if (detectorIsEnglishWordFromKeyStates(KeyStates, englishStateIndex) &&
                        !detectorIsVietnameseWordFromKeyStates(KeyStates, englishStateIndex) &&
                        !isVietnameseWordFromTypingWord(_index)) {
                        shouldRestoreEnglish = true;
                    }
                }

                // PROTECTION: Single-character Vietnamese words should never be restored
                // (Same protection as SPACE handler - see detailed comment there)
                if (shouldRestoreEnglish && _index == 1) {
                    if (TypingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: Single Vietnamese char (has marks)\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // CANONICAL TELEX CHECK (word break path)
                // (Same logic as SPACE handler - see detailed comment there)
                if (shouldRestoreEnglish) {
                    bool hasVietnameseMarks = false;
                    for (int k = 0; k < _index; k++) {
                        if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                            hasVietnameseMarks = true;
                            break;
                        }
                    }
                    if (hasVietnameseMarks && isVietnameseFromCanonicalTelex(_index)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: Canonical Telex is Vietnamese\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // Fix for "macoss" -> "macos": If user corrected the word manually (e.g. typing 's' to remove tone),
                // producing a clean English word in TypingWord, do not restore the raw keys (which might be "macoss").
                if (shouldRestoreEnglish) {
                    bool isTypingWordPureEnglish = true;
                    for (int k = 0; k < _index; k++) {
                        if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                            isTypingWordPureEnglish = false;
                            break;
                        }
                    }
                    if (isTypingWordPureEnglish && detectorIsEnglishWordFromKeyStates(TypingWord, _index)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE: TypingWord is already clean English\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // Mixed tokens like "power1" should restore only when Vietnamese transform happened
                // (e.g. "pơer1" -> "power1"), avoid no-op restore for plain "int1234".
                if (shouldRestoreEnglish && isLetterWithNumericSuffixToken &&
                    !hasVietnameseTransformsInTypingWord(_index)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: no Vietnamese transform in mixed token\n");
                    fflush(stderr);
                    #endif
                }
            }
            // IMPORTANT: Check _index > 0 (must have display chars) and englishStateIndex > 1 (at least 2 keys pressed)
            if (_index > 0 && restoreStateIndex > 1 && canAutoRestoreToken && shouldRestoreEnglish) {
                // Auto restore English word feature
                // checkIfEnglishWord returns true only if:
                // - Word exists in English dictionary AND
                // - Word does NOT exist in Vietnamese dictionary
                hCode = vRestoreAndStartNewSession;
                // SPACE FIX (WORD BREAK path): Use _index for backspace count
                // When Vietnamese processing combines chars (e.g., "search" → "sẻach"),
                // _stateIndex=6 but _index=5, so we must delete based on display count
                // to avoid deleting characters before the word
                hBPC = _index;  // Backspace count = display character count
                hNCC = restoreStateIndex;  // Insert count = original keystroke count (restore full mixed token if needed)
                hExt = 5;  // Signal: This is Auto English restore (not Text Replacement)
                for (i = 0; i < restoreStateIndex; i++) {
                    TypingWord[i] = KeyStates[i];
                    hData[restoreStateIndex - 1 - i] = KeyStates[i];
                }
                // Apply uppercase first character if enabled
                // Use _shouldUpperCaseEnglishRestore which was set when first char was typed
                // Also check if current app is NOT excluded from uppercase feature
                if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _shouldUpperCaseEnglishRestore && restoreStateIndex > 0) {
                    hData[restoreStateIndex - 1] |= CAPS_MASK;
                }
                _shouldUpperCaseEnglishRestore = false;
                _index = restoreStateIndex;
                // CRITICAL FIX: Reset session immediately to prevent state pollution
                // Without this, when typing fast or multiple words, _index/_stateIndex retain old values
                // causing intermittent failures ("sometimes works, sometimes doesn't")
                // This matches SPACE handler behavior (line 1573-1574)
                _index = 0;
                _stateIndex = 0;
                #ifdef DEBUG
                fprintf(stderr, "[AutoEnglish] ✓ WORD BREAK RESTORE: reset to _index=0, _stateIndex=0\n");
                fflush(stderr);
                #endif
            #ifdef DEBUG
            } else if (_stateIndex > 0) {
                std::string word = detectorKeyStatesToString(KeyStates, englishStateIndex);
                fprintf(stderr, "[AutoEnglish] ✗ WORD BREAK NO RESTORE: word='%s', _index=%d, _stateIndex=%d, blocked by: ",
                       word.c_str(), _index, _stateIndex);
                if (_index <= 0) fprintf(stderr, "_index<=0 ");
                if (englishStateIndex <= 1) fprintf(stderr, "englishStateIndex<=1 ");
                if (!canAutoRestoreToken) fprintf(stderr, "invalidTokenShape ");
                if (!detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex)) fprintf(stderr, "notEnglish ");
                fprintf(stderr, "\n");
                fflush(stderr);
            #endif
            }
        } else if ((phtvRuntimeQuickStartConsonantEnabled() || phtvRuntimeQuickEndConsonantEnabled()) && !tempDisableKey && isMacroBreakCode(data)) {
            // Quick Consonant for Vietnamese typing shortcuts
            // Now checked AFTER Auto English to avoid conflicts
            checkQuickConsonant();
        } else if (isAutoRestoreBreakKey) { //restore raw keys if word is invalid Vietnamese
            if (!tempDisableKey && isSpellCheckingEnabled()) {
                checkSpelling(true); //force check spelling before restore decision
            }
            if (tempDisableKey && !checkRestoreIfWrongSpelling(vRestoreAndStartNewSession)) {
                hCode = vDoNothing;
            }
        }
        
        _isCharKeyCode = state == KeyDown && std::find(_charKeyCode.begin(), _charKeyCode.end(), data) != _charKeyCode.end();
        if (!_isCharKeyCode) { //clear all line cache
            _specialChar.clear();
            _typingStates.clear();
        } else { //check and save current word
            if (_spaceCount > 0) {
                saveWord(KEY_SPACE, _spaceCount);
                _spaceCount = 0;
            } else {
                saveWord();
            }
            _specialChar.push_back(data | (_isCaps ? CAPS_MASK : 0));
            hExt = 3;//normal word
        }
        
        if (hCode == vDoNothing) {
            startNewSession();
            setSpellCheckingEnabled(_useSpellCheckingBefore);
            _willTempOffEngine = false;
        } else if (hCode == vReplaceMaro || _hasHandleQuickConsonant) {
            _index = 0;
            _hasHandledMacro = false;  // Reset for next macro
        }

        //insert key for macro function
        if (phtvRuntimeUseMacroEnabled()) {
            if (_isCharKeyCode) {
                hMacroKey.push_back(data | (_isCaps ? CAPS_MASK : 0));
            } else {
                hMacroKey.clear();
                _hasHandledMacro = false;  // Reset when starting new word
            }
        }

        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp()) {
            if (isSentenceTerminator(data, capsStatus)) {
                _upperCaseStatus = 2;
                // Period, question mark, exclamation need space before capitalizing (e.g. "iegglobal.vn" should not capitalize "v")
                // Enter/Return capitalize immediately (no space expected after newline)
                _upperCaseNeedsSpaceConfirm = (data != KEY_ENTER && data != KEY_RETURN);
            } else if (_upperCaseStatus > 0 && isUppercaseSkippablePunctuation(data, capsStatus)) {
                // Keep pending uppercase across quotes/brackets/parentheses
            } else {
                _upperCaseStatus = 0;
            }
        }
    } else if (data == KEY_SPACE) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SPACE pressed: _stateIndex=%d, _index=%d, tempDisableKey=%d\n",
               _stateIndex, _index, tempDisableKey);
        fflush(stderr);
        #endif
        // CRITICAL FIX: Always run checkSpelling() for Auto English
        // Even when tempDisableKey=true, we need accurate _index for Auto English check
        // This ensures _index is up-to-date before checking English words
        if (isSpellCheckingEnabled()) {
            checkSpelling(true); //force check spelling (ignore tempDisableKey for Auto English)
        }
        bool shouldRestoreEnglish = false;
        int englishStateIndex = getEnglishLookupStateLength();
        bool isPureLetterToken = (englishStateIndex == _stateIndex) &&
                                 hasOnlyEnglishLetterKeyStates(_stateIndex);
        bool isLetterWithNumericSuffixToken =
            (englishStateIndex > 0 && englishStateIndex < _stateIndex) &&
            hasOnlyEnglishLetterKeyStates(englishStateIndex) &&
            hasOnlyTrailingDigitKeyStates(englishStateIndex);
        bool canAutoRestoreToken = isPureLetterToken || isLetterWithNumericSuffixToken;
        int restoreStateIndex = isLetterWithNumericSuffixToken ? _stateIndex : englishStateIndex;

        if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _index > 0 && englishStateIndex > 1 && canAutoRestoreToken) {
            shouldRestoreEnglish = detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex);
            if (!shouldRestoreEnglish) {
                if (detectorIsEnglishWordFromKeyStates(KeyStates, englishStateIndex) &&
                    !detectorIsVietnameseWordFromKeyStates(KeyStates, englishStateIndex) &&
                    !isVietnameseWordFromTypingWord(_index)) {
                    shouldRestoreEnglish = true;
                }
            }
            
            // PROTECTION: Single-character Vietnamese words should never be restored
            // When _index==1 and TypingWord has Vietnamese marks, it's a processed Vietnamese character
            // that has no equivalent English word. Standalone W patterns (e.g., "wf" for "ừ")
            // are not in any dictionary, so they could slip through both primary and fallback checks.
            // Examples: ừ (wf), ớ (o[s), ứ (uws), ờ (owf), etc.
            if (shouldRestoreEnglish && _index == 1) {
                if (TypingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: Single Vietnamese char (has marks)\n");
                    fflush(stderr);
                    #endif
                }
            }

            // CANONICAL TELEX CHECK: Convert TypingWord to canonical Telex and verify against
            // Vietnamese dictionary. This catches ALL alternative Telex typing orders:
            //   "dods" → canonical "ddos" (đó) → Vietnamese → block restore
            //   "thoongr" → canonical "thoongr" (thỏng) → Vietnamese → block restore
            // The check only runs when TypingWord has Vietnamese marks (to avoid overhead
            // for pure English words like "search" where TypingWord base "seach" ≠ Vietnamese)
            if (shouldRestoreEnglish) {
                bool hasVietnameseMarks = false;
                for (int k = 0; k < _index; k++) {
                    if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                        hasVietnameseMarks = true;
                        break;
                    }
                }
                if (hasVietnameseMarks && isVietnameseFromCanonicalTelex(_index)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: Canonical Telex is Vietnamese\n");
                    fflush(stderr);
                    #endif
                }
            }

            // Fix for "macoss" -> "macos": If user corrected the word manually (e.g. typing 's' to remove tone),
            // producing a clean English word in TypingWord, do not restore the raw keys (which might be "macoss").
            if (shouldRestoreEnglish) {
                bool isTypingWordPureEnglish = true;
                for (int k = 0; k < _index; k++) {
                    if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                        isTypingWordPureEnglish = false;
                        break;
                    }
                }
                if (isTypingWordPureEnglish && detectorIsEnglishWordFromKeyStates(TypingWord, _index)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: TypingWord is already clean English\n");
                    fflush(stderr);
                    #endif
                }
            }

            // Mixed tokens like "power1" should restore only when Vietnamese transform happened
            // (e.g. "pơer1" -> "power1"), avoid no-op restore for plain "int1234".
            if (shouldRestoreEnglish && isLetterWithNumericSuffixToken &&
                !hasVietnameseTransformsInTypingWord(_index)) {
                shouldRestoreEnglish = false;
                #ifdef DEBUG
                fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: no Vietnamese transform in mixed token\n");
                fflush(stderr);
                #endif
            }
        }

        if (phtvRuntimeUseMacroEnabled() && !_hasHandledMacro && findMacro(hMacroKey, hMacroData)) { //macro
            hCode = vReplaceMaro;
            hBPC = (Byte)hMacroKey.size();
            _spaceCount++;
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] Macro matched, Auto English skipped\n");
            fflush(stderr);
            #endif
        } else if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _index > 0 && restoreStateIndex > 1 && canAutoRestoreToken && shouldRestoreEnglish) {
            // PRIORITY FIX: Check Auto English BEFORE Quick Consonant
            // Auto English should have higher priority to prevent conflicts
            // (e.g., "search" ending in "ch" shouldn't trigger Quick Consonant)
            // Auto restore English word on SPACE
            // checkIfEnglishWord returns true only if word is English AND NOT Vietnamese
            // SAFETY: _index > 0 ensures we have characters to delete (prevents deleting nothing)
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] ✓ SPACE RESTORE: _stateIndex=%d, _index=%d\n", _stateIndex, _index);
            fflush(stderr);
            #endif
            hCode = vRestore;
            // SPACE FIX: Use _index for backspace (delete only what's on screen)
            // When Vietnamese processing combines chars (e.g., "search" → "sẻach"),
            // _stateIndex=6 but _index=5, so we must delete based on display count
            // to avoid deleting the space before the word
            hBPC = _index;  // Backspace count = display character count
            hNCC = restoreStateIndex;  // Insert count = original keystroke count (restore full mixed token if needed)
            hExt = 5;  // Signal: This is Auto English restore (not Text Replacement)
            for (i = 0; i < restoreStateIndex; i++) {
                TypingWord[i] = KeyStates[i];
                hData[restoreStateIndex - 1 - i] = KeyStates[i];
            }
            // Apply uppercase first character if enabled
            // Use _shouldUpperCaseEnglishRestore which was set when first char was typed
            // Also check if current app is NOT excluded from uppercase feature
            if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _shouldUpperCaseEnglishRestore && restoreStateIndex > 0) {
                hData[restoreStateIndex - 1] |= CAPS_MASK;
            }
            _shouldUpperCaseEnglishRestore = false;
            _index = restoreStateIndex;
            _spaceCount++;
            // Reset session after restore to prevent re-triggering on next key (e.g., arrow keys)
            // This is different from vRestoreAndStartNewSession which also sends the break key
            _index = 0;
            _stateIndex = 0;
        } else if ((phtvRuntimeQuickStartConsonantEnabled() || phtvRuntimeQuickEndConsonantEnabled()) && !tempDisableKey && checkQuickConsonant()) {
            // Quick Consonant for Vietnamese typing shortcuts
            // Now checked AFTER Auto English to avoid conflicts
            _spaceCount++;
        } else if (tempDisableKey && !_hasHandledMacro) { //restore raw keys if word is invalid Vietnamese
            if (!checkRestoreIfWrongSpelling(vRestore)) {
                hCode = vDoNothing;
            }
            _spaceCount++;
        } else { //do nothing with SPACE KEY
            #ifdef DEBUG
            // Log why Auto English didn't trigger (for debugging random failures)
            if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _stateIndex > 0) {
                std::string word = detectorKeyStatesToString(KeyStates, englishStateIndex);
                fprintf(stderr, "[AutoEnglish] ✗ SPACE NO RESTORE: word='%s', _stateIndex=%d, _index=%d, blocked by: ",
                       word.c_str(), _stateIndex, _index);
                if (_index <= 0) fprintf(stderr, "_index<=0 ");
                if (englishStateIndex <= 1) fprintf(stderr, "englishStateIndex<=1 ");
                if (!canAutoRestoreToken) fprintf(stderr, "invalidTokenShape ");
                if (!detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex)) fprintf(stderr, "notEnglishWord ");
                fprintf(stderr, "\n");
                fflush(stderr);
            }
            #endif
            hCode = vDoNothing;
            _spaceCount++;
        }
        if (phtvRuntimeUseMacroEnabled()) {
            hMacroKey.clear();
            _hasHandledMacro = false;  // Reset when starting new word
        }
        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _upperCaseNeedsSpaceConfirm) {
            _upperCaseNeedsSpaceConfirm = false; // Space confirms: allow capitalize on next character
        }
        //save word
        if (_spaceCount == 1) {
            if (_specialChar.size() > 0) {
                saveSpecialChar();
            } else {
                saveWord();
            }
        }
        setSpellCheckingEnabled(_useSpellCheckingBefore);
        _willTempOffEngine = false;
    } else if (data == KEY_DELETE) {
        hCode = vDoNothing;
        hExt = 2; //delete
        tempDisableKey = false; // Reset temp disable on backspace
        if (_specialChar.size() > 0) {
            _specialChar.pop_back();
            if (_specialChar.size() == 0) {
                restoreLastTypingState();
            }
        } else if (_spaceCount > 0) { //previous char is space
            _spaceCount--;
            if (_spaceCount == 0) { //restore word
                restoreLastTypingState();
            }
        } else {
            if (_stateIndex > 0) {
                _stateIndex--;
            }
            if (_index > 0){
                _index--;
                if (_longWordHelper.size() > 0) {
                    //right shift
                    for (i = MAX_BUFF - 1; i > 0; i--) {
                        TypingWord[i] = TypingWord[i-1];
                    }
                    TypingWord[0] = _longWordHelper.back();
                    _longWordHelper.pop_back();
                    _index++;
                }
                if (isSpellCheckingEnabled())
                    checkSpelling();
            }
            if (phtvRuntimeUseMacroEnabled() && hMacroKey.size() > 0) {
                hMacroKey.pop_back();
            }
            
            hBPC = 0;
            hNCC = 0;
            hExt = 2; //delete key
            if (_index == 0) {
                // PERFORMANCE FIX: Removed file I/O from keystroke handler
                // Debug logging moved to stderr (use PHTV_DEBUG=1 environment variable)
                Byte savedUpperCaseStatus = _upperCaseStatus;
                bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
                startNewSession();
                _upperCaseStatus = savedUpperCaseStatus;
                _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
                _specialChar.clear();
                restoreLastTypingState();
            } else { //August 23rd continue check grammar
                checkGrammar(1);
            }
        }
    } else { //START AND CHECK KEY
        if (_willTempOffEngine) {
            hCode = vDoNothing;
            hExt = 3;
            return;
        }
        if (_spaceCount > 0) {
            hBPC = 0;
            hNCC = 0;
            hExt = 0;
            // FIX: Save space count BEFORE startNewSession() resets it
            int savedSpaceCount = _spaceCount;
            Byte savedUpperCaseStatus = _upperCaseStatus;
            bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
            startNewSession();
            _upperCaseStatus = savedUpperCaseStatus;
            _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
            //continue save space
            saveWord(KEY_SPACE, savedSpaceCount);
            // _spaceCount is already 0 from startNewSession()
        } else if (_specialChar.size() > 0) {
            saveSpecialChar();
        }

        insertState(data, _isCaps); //save state

        // If a tone mark is pressed while tempDisableKey is true, re-evaluate spelling.
        // This allows adding tone after finishing a word like "hưu" -> "hữu".
        bool allowMarkDespiteTempDisable = IS_MARK_KEY(data);

        // Also allow vowel modifiers to be applied even if tempDisableKey is true,
        // when the current word already has a tone/diacritic. This fixes cases like
        // "viejet" -> "việt" where the tone is typed before the vowel modifier.
        bool allowVowelChangeDespiteTempDisable = false;
        if (tempDisableKey && IS_SPECIALKEY(data) && !allowMarkDespiteTempDisable) {
            if (IS_KEY_DOUBLE(data) || IS_KEY_W(data) || IS_BRACKET_KEY(data)) {
                bool hasToneOrDiacritic = false;
                for (int scan = 0; scan < _index; scan++) {
                    if (TypingWord[scan] & (MARK_MASK | TONE_MASK | TONEW_MASK)) {
                        hasToneOrDiacritic = true;
                        break;
                    }
                }
                allowVowelChangeDespiteTempDisable = hasToneOrDiacritic;
            }
        }

        bool allowSpecialDespiteTempDisable = allowMarkDespiteTempDisable || allowVowelChangeDespiteTempDisable;
        if (isSpellCheckingEnabled() && allowSpecialDespiteTempDisable) {
            checkSpelling(true);
            
            // Fix for Issue #123: If word is invalid Vietnamese (tempDisableKey=true),
            // do not allow tone marks (s,f,r,x,j) to force themselves in.
            // This prevents "year" -> "yẻa", "string" -> "stríng", "global" -> "globá".
            // We only block MARK keys, allowing vowel corrections (aa, ee, dd) if they were allowed.
            if (tempDisableKey && allowMarkDespiteTempDisable) {
                // Allow tone marks when the word is Vietnamese-valid except for missing vowel modifiers
                // (e.g., "vie" + "j" then "e" -> "việc").
                bool allowToneOnInvalid = (_spellingOK && !_spellingVowelOK && canFixVowelWithDiacriticsForMark());
                if (!allowToneOnInvalid) {
                    allowSpecialDespiteTempDisable = false;
                }
            }
        }

        const bool quickTelexEnabled = phtvRuntimeQuickTelexEnabled() != 0;
        const bool freeMarkEnabled = phtvRuntimeFreeMarkEnabled() != 0;

        if (!IS_SPECIALKEY(data) || (tempDisableKey && !allowSpecialDespiteTempDisable)) { //do nothing
            if (quickTelexEnabled && IS_QUICK_TELEX_KEY(data)) {
                handleQuickTelex(data, _isCaps);
                return;
            } else {
                hCode = vDoNothing;
                hBPC = 0;
                hNCC = 0;
                hExt = 3; //normal key
                insertKey(data, _isCaps);
            }
        } else { //check and update key
            //restore state
            hCode = vDoNothing;
            hExt = 3; //normal key
            handleMainKey(data, _isCaps);
        }

        if (!freeMarkEnabled && !IS_KEY_D(data)) {
            if (hCode == vDoNothing) {
                checkGrammar(-1);
            } else {
                checkGrammar(0);
            }
        }
        
        if (hCode == vRestore) {
            insertKey(data, _isCaps);
            // FIX: Do NOT decrement _stateIndex here!
            // When a Telex mark is restored/removed (e.g., pressing 's' twice to toggle sắc),
            // the key was already added to KeyStates via insertState() at line 1712.
            // Decrementing _stateIndex causes English word detection to fail because
            // detectorShouldRestoreEnglishWord() would see "addres" (6 chars) instead of "address" (7 chars).
            // The key IS being inserted into TypingWord via insertKey() above, so _stateIndex
            // should remain in sync with the actual number of keys pressed.
        }
        
        //insert or replace key for macro feature
        if (phtvRuntimeUseMacroEnabled()) {
            if (hCode == vDoNothing) {
                hMacroKey.push_back(data | (_isCaps ? CAPS_MASK : 0));
            } else if (hCode == vWillProcess || hCode == vRestore) {
                for (i = 0; i < hBPC; i++) {
                    if (hMacroKey.size() > 0) {
                        hMacroKey.pop_back();
                    }
                }
                for (i = _index - hBPC; i < hNCC + (_index - hBPC); i++) {
                    hMacroKey.push_back(TypingWord[i]);
                }
            }
        }
        
        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp()) {
            if (_index == 1 && _upperCaseStatus == 2 && !_upperCaseNeedsSpaceConfirm) {
                upperCaseFirstCharacter();
                // Track for English restore - in case Vietnamese transform didn't happen
                _shouldUpperCaseEnglishRestore = true;
            }
            _upperCaseStatus = 0;
            _upperCaseNeedsSpaceConfirm = false;
        }
        
        //case [ ]
        if (IS_BRACKET_KEY(data) && (( IS_BRACKET_KEY((Uint16)hData[0])) || runtimeInputTypeSnapshot == vSimpleTelex1 || runtimeInputTypeSnapshot == vSimpleTelex2)) {
            if (_index - (hCode == vWillProcess ? hBPC : 0) > 0) {
                _index--;
                saveWord();
            }
            _index = 0;
            tempDisableKey = false;
            _stateIndex = 0;
            hExt = 3;
            _specialChar.push_back(data | (_isCaps ? CAPS_MASK : 0));
        }
    }
    
    //Debug
    //cout<<"index "<<(int)_index<< ", stateIndex "<<(int)_stateIndex<<", word "<<_typingStates.size()<<", long word "<<_longWordHelper.size()<< endl;
    //cout<<"backspace "<<(int)hBPC<<endl;
    //cout<<"new char "<<(int)hNCC<<endl<<endl;
}

#include "EngineRestoreSession.inc"
