#include "EngineDataTypes.inc"
#include "PHTVEngineCBridge.h"

#include <iostream>
#include <string>
#include <vector>

// -----------------------------------------------------------------------------
// Runtime bridge stubs for standalone regression binary (no Swift runtime linked)
// -----------------------------------------------------------------------------
static int runtimeRestoreOnEscape = 1;
static int runtimeAutoRestoreEnglishWord = 1;
static int runtimeUpperCaseFirstChar = 0;
static int runtimeUpperCaseExcludedForCurrentApp = 0;
static int runtimeUseMacro = 0;
static int runtimeInputType = vTelex;
static int runtimeCodeTable = 0;
static int runtimeCheckSpelling = 1;
static int runtimeUseModernOrthography = 0;
static int runtimeQuickTelex = 0;
static int runtimeFreeMark = 0;
static int runtimeAllowConsonantZFWJ = 0;
static int runtimeQuickStartConsonant = 0;
static int runtimeQuickEndConsonant = 0;
static int runtimeAutoCapsMacro = 1;

extern "C" int phtvRuntimeRestoreOnEscapeEnabled() { return runtimeRestoreOnEscape; }
extern "C" int phtvRuntimeAutoRestoreEnglishWordEnabled() { return runtimeAutoRestoreEnglishWord; }
extern "C" int phtvRuntimeUpperCaseFirstCharEnabled() { return runtimeUpperCaseFirstChar; }
extern "C" int phtvRuntimeUpperCaseExcludedForCurrentApp() { return runtimeUpperCaseExcludedForCurrentApp; }
extern "C" int phtvRuntimeUseMacroEnabled() { return runtimeUseMacro; }
extern "C" int phtvRuntimeInputTypeValue() { return runtimeInputType; }
extern "C" int phtvRuntimeCodeTableValue() { return runtimeCodeTable; }
extern "C" int phtvRuntimeCheckSpellingValue() { return runtimeCheckSpelling; }
extern "C" void phtvRuntimeSetCheckSpellingValue(int value) { runtimeCheckSpelling = value; }
extern "C" int phtvRuntimeUseModernOrthographyEnabled() { return runtimeUseModernOrthography; }
extern "C" int phtvRuntimeQuickTelexEnabled() { return runtimeQuickTelex; }
extern "C" int phtvRuntimeFreeMarkEnabled() { return runtimeFreeMark; }
extern "C" int phtvRuntimeAllowConsonantZFWJEnabled() { return runtimeAllowConsonantZFWJ; }
extern "C" int phtvRuntimeQuickStartConsonantEnabled() { return runtimeQuickStartConsonant; }
extern "C" int phtvRuntimeQuickEndConsonantEnabled() { return runtimeQuickEndConsonant; }
extern "C" int phtvRuntimeAutoCapsMacroValue() { return runtimeAutoCapsMacro; }

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
    phtvCustomDictionaryClear();

    std::string json = "[";
    for (size_t i = 0; i < words.size(); i++) {
        if (i > 0) json += ",";
        json += "{\"word\":\"" + words[i] + "\",\"type\":\"en\"}";
    }
    json += "]";

    phtvCustomDictionaryLoadJSON(json.c_str(), static_cast<int>(json.size()));
}

void feedWord(const std::string& token) {
    for (char ch : token) {
        Uint16 code = keyCodeForChar(ch);
        if (code == KEY_EMPTY) {
            std::cerr << "Unsupported token char: '" << ch << "'\n";
            continue;
        }
        phtvEngineHandleEvent(PHTV_ENGINE_EVENT_KEYBOARD,
                              PHTV_ENGINE_EVENT_STATE_KEY_DOWN,
                              code,
                              0,
                              0);
    }
}

CaseResult runSpaceCase(const std::string& name,
                        const std::string& token,
                        const std::vector<std::string>& customEnglish,
                        bool expectRestore,
                        bool autoRestoreEnglish = true) {
    setCustomEnglishWords(customEnglish);
    int savedAutoRestoreEnglish = runtimeAutoRestoreEnglishWord;
    runtimeAutoRestoreEnglishWord = autoRestoreEnglish ? 1 : 0;
    phtvEngineInitialize();
    feedWord(token);
    phtvEngineHandleEvent(PHTV_ENGINE_EVENT_KEYBOARD,
                          PHTV_ENGINE_EVENT_STATE_KEY_DOWN,
                          KEY_SPACE,
                          0,
                          0);
    runtimeAutoRestoreEnglishWord = savedAutoRestoreEnglish;

    int code = phtvEngineHookCode();
    bool restored = (code == vRestore || code == vRestoreAndStartNewSession);
    bool pass = (restored == expectRestore);

    std::string detail = "code=" + std::to_string(code) +
                         ", backspace=" + std::to_string(phtvEngineHookBackspaceCount()) +
                         ", newChar=" + std::to_string(phtvEngineHookNewCharCount());

    return {name, pass, detail};
}

CaseResult runWordBreakCase(const std::string& name,
                            const std::string& token,
                            const std::vector<std::string>& customEnglish,
                            bool expectRestore,
                            bool autoRestoreEnglish = true,
                            Uint16 breakKeyCode = KEY_DOT,
                            Uint8 breakCapsStatus = 0) {
    setCustomEnglishWords(customEnglish);
    int savedAutoRestoreEnglish = runtimeAutoRestoreEnglishWord;
    runtimeAutoRestoreEnglishWord = autoRestoreEnglish ? 1 : 0;
    phtvEngineInitialize();
    feedWord(token);
    phtvEngineHandleEvent(PHTV_ENGINE_EVENT_KEYBOARD,
                          PHTV_ENGINE_EVENT_STATE_KEY_DOWN,
                          breakKeyCode,
                          breakCapsStatus,
                          0);
    runtimeAutoRestoreEnglishWord = savedAutoRestoreEnglish;

    int code = phtvEngineHookCode();
    bool restored = (code == vRestore || code == vRestoreAndStartNewSession);
    bool pass = (restored == expectRestore);

    std::string detail = "code=" + std::to_string(code) +
                         ", backspace=" + std::to_string(phtvEngineHookBackspaceCount()) +
                         ", newChar=" + std::to_string(phtvEngineHookNewCharCount()) +
                         ", breakKey=" + std::to_string(breakKeyCode) +
                         ", caps=" + std::to_string(breakCapsStatus);

    return {name, pass, detail};
}

} // namespace

int main(int argc, char** argv) {
    const std::string defaultEnPath = "macOS/PHTV/Resources/Dictionaries/en_dict.bin";
    const std::string defaultViPath = "macOS/PHTV/Resources/Dictionaries/vi_dict.bin";

    std::string enPath = (argc > 1) ? argv[1] : defaultEnPath;
    std::string viPath = (argc > 2) ? argv[2] : defaultViPath;

    bool enOk = phtvDictionaryInitEnglish(enPath.c_str()) != 0;
    bool viOk = phtvDictionaryInitVietnamese(viPath.c_str()) != 0;
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
        "Custom-English token qes should restore on SPACE",
        "qes",
        {"qes"},
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

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on COMMA",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_COMMA,
        0));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on QUESTION MARK",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_SLASH,
        1));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on EXCLAMATION MARK",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_1,
        1));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on LEFT PARENTHESIS",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_9,
        1));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on RIGHT PARENTHESIS",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_0,
        1));

    results.push_back(runWordBreakCase(
        "Telex-modified English word terminal should restore on LEFT BRACKET",
        "terminal",
        {"terminal"},
        true,
        true,
        KEY_LEFT_BRACKET,
        0));

    results.push_back(runWordBreakCase(
        "Telex-conflict token terminal1234 should restore full raw keys on RIGHT BRACKET",
        "terminal1234",
        {"terminal"},
        true,
        true,
        KEY_RIGHT_BRACKET,
        0));

    results.push_back(runWordBreakCase(
        "Alnum token int1234 should NOT restore on EXCLAMATION MARK",
        "int1234",
        {"int"},
        false,
        true,
        KEY_1,
        1));

    results.push_back(runWordBreakCase(
        "Alnum token int1234 should NOT restore on RIGHT PARENTHESIS",
        "int1234",
        {"int"},
        false,
        true,
        KEY_0,
        1));

    results.push_back(runWordBreakCase(
        "Wrong-spelling token user should restore raw keys on EXCLAMATION MARK",
        "user",
        {},
        true,
        false,
        KEY_1,
        1));

    int failed = 0;
    for (const auto& r : results) {
        std::cout << (r.pass ? "[PASS] " : "[FAIL] ") << r.name
                  << " (" << r.detail << ")\n";
        if (!r.pass) failed++;
    }

    phtvCustomDictionaryClear();
    phtvDictionaryClear();

    if (failed > 0) {
        std::cerr << "\nRegression tests failed: " << failed << " case(s).\n";
        return 1;
    }

    std::cout << "\nAll regression tests passed.\n";
    return 0;
}
