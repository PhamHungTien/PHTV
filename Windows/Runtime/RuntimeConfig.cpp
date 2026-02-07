#include "RuntimeConfig.h"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include "Macro.h"

namespace {

std::string trim(const std::string& input) {
    size_t start = 0;
    while (start < input.size() && std::isspace(static_cast<unsigned char>(input[start])) != 0) {
        start++;
    }

    size_t end = input.size();
    while (end > start && std::isspace(static_cast<unsigned char>(input[end - 1])) != 0) {
        end--;
    }

    return input.substr(start, end - start);
}

bool tryParseInt(const std::string& input, int& value) {
    if (input.empty()) {
        return false;
    }

    char* endPtr = nullptr;
    errno = 0;
    const long parsed = std::strtol(input.c_str(), &endPtr, 10);
    if (errno != 0 || endPtr == input.c_str() || *endPtr != '\0') {
        return false;
    }

    value = static_cast<int>(parsed);
    return true;
}

int readInt(const std::unordered_map<std::string, std::string>& table,
            const std::string& key,
            int fallback) {
    const auto it = table.find(key);
    if (it == table.end()) {
        return fallback;
    }

    int value = fallback;
    if (!tryParseInt(trim(it->second), value)) {
        return fallback;
    }
    return value;
}

int readBoolAsInt(const std::unordered_map<std::string, std::string>& table,
                  const std::string& key,
                  int fallback) {
    return readInt(table, key, fallback) == 0 ? 0 : 1;
}

void parseIniFile(const std::filesystem::path& path,
                  std::unordered_map<std::string, std::string>& outValues) {
    outValues.clear();

    std::ifstream stream(path);
    if (!stream.is_open()) {
        return;
    }

    std::string line;
    while (std::getline(stream, line)) {
        const std::string trimmed = trim(line);
        if (trimmed.empty() || trimmed[0] == '#' || trimmed[0] == ';') {
            continue;
        }

        const size_t separator = trimmed.find('=');
        if (separator == std::string::npos || separator == 0) {
            continue;
        }

        std::string key = trim(trimmed.substr(0, separator));
        std::string value = trim(trimmed.substr(separator + 1));
        if (key.empty()) {
            continue;
        }

        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) {
            return static_cast<char>(std::tolower(c));
        });
        outValues[key] = value;
    }
}

std::string unescapeField(const std::string& input) {
    std::string output;
    output.reserve(input.size());

    for (size_t i = 0; i < input.size(); ++i) {
        const char c = input[i];
        if (c != '\\' || i + 1 >= input.size()) {
            output.push_back(c);
            continue;
        }

        const char escaped = input[++i];
        switch (escaped) {
            case 'n':
                output.push_back('\n');
                break;
            case 'r':
                output.push_back('\r');
                break;
            case 't':
                output.push_back('\t');
                break;
            case '\\':
                output.push_back('\\');
                break;
            default:
                output.push_back(escaped);
                break;
        }
    }

    return output;
}

std::vector<std::string> readEscapedList(const std::unordered_map<std::string, std::string>& table,
                                         const std::string& key) {
    std::vector<std::string> values;

    const auto it = table.find(key);
    if (it == table.end()) {
        return values;
    }

    std::string current;
    current.reserve(it->second.size());
    bool escaped = false;

    auto flushCurrent = [&]() {
        const std::string normalized = trim(current);
        if (!normalized.empty()) {
            values.push_back(normalized);
        }
        current.clear();
    };

    for (const char c : it->second) {
        if (escaped) {
            current.push_back(c);
            escaped = false;
            continue;
        }

        if (c == '\\') {
            escaped = true;
            continue;
        }

        if (c == '|') {
            flushCurrent();
            continue;
        }

        current.push_back(c);
    }

    if (escaped) {
        current.push_back('\\');
    }

    flushCurrent();
    return values;
}

void loadMacrosFromFile(const std::filesystem::path& path,
                        std::vector<phtv::windows_runtime::RuntimeMacroEntry>& outMacros) {
    outMacros.clear();

    std::ifstream stream(path);
    if (!stream.is_open()) {
        return;
    }

    std::string line;
    while (std::getline(stream, line)) {
        const std::string trimmed = trim(line);
        if (trimmed.empty() || trimmed[0] == '#') {
            continue;
        }

        const size_t separator = trimmed.find('\t');
        if (separator == std::string::npos || separator == 0 || separator + 1 >= trimmed.size()) {
            continue;
        }

        const std::string rawShortcut = trimmed.substr(0, separator);
        const std::string rawContent = trimmed.substr(separator + 1);
        const std::string shortcut = unescapeField(rawShortcut);
        const std::string content = unescapeField(rawContent);
        if (shortcut.empty() || content.empty()) {
            continue;
        }

        outMacros.push_back({shortcut, content});
    }
}

void applyConfigToEngine(const phtv::windows_runtime::RuntimeConfig& config) {
    vLanguage = config.language == 0 ? 0 : 1;
    vInputType = std::clamp(config.inputType, 0, 3);
    vCodeTable = std::clamp(config.codeTable, 0, 4);
    vSwitchKeyStatus = config.switchKeyStatus;
    vCheckSpelling = config.checkSpelling == 0 ? 0 : 1;
    vUseModernOrthography = config.useModernOrthography == 0 ? 0 : 1;
    vQuickTelex = config.quickTelex == 0 ? 0 : 1;
    vUseMacro = config.useMacro == 0 ? 0 : 1;
    vUseMacroInEnglishMode = config.useMacroInEnglishMode == 0 ? 0 : 1;
    vAutoCapsMacro = config.autoCapsMacro == 0 ? 0 : 1;
    vUseSmartSwitchKey = config.useSmartSwitchKey == 0 ? 0 : 1;
    vUpperCaseFirstChar = config.upperCaseFirstChar == 0 ? 0 : 1;
    vAllowConsonantZFWJ = config.allowConsonantZFWJ == 0 ? 0 : 1;
    vQuickStartConsonant = config.quickStartConsonant == 0 ? 0 : 1;
    vQuickEndConsonant = config.quickEndConsonant == 0 ? 0 : 1;
    vRememberCode = config.rememberCode == 0 ? 0 : 1;
    vRestoreOnEscape = config.restoreOnEscape == 0 ? 0 : 1;
    vCustomEscapeKey = config.customEscapeKey > 0 ? config.customEscapeKey : KEY_ESC;
    vPauseKeyEnabled = config.pauseKeyEnabled == 0 ? 0 : 1;
    vPauseKey = config.pauseKey > 0 ? config.pauseKey : KEY_LEFT_OPTION;
    vAutoRestoreEnglishWord = config.autoRestoreEnglishWord == 0 ? 0 : 1;
    vFixRecommendBrowser = config.fixRecommendBrowser == 0 ? 0 : 1;

    onTableCodeChange();

    initMacroMap(nullptr, 0);
    for (const auto& macro : config.macros) {
        addMacro(macro.shortcut, macro.content);
    }
}

} // namespace

namespace phtv::windows_runtime {

std::filesystem::path runtimeDirectory() {
    const char* overridePath = std::getenv("PHTV_RUNTIME_DIR");
    if (overridePath != nullptr && overridePath[0] != '\0') {
        return std::filesystem::path(overridePath);
    }

    const char* localAppData = std::getenv("LOCALAPPDATA");
    if (localAppData != nullptr && localAppData[0] != '\0') {
        return std::filesystem::path(localAppData) / "PHTV";
    }

    const char* userProfile = std::getenv("USERPROFILE");
    if (userProfile != nullptr && userProfile[0] != '\0') {
        return std::filesystem::path(userProfile) / "AppData" / "Local" / "PHTV";
    }

    return std::filesystem::current_path() / "PHTV";
}

std::filesystem::path runtimeConfigPath() {
    return runtimeDirectory() / "runtime-config.ini";
}

std::filesystem::path runtimeMacrosPath() {
    return runtimeDirectory() / "runtime-macros.tsv";
}

bool loadAndApplyRuntimeConfig(RuntimeConfig& outConfig, std::string& errorMessage) {
    errorMessage.clear();

    RuntimeConfig config;
    const std::filesystem::path configPath = runtimeConfigPath();
    const std::filesystem::path macrosPath = runtimeMacrosPath();

    std::error_code ec;
    const bool hasConfigFile = std::filesystem::exists(configPath, ec);
    if (ec) {
        errorMessage = "Cannot check runtime-config.ini: " + ec.message();
        return false;
    }

    if (hasConfigFile) {
        std::unordered_map<std::string, std::string> values;
        parseIniFile(configPath, values);

        config.language = readBoolAsInt(values, "language", config.language);
        config.inputType = readInt(values, "input_type", config.inputType);
        config.codeTable = readInt(values, "code_table", config.codeTable);
        config.switchKeyStatus = readInt(values, "switch_key_status", config.switchKeyStatus);
        config.checkSpelling = readBoolAsInt(values, "check_spelling", config.checkSpelling);
        config.useModernOrthography = readBoolAsInt(values, "use_modern_orthography", config.useModernOrthography);
        config.quickTelex = readBoolAsInt(values, "quick_telex", config.quickTelex);
        config.useMacro = readBoolAsInt(values, "use_macro", config.useMacro);
        config.useMacroInEnglishMode = readBoolAsInt(values, "use_macro_in_english_mode", config.useMacroInEnglishMode);
        config.autoCapsMacro = readBoolAsInt(values, "auto_caps_macro", config.autoCapsMacro);
        config.useSmartSwitchKey = readBoolAsInt(values, "use_smart_switch_key", config.useSmartSwitchKey);
        config.upperCaseFirstChar = readBoolAsInt(values, "upper_case_first_char", config.upperCaseFirstChar);
        config.allowConsonantZFWJ = readBoolAsInt(values, "allow_consonant_zfwj", config.allowConsonantZFWJ);
        config.quickStartConsonant = readBoolAsInt(values, "quick_start_consonant", config.quickStartConsonant);
        config.quickEndConsonant = readBoolAsInt(values, "quick_end_consonant", config.quickEndConsonant);
        config.rememberCode = readBoolAsInt(values, "remember_code", config.rememberCode);
        config.restoreOnEscape = readBoolAsInt(values, "restore_on_escape", config.restoreOnEscape);
        config.customEscapeKey = readInt(values, "custom_escape_key", config.customEscapeKey);
        config.pauseKeyEnabled = readBoolAsInt(values, "pause_key_enabled", config.pauseKeyEnabled);
        config.pauseKey = readInt(values, "pause_key", config.pauseKey);
        config.autoRestoreEnglishWord = readBoolAsInt(values, "auto_restore_english_word", config.autoRestoreEnglishWord);
        config.sendKeyStepByStep = readBoolAsInt(values, "send_key_step_by_step", config.sendKeyStepByStep);
        config.performLayoutCompat = readBoolAsInt(values, "perform_layout_compat", config.performLayoutCompat);
        config.emojiHotkeyEnabled = readBoolAsInt(values, "emoji_hotkey_enabled", config.emojiHotkeyEnabled);
        config.emojiHotkeyStatus = readInt(values, "emoji_hotkey_status", config.emojiHotkeyStatus);
        config.fixRecommendBrowser = readBoolAsInt(values, "fix_recommend_browser", config.fixRecommendBrowser);
        config.excludedApps = readEscapedList(values, "excluded_apps");
        config.stepByStepApps = readEscapedList(values, "step_by_step_apps");
    }

    ec.clear();
    const bool hasMacrosFile = std::filesystem::exists(macrosPath, ec);
    if (ec) {
        errorMessage = "Cannot check runtime-macros.tsv: " + ec.message();
        return false;
    }
    if (hasMacrosFile) {
        loadMacrosFromFile(macrosPath, config.macros);
    } else {
        config.macros.clear();
    }

    applyConfigToEngine(config);
    outConfig = config;
    return true;
}

bool persistRuntimeLanguage(int language, std::string& errorMessage) {
    errorMessage.clear();

    const int normalizedLanguage = language == 0 ? 0 : 1;
    const std::filesystem::path configPath = runtimeConfigPath();
    const std::filesystem::path tempPath = configPath.string() + ".tmp";

    std::error_code ec;
    std::filesystem::create_directories(configPath.parent_path(), ec);
    if (ec) {
        errorMessage = "Cannot create runtime directory: " + ec.message();
        return false;
    }

    std::vector<std::string> lines;
    lines.reserve(128);

    {
        std::ifstream input(configPath);
        std::string line;
        while (std::getline(input, line)) {
            lines.push_back(line);
        }
    }

    bool foundLanguage = false;
    for (std::string& line : lines) {
        const std::string trimmed = trim(line);
        if (trimmed.empty() || trimmed[0] == '#' || trimmed[0] == ';') {
            continue;
        }

        const size_t separator = trimmed.find('=');
        if (separator == std::string::npos || separator == 0) {
            continue;
        }

        std::string key = trim(trimmed.substr(0, separator));
        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) {
            return static_cast<char>(std::tolower(c));
        });

        if (key == "language") {
            line = "language=" + std::to_string(normalizedLanguage);
            foundLanguage = true;
        }
    }

    if (!foundLanguage) {
        lines.push_back("language=" + std::to_string(normalizedLanguage));
    }

    {
        std::ofstream output(tempPath, std::ios::trunc);
        if (!output.is_open()) {
            errorMessage = "Cannot write temporary runtime-config.ini";
            return false;
        }

        for (const std::string& line : lines) {
            output << line << '\n';
            if (!output.good()) {
                errorMessage = "Failed while writing runtime-config.ini";
                return false;
            }
        }
    }

    ec.clear();
    std::filesystem::rename(tempPath, configPath, ec);
    if (!ec) {
        return true;
    }

    ec.clear();
    std::filesystem::copy_file(tempPath,
                               configPath,
                               std::filesystem::copy_options::overwrite_existing,
                               ec);
    if (ec) {
        errorMessage = "Cannot finalize runtime-config.ini: " + ec.message();
        std::error_code cleanupEc;
        std::filesystem::remove(tempPath, cleanupEc);
        return false;
    }

    std::error_code cleanupEc;
    std::filesystem::remove(tempPath, cleanupEc);
    return true;
}

} // namespace phtv::windows_runtime
