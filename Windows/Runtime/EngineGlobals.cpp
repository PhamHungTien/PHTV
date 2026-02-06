#include "EngineGlobals.h"

namespace {
constexpr int kDefaultSwitchStatus = 0x9FE; // Ctrl + Shift + no primary key
}

// Engine globals (declared in Engine.h)
volatile int vLanguage = 1;
volatile int vInputType = 0;
int vFreeMark = 0;
volatile int vCodeTable = 0;
volatile int vSwitchKeyStatus = kDefaultSwitchStatus;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 1;
volatile int vQuickTelex = 0;
volatile int vFixRecommendBrowser = 1;
volatile int vUseMacro = 1;
volatile int vUseMacroInEnglishMode = 1;
volatile int vAutoCapsMacro = 0;
volatile int vUseSmartSwitchKey = 1;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 1;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 1;
volatile int vOtherLanguage = 1;
volatile int vTempOffPHTV = 0;
volatile int vRestoreOnEscape = 1;
volatile int vCustomEscapeKey = 0;
volatile int vPauseKeyEnabled = 0;
volatile int vPauseKey = KEY_LEFT_OPTION;
volatile int vAutoRestoreEnglishWord = 1;

namespace phtv::windows_runtime {

void resetEngineDefaults() {
    vLanguage = 1;
    vInputType = 0;
    vFreeMark = 0;
    vCodeTable = 0;
    vSwitchKeyStatus = kDefaultSwitchStatus;
    vCheckSpelling = 1;
    vUseModernOrthography = 1;
    vQuickTelex = 0;
    vFixRecommendBrowser = 1;
    vUseMacro = 1;
    vUseMacroInEnglishMode = 1;
    vAutoCapsMacro = 0;
    vUseSmartSwitchKey = 1;
    vUpperCaseFirstChar = 0;
    vUpperCaseExcludedForCurrentApp = 0;
    vTempOffSpelling = 0;
    vAllowConsonantZFWJ = 1;
    vQuickStartConsonant = 0;
    vQuickEndConsonant = 0;
    vRememberCode = 1;
    vOtherLanguage = 1;
    vTempOffPHTV = 0;
    vRestoreOnEscape = 1;
    vCustomEscapeKey = 0;
    vPauseKeyEnabled = 0;
    vPauseKey = KEY_LEFT_OPTION;
    vAutoRestoreEnglishWord = 1;
}

} // namespace phtv::windows_runtime
