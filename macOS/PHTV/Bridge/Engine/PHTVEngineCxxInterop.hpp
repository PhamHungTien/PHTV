//
//  PHTVEngineCxxInterop.hpp
//  PHTV
//
//  Swift-facing C++ interop wrappers around engine helpers.
//

#ifndef PHTVEngineCxxInterop_hpp
#define PHTVEngineCxxInterop_hpp

#ifdef __cplusplus

#include <cstdint>
#include <ApplicationServices/ApplicationServices.h>

#include "../../Core/Engine/Engine.h"
#include "../../Core/PHTVConstants.h"

extern volatile int vSendKeyStepByStep;
extern volatile int vPerformLayoutCompat;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern volatile int vSafeMode;
extern int vShowIconOnDock;

inline constexpr int phtvEngineInteropProbeValue() noexcept {
    return 20260221;
}

inline int phtvEngineInteropAdd(const int lhs, const int rhs) noexcept {
    return lhs + rhs;
}


inline void phtvEngineInitializeMacroMap(const std::uint8_t *data, const int length) noexcept {
    if (!data || length <= 0) {
        initMacroMap(nullptr, 0);
        return;
    }
    initMacroMap(data, length);
}

inline bool phtvEngineInitializeEnglishDictionary(const char *path) {
    if (!path || path[0] == '\0') {
        return false;
    }
    return initEnglishDictionary(std::string(path));
}

inline unsigned long phtvEngineEnglishDictionarySize() noexcept {
    return static_cast<unsigned long>(getEnglishDictionarySize());
}

inline bool phtvEngineInitializeVietnameseDictionary(const char *path) {
    if (!path || path[0] == '\0') {
        return false;
    }
    return initVietnameseDictionary(std::string(path));
}

inline unsigned long phtvEngineVietnameseDictionarySize() noexcept {
    return static_cast<unsigned long>(getVietnameseDictionarySize());
}

inline void phtvEngineInitializeCustomDictionary(const char *jsonData, const int length) noexcept {
    if (!jsonData || length <= 0) {
        initCustomDictionary(nullptr, 0);
        return;
    }
    initCustomDictionary(jsonData, length);
}

inline unsigned long phtvEngineCustomEnglishWordCount() noexcept {
    return static_cast<unsigned long>(getCustomEnglishWordCount());
}

inline unsigned long phtvEngineCustomVietnameseWordCount() noexcept {
    return static_cast<unsigned long>(getCustomVietnameseWordCount());
}

inline void phtvEngineClearCustomDictionary() noexcept {
    clearCustomDictionary();
}

inline const char *phtvEngineConvertUtf8(const char *source) noexcept {
    static thread_local std::string converted;
    converted = convertUtil(source ? std::string(source) : std::string());
    return converted.c_str();
}

inline void phtvEngineSetCheckSpellingValue(const int value) noexcept {
    vCheckSpelling = value;
}

inline void phtvEngineApplyCheckSpelling() noexcept {
    vSetCheckSpelling();
}

inline void phtvEngineNotifyTableCodeChanged() noexcept {
    onTableCodeChange();
}

inline void phtvRuntimeBarrier() noexcept {
    __sync_synchronize();
}

inline int phtvRuntimeCurrentLanguage() noexcept {
    return vLanguage;
}

inline void phtvRuntimeSetCurrentLanguage(const int language) noexcept {
    vLanguage = language;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeCurrentInputType() noexcept {
    return vInputType;
}

inline void phtvRuntimeSetCurrentInputType(const int inputType) noexcept {
    vInputType = inputType;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeCurrentCodeTable() noexcept {
    return vCodeTable;
}

inline void phtvRuntimeSetCurrentCodeTable(const int codeTable) noexcept {
    vCodeTable = codeTable;
    phtvRuntimeBarrier();
}

inline bool phtvRuntimeIsSmartSwitchKeyEnabled() noexcept {
    return vUseSmartSwitchKey != 0;
}

inline bool phtvRuntimeIsSendKeyStepByStepEnabled() noexcept {
    return vSendKeyStepByStep != 0;
}

inline void phtvRuntimeSetSendKeyStepByStepEnabled(const bool enabled) noexcept {
    vSendKeyStepByStep = enabled ? 1 : 0;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetUpperCaseExcludedForCurrentApp(const bool excluded) noexcept {
    vUpperCaseExcludedForCurrentApp = excluded ? 1 : 0;
}

inline int phtvRuntimeSwitchKeyStatus() noexcept {
    return vSwitchKeyStatus;
}

inline void phtvRuntimeSetSwitchKeyStatus(const int status) noexcept {
    vSwitchKeyStatus = status;
    phtvRuntimeBarrier();
}

inline bool phtvRuntimeSafeMode() noexcept {
    return vSafeMode != 0;
}

inline void phtvRuntimeSetSafeMode(const bool enabled) noexcept {
    vSafeMode = enabled ? 1 : 0;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeCheckSpelling() noexcept {
    return vCheckSpelling;
}

inline void phtvRuntimeSetCheckSpelling(const int value) noexcept {
    vCheckSpelling = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeAllowConsonantZFWJ() noexcept {
    return vAllowConsonantZFWJ;
}

inline void phtvRuntimeSetAllowConsonantZFWJ(const int value) noexcept {
    vAllowConsonantZFWJ = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeUseModernOrthography() noexcept {
    return vUseModernOrthography;
}

inline void phtvRuntimeSetUseModernOrthography(const int value) noexcept {
    vUseModernOrthography = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeQuickTelex() noexcept {
    return vQuickTelex;
}

inline void phtvRuntimeSetQuickTelex(const int value) noexcept {
    vQuickTelex = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeUpperCaseFirstChar() noexcept {
    return vUpperCaseFirstChar;
}

inline void phtvRuntimeSetUpperCaseFirstChar(const int value) noexcept {
    vUpperCaseFirstChar = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeAutoRestoreEnglishWord() noexcept {
    return vAutoRestoreEnglishWord;
}

inline void phtvRuntimeSetAutoRestoreEnglishWord(const int value) noexcept {
    vAutoRestoreEnglishWord = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetShowIconOnDock(const bool visible) noexcept {
    vShowIconOnDock = visible ? 1 : 0;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeUseMacro() noexcept {
    return vUseMacro;
}

inline int phtvRuntimeUseMacroInEnglishMode() noexcept {
    return vUseMacroInEnglishMode;
}

inline int phtvRuntimeAutoCapsMacro() noexcept {
    return vAutoCapsMacro;
}

inline int phtvRuntimeQuickStartConsonant() noexcept {
    return vQuickStartConsonant;
}

inline int phtvRuntimeQuickEndConsonant() noexcept {
    return vQuickEndConsonant;
}

inline int phtvRuntimeRememberCode() noexcept {
    return vRememberCode;
}

inline int phtvRuntimePerformLayoutCompat() noexcept {
    return vPerformLayoutCompat;
}

inline int phtvRuntimeShowIconOnDock() noexcept {
    return vShowIconOnDock;
}

inline int phtvRuntimeRestoreOnEscape() noexcept {
    return vRestoreOnEscape;
}

inline int phtvRuntimeCustomEscapeKey() noexcept {
    return vCustomEscapeKey;
}

inline int phtvRuntimePauseKeyEnabled() noexcept {
    return vPauseKeyEnabled;
}

inline int phtvRuntimePauseKey() noexcept {
    return vPauseKey;
}

inline int phtvRuntimeEnableEmojiHotkey() noexcept {
    return vEnableEmojiHotkey;
}

inline int phtvRuntimeEmojiHotkeyModifiers() noexcept {
    return vEmojiHotkeyModifiers;
}

inline int phtvRuntimeEmojiHotkeyKeyCode() noexcept {
    return vEmojiHotkeyKeyCode;
}

inline void phtvRuntimeSetEmojiHotkeySettings(const int enabled,
                                              const int modifiers,
                                              const int keyCode) noexcept {
    vEnableEmojiHotkey = enabled;
    vEmojiHotkeyModifiers = modifiers;
    vEmojiHotkeyKeyCode = keyCode;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeFreeMark() noexcept {
    return vFreeMark;
}

inline void phtvRuntimeSetFreeMark(const int value) noexcept {
    vFreeMark = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetUseMacro(const int value) noexcept {
    vUseMacro = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetUseMacroInEnglishMode(const int value) noexcept {
    vUseMacroInEnglishMode = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetAutoCapsMacro(const int value) noexcept {
    vAutoCapsMacro = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetUseSmartSwitchKey(const bool enabled) noexcept {
    vUseSmartSwitchKey = enabled ? 1 : 0;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetQuickStartConsonant(const int value) noexcept {
    vQuickStartConsonant = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetQuickEndConsonant(const int value) noexcept {
    vQuickEndConsonant = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetRememberCode(const int value) noexcept {
    vRememberCode = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetPerformLayoutCompat(const int value) noexcept {
    vPerformLayoutCompat = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetRestoreOnEscape(const int value) noexcept {
    vRestoreOnEscape = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetCustomEscapeKey(const int value) noexcept {
    vCustomEscapeKey = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetPauseKeyEnabled(const int value) noexcept {
    vPauseKeyEnabled = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetPauseKey(const int value) noexcept {
    vPauseKey = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetFixRecommendBrowser(const int value) noexcept {
    vFixRecommendBrowser = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetTempOffSpelling(const int value) noexcept {
    vTempOffSpelling = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetOtherLanguage(const int value) noexcept {
    vOtherLanguage = value;
    phtvRuntimeBarrier();
}

inline void phtvRuntimeSetTempOffPHTV(const int value) noexcept {
    vTempOffPHTV = value;
    phtvRuntimeBarrier();
}

inline int phtvRuntimeDefaultSwitchHotkeyStatus() noexcept {
    return PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
}

inline int phtvRuntimeDefaultPauseKey() noexcept {
    return KEY_LEFT_OPTION;
}

inline int phtvRuntimeOtherLanguage() noexcept {
    return vOtherLanguage;
}

inline void phtvConvertToolResetOptions() noexcept {
    resetConvertToolOptions();
}

inline void phtvConvertToolNormalizeOptions() noexcept {
    normalizeConvertToolOptions();
}

inline void phtvConvertToolSetOptions(const bool dontAlertWhenCompleted,
                                      const bool toAllCaps,
                                      const bool toAllNonCaps,
                                      const bool toCapsFirstLetter,
                                      const bool toCapsEachWord,
                                      const bool removeMark,
                                      const int fromCode,
                                      const int toCode,
                                      const int hotKey) noexcept {
    gConvertToolOptions.dontAlertWhenCompleted = dontAlertWhenCompleted;
    gConvertToolOptions.toAllCaps = toAllCaps;
    gConvertToolOptions.toAllNonCaps = toAllNonCaps;
    gConvertToolOptions.toCapsFirstLetter = toCapsFirstLetter;
    gConvertToolOptions.toCapsEachWord = toCapsEachWord;
    gConvertToolOptions.removeMark = removeMark;
    gConvertToolOptions.fromCode = static_cast<Uint8>(phtv_clamp_code_table(fromCode));
    gConvertToolOptions.toCode = static_cast<Uint8>(phtv_clamp_code_table(toCode));
    gConvertToolOptions.hotKey = hotKey;
}

inline std::uint16_t phtvEngineHotkeyDisplayCharacter(const std::uint16_t keyCode) noexcept {
    return static_cast<std::uint16_t>(keyCodeToCharacter(static_cast<Uint32>(keyCode) | CAPS_MASK));
}

inline bool phtvEngineFindCodeTableSourceKey(const int codeTable,
                                             const std::uint16_t character,
                                             std::uint32_t* outKeyCode,
                                             int* outVariantIndex) noexcept {
    const int safeCodeTable = phtv_clamp_code_table(codeTable);
    const std::map<Uint32, std::vector<Uint16>>& table = _codeTable[safeCodeTable];
    for (std::map<Uint32, std::vector<Uint16>>::const_iterator tableIt = table.begin();
         tableIt != table.end();
         ++tableIt) {
        const std::vector<Uint16>& variants = tableIt->second;
        for (size_t idx = 0; idx < variants.size(); ++idx) {
            if (variants[idx] != character) continue;
            if (outKeyCode) {
                *outKeyCode = tableIt->first;
            }
            if (outVariantIndex) {
                *outVariantIndex = static_cast<int>(idx);
            }
            return true;
        }
    }
    return false;
}

inline int phtvEngineCodeTableVariantCountForKey(const int codeTable,
                                                 const std::uint32_t keyCode) noexcept {
    const int safeCodeTable = phtv_clamp_code_table(codeTable);
    const std::map<Uint32, std::vector<Uint16>>& table = _codeTable[safeCodeTable];
    const std::map<Uint32, std::vector<Uint16>>::const_iterator it = table.find(keyCode);
    if (it == table.end()) {
        return 0;
    }
    return static_cast<int>(it->second.size());
}

inline bool phtvEngineCodeTableCharacterForKey(const int codeTable,
                                               const std::uint32_t keyCode,
                                               const int variantIndex,
                                               std::uint16_t* outCharacter) noexcept {
    const int safeCodeTable = phtv_clamp_code_table(codeTable);
    const std::map<Uint32, std::vector<Uint16>>& table = _codeTable[safeCodeTable];
    const std::map<Uint32, std::vector<Uint16>>::const_iterator it = table.find(keyCode);
    if (it == table.end()) {
        return false;
    }
    if (variantIndex < 0 || variantIndex >= static_cast<int>(it->second.size())) {
        return false;
    }
    if (outCharacter) {
        *outCharacter = it->second[static_cast<size_t>(variantIndex)];
    }
    return true;
}

inline int phtvEngineSpaceKeyCode() noexcept {
    return KEY_SPACE;
}

inline std::uint32_t phtvEngineCapsMask() noexcept {
    return CAPS_MASK;
}

inline std::uint32_t phtvEngineCharCodeMask() noexcept {
    return CHAR_CODE_MASK;
}

inline std::uint32_t phtvEnginePureCharacterMask() noexcept {
    return PURE_CHARACTER_MASK;
}

inline std::uint16_t phtvEngineMacroKeyCodeToCharacter(const std::uint32_t keyData) noexcept {
    return keyCodeToCharacter(static_cast<Uint32>(keyData));
}

inline std::uint16_t phtvEngineLowByte(const std::uint32_t data) noexcept {
    return static_cast<std::uint16_t>(data & 0xFF);
}

inline std::uint16_t phtvEngineHiByte(const std::uint32_t data) noexcept {
    return static_cast<std::uint16_t>((data >> 8) & 0xFF);
}

// MARK: - Runtime flag helpers

inline bool phtvRuntimeIsDoubleCode(const int codeTable) noexcept {
    return codeTable == 2 || codeTable == 3;
}

// MARK: - Event marker

inline std::int64_t phtvEventMarkerValue() noexcept {
    return 0x50485456; // "PHTV"
}

// MARK: - Unicode Compound mark table

inline std::uint16_t phtvEngineUnicodeCompoundMarkAt(const int index) noexcept {
    extern Uint16 _unicodeCompoundMark[];
    return (index >= 0) ? _unicodeCompoundMark[index] : 0;
}

// MARK: - Engine output state (pData) field accessors

extern vKeyHookState* pData;

inline std::uint8_t phtvEngineDataCode() noexcept {
    return pData ? pData->code : 0;
}

inline std::uint8_t phtvEngineDataExtCode() noexcept {
    return pData ? pData->extCode : 0;
}

inline std::uint8_t phtvEngineDataBackspaceCount() noexcept {
    return pData ? pData->backspaceCount : 0;
}

inline void phtvEngineDataSetBackspaceCount(const std::uint8_t count) noexcept {
    if (pData) pData->backspaceCount = count;
}

inline std::uint8_t phtvEngineDataNewCharCount() noexcept {
    return pData ? pData->newCharCount : 0;
}

inline std::uint32_t phtvEngineDataCharAt(const int index) noexcept {
    if (!pData || index < 0 || index >= MAX_BUFF) return 0;
    return pData->charData[index];
}

inline int phtvEngineDataMacroDataSize() noexcept {
    return pData ? static_cast<int>(pData->macroData.size()) : 0;
}

inline std::uint32_t phtvEngineDataMacroDataAt(const int index) noexcept {
    if (!pData || index < 0 || index >= static_cast<int>(pData->macroData.size())) return 0;
    return pData->macroData[index];
}

inline const std::uint32_t* phtvEngineDataMacroDataPtr() noexcept {
    return pData ? pData->macroData.data() : nullptr;
}

// MARK: - Engine action codes

inline int phtvEngineVRestoreCode() noexcept {
    return static_cast<int>(vRestore);
}

inline int phtvEngineVRestoreAndStartNewSessionCode() noexcept {
    return static_cast<int>(vRestoreAndStartNewSession);
}

// MARK: - Session helpers

inline void phtvRuntimeStartNewSession() noexcept {
    startNewSession();
}

// MARK: - Runtime flag getters

inline int phtvRuntimeFixRecommendBrowser() noexcept {
    return vFixRecommendBrowser;
}

inline int phtvRuntimeUpperCaseExcludedForCurrentApp() noexcept {
    return vUpperCaseExcludedForCurrentApp;
}

inline int phtvRuntimeTempOffPHTV() noexcept {
    return vTempOffPHTV;
}

inline int phtvRuntimeTempOffSpelling() noexcept {
    return vTempOffSpelling;
}

// MARK: - Engine action codes (additional)

inline int phtvEngineVDoNothingCode() noexcept {
    return static_cast<int>(vDoNothing);
}

inline int phtvEngineVWillProcessCode() noexcept {
    return static_cast<int>(vWillProcess);
}

inline int phtvEngineVReplaceMaroCode() noexcept {
    return static_cast<int>(vReplaceMaro);
}

inline int phtvEngineMaxBuff() noexcept {
    return MAX_BUFF;
}

// MARK: - Key code constants

inline int phtvEngineKeyDeleteCode() noexcept {
    return KEY_DELETE;
}

inline int phtvEngineKeySlashCode() noexcept {
    return KEY_SLASH;
}

inline int phtvEngineKeyEnterCode() noexcept {
    return KEY_ENTER;
}

inline int phtvEngineKeyReturnCode() noexcept {
    return KEY_RETURN;
}

// MARK: - Engine function wrappers

inline void phtvEngineInitializeAndGetKeyHookState() noexcept {
    pData = static_cast<vKeyHookState*>(vKeyInit());
}

inline void phtvEngineHandleKeyboardKeyDown(const std::uint16_t keyCode,
                                             const std::uint8_t capsStatus,
                                             const bool hasOtherControlKey) noexcept {
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown,
                    keyCode, capsStatus, hasOtherControlKey);
}

inline void phtvEngineHandleMouseDown() noexcept {
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
}

inline void phtvEngineHandleEnglishModeKeyDown(const std::uint16_t keyCode,
                                                const bool isCaps,
                                                const bool hasOtherControlKey) noexcept {
    vEnglishMode(vKeyEventState::KeyDown, keyCode, isCaps, hasOtherControlKey);
}

inline bool phtvEngineRestoreToRawKeys() noexcept {
    return vRestoreToRawKeys();
}

inline void phtvEnginePrimeUpperCaseFirstChar() noexcept {
    vPrimeUpperCaseFirstChar();
}

inline void phtvEngineTempOffSpellChecking() noexcept {
    vTempOffSpellChecking();
}

inline void phtvEngineTempOffEngine() noexcept {
    vTempOffEngine();
}

inline bool phtvMacKeyIsNavigation(const std::uint16_t keyCode) noexcept {
    return phtv_mac_key_is_navigation(keyCode);
}

#endif

#endif /* PHTVEngineCxxInterop_hpp */
