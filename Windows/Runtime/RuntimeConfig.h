#pragma once

#include <filesystem>
#include <string>
#include <vector>
#include "Engine.h"

namespace phtv::windows_runtime {

struct RuntimeMacroEntry {
    std::string shortcut;
    std::string content;
};

struct RuntimeConfig {
    int language = 1;
    int inputType = 0;
    int codeTable = 0;
    int switchKeyStatus = 0x9FE;
    int checkSpelling = 1;
    int useModernOrthography = 1;
    int quickTelex = 0;
    int useMacro = 1;
    int useMacroInEnglishMode = 1;
    int autoCapsMacro = 0;
    int useSmartSwitchKey = 1;
    int upperCaseFirstChar = 0;
    int allowConsonantZFWJ = 1;
    int quickStartConsonant = 0;
    int quickEndConsonant = 0;
    int rememberCode = 1;
    int restoreOnEscape = 1;
    int customEscapeKey = KEY_ESC;
    int pauseKeyEnabled = 0;
    int pauseKey = KEY_LEFT_OPTION;
    int autoRestoreEnglishWord = 1;
    int sendKeyStepByStep = 0;
    int performLayoutCompat = 0;
    int emojiHotkeyEnabled = 1;
    int emojiHotkeyStatus = 0x100 | KEY_E;
    int fixRecommendBrowser = 1;
    std::vector<std::string> excludedApps;
    std::vector<std::string> stepByStepApps;
    std::vector<RuntimeMacroEntry> macros;
};

std::filesystem::path runtimeDirectory();
std::filesystem::path runtimeConfigPath();
std::filesystem::path runtimeMacrosPath();

// Loads runtime files and applies all values to shared engine globals.
// Returns true when engine state was applied successfully.
// Returns false only if there was a hard I/O error while reading existing files.
bool loadAndApplyRuntimeConfig(RuntimeConfig& outConfig, std::string& errorMessage);

// Updates only the "language" field in runtime-config.ini so UI and daemon stay in sync.
// language: 0 = English, non-zero = Vietnamese.
bool persistRuntimeLanguage(int language, std::string& errorMessage);

} // namespace phtv::windows_runtime
