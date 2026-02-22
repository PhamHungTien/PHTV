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

#include "EngineEnglishMode.inc"

#include "EngineKeyHandleEvent.inc"

#include "EngineRestoreSession.inc"
