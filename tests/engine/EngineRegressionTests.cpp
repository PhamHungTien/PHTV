#include "Engine.h"
#include "EnglishWordDetector.h"

#include <iostream>
#include <string>
#include <vector>

// -----------------------------------------------------------------------------
// Minimal runtime globals required by Engine.h extern declarations
// -----------------------------------------------------------------------------
volatile int vLanguage = 1;
volatile int vInputType = vTelex;
int vFreeMark = 0;
volatile int vCodeTable = 0;
volatile int vSwitchKeyStatus = DEFAULT_SWITCH_HOTKEY_STATUS;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 0;
volatile int vQuickTelex = 0;
volatile int vFixRecommendBrowser = 1;
volatile int vUseMacro = 0;
volatile int vUseMacroInEnglishMode = 0;
volatile int vAutoCapsMacro = 1;
volatile int vUseSmartSwitchKey = 0;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 0;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 0;
volatile int vOtherLanguage = 0;
volatile int vTempOffPHTV = 0;
volatile int vRestoreOnEscape = 1;
volatile int vCustomEscapeKey = 0;
volatile int vPauseKeyEnabled = 0;
volatile int vPauseKey = KEY_LEFT_OPTION;
volatile int vAutoRestoreEnglishWord = 1;

// -----------------------------------------------------------------------------
// Macro stubs (Engine references findMacro, but macro behavior is not under test)
// -----------------------------------------------------------------------------
bool findMacro(std::vector<Uint32>& key, std::vector<Uint32>& macroContentCode) {
    (void)key;
    (void)macroContentCode;
    return false;
}

namespace {

struct CaseResult {
    std::string name;
    bool pass;
    std::string detail;
};

Uint16 keyCodeForChar(char ch) {
    switch (ch) {
        case 'a': return KEY_A;
        case 'b': return KEY_B;
        case 'c': return KEY_C;
        case 'd': return KEY_D;
        case 'e': return KEY_E;
        case 'f': return KEY_F;
        case 'g': return KEY_G;
        case 'h': return KEY_H;
        case 'i': return KEY_I;
        case 'j': return KEY_J;
        case 'k': return KEY_K;
        case 'l': return KEY_L;
        case 'm': return KEY_M;
        case 'n': return KEY_N;
        case 'o': return KEY_O;
        case 'p': return KEY_P;
        case 'q': return KEY_Q;
        case 'r': return KEY_R;
        case 's': return KEY_S;
        case 't': return KEY_T;
        case 'u': return KEY_U;
        case 'v': return KEY_V;
        case 'w': return KEY_W;
        case 'x': return KEY_X;
        case 'y': return KEY_Y;
        case 'z': return KEY_Z;
        case '0': return KEY_0;
        case '1': return KEY_1;
        case '2': return KEY_2;
        case '3': return KEY_3;
        case '4': return KEY_4;
        case '5': return KEY_5;
        case '6': return KEY_6;
        case '7': return KEY_7;
        case '8': return KEY_8;
        case '9': return KEY_9;
        default:
            return KEY_EMPTY;
    }
}

void setCustomEnglishWords(const std::vector<std::string>& words) {
    clearCustomDictionary();

    std::string json = "[";
    for (size_t i = 0; i < words.size(); i++) {
        if (i > 0) json += ",";
        json += "{\"word\":\"" + words[i] + "\",\"type\":\"en\"}";
    }
    json += "]";

    initCustomDictionary(json.c_str(), static_cast<int>(json.size()));
}

void feedWord(const std::string& token) {
    for (char ch : token) {
        Uint16 code = keyCodeForChar(ch);
        if (code == KEY_EMPTY) {
            std::cerr << "Unsupported token char: '" << ch << "'\n";
            continue;
        }
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, 0, false);
    }
}

CaseResult runSpaceCase(const std::string& name,
                        const std::string& token,
                        const std::vector<std::string>& customEnglish,
                        bool expectRestore,
                        bool autoRestoreEnglish = true) {
    setCustomEnglishWords(customEnglish);
    int savedAutoRestoreEnglish = vAutoRestoreEnglishWord;
    vAutoRestoreEnglishWord = autoRestoreEnglish ? 1 : 0;
    vKeyHookState* state = static_cast<vKeyHookState*>(vKeyInit());
    feedWord(token);
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, KEY_SPACE, 0, false);
    vAutoRestoreEnglishWord = savedAutoRestoreEnglish;

    bool restored = (state->code == vRestore || state->code == vRestoreAndStartNewSession);
    bool pass = (restored == expectRestore);

    std::string detail = "code=" + std::to_string(state->code) +
                         ", backspace=" + std::to_string(state->backspaceCount) +
                         ", newChar=" + std::to_string(state->newCharCount);

    return {name, pass, detail};
}

CaseResult runWordBreakCase(const std::string& name,
                            const std::string& token,
                            const std::vector<std::string>& customEnglish,
                            bool expectRestore,
                            bool autoRestoreEnglish = true) {
    setCustomEnglishWords(customEnglish);
    int savedAutoRestoreEnglish = vAutoRestoreEnglishWord;
    vAutoRestoreEnglishWord = autoRestoreEnglish ? 1 : 0;
    vKeyHookState* state = static_cast<vKeyHookState*>(vKeyInit());
    feedWord(token);
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, KEY_DOT, 0, false);
    vAutoRestoreEnglishWord = savedAutoRestoreEnglish;

    bool restored = (state->code == vRestore || state->code == vRestoreAndStartNewSession);
    bool pass = (restored == expectRestore);

    std::string detail = "code=" + std::to_string(state->code) +
                         ", backspace=" + std::to_string(state->backspaceCount) +
                         ", newChar=" + std::to_string(state->newCharCount);

    return {name, pass, detail};
}

} // namespace

int main(int argc, char** argv) {
    const std::string defaultEnPath = "macOS/PHTV/Resources/Dictionaries/en_dict.bin";
    const std::string defaultViPath = "macOS/PHTV/Resources/Dictionaries/vi_dict.bin";

    std::string enPath = (argc > 1) ? argv[1] : defaultEnPath;
    std::string viPath = (argc > 2) ? argv[2] : defaultViPath;

    bool enOk = initEnglishDictionary(enPath);
    bool viOk = initVietnameseDictionary(viPath);
    if (!enOk) {
        std::cerr << "[FAIL] Cannot initialize English dictionary: " << enPath << "\n";
        return 2;
    }
    if (!viOk) {
        std::cerr << "[FAIL] Cannot initialize Vietnamese dictionary: " << viPath << "\n";
        return 2;
    }

    std::vector<CaseResult> results;
    results.push_back(runSpaceCase(
        "Telex-modified English word terminal should restore on SPACE",
        "terminal",
        {"terminal"},
        true));

    results.push_back(runSpaceCase(
        "Alnum token int1234 should NOT restore on SPACE",
        "int1234",
        {"int"},
        false));

    results.push_back(runSpaceCase(
        "Telex-conflict token terminal1234 should restore full raw keys on SPACE",
        "terminal1234",
        {"terminal"},
        true));

    results.push_back(runSpaceCase(
        "Wrong-spelling token user should restore raw keys on SPACE",
        "user",
        {},
        true,
        false));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on DOT",
        "terminal",
        {"terminal"},
        true));

    results.push_back(runWordBreakCase(
        "Telex-conflict token terminal1234 should restore full raw keys on DOT",
        "terminal1234",
        {"terminal"},
        true));

    results.push_back(runWordBreakCase(
        "Alnum token int1234 should NOT restore on DOT",
        "int1234",
        {"int"},
        false));

    results.push_back(runWordBreakCase(
        "Wrong-spelling token user should restore raw keys on DOT",
        "user",
        {},
        true,
        false));

    int failed = 0;
    for (const auto& r : results) {
        std::cout << (r.pass ? "[PASS] " : "[FAIL] ") << r.name
                  << " (" << r.detail << ")\n";
        if (!r.pass) failed++;
    }

    clearCustomDictionary();
    clearEnglishDictionary();

    if (failed > 0) {
        std::cerr << "\nRegression tests failed: " << failed << " case(s).\n";
        return 1;
    }

    std::cout << "\nAll regression tests passed.\n";
    return 0;
}
