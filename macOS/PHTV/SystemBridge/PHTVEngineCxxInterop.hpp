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

#include "../Core/Engine/Engine.h"
#include "../Core/PHTVConstants.h"

extern volatile int vSendKeyStepByStep;
extern volatile int vPerformLayoutCompat;
extern volatile int vEnableEmojiHotkey;
extern volatile int vEmojiHotkeyModifiers;
extern volatile int vEmojiHotkeyKeyCode;
extern volatile int vSafeMode;
extern int vShowIconOnDock;

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

inline int phtvEngineQuickConvertHotkey() noexcept {
    return gConvertToolOptions.hotKey;
}

inline int phtvConvertToolDefaultHotKey() noexcept {
    return defaultConvertToolOptions().hotKey;
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

inline bool phtvEngineHotkeyHasControl(const int hotkey) noexcept {
    return HAS_CONTROL(hotkey) != 0;
}

inline bool phtvEngineHotkeyHasOption(const int hotkey) noexcept {
    return HAS_OPTION(hotkey) != 0;
}

inline bool phtvEngineHotkeyHasCommand(const int hotkey) noexcept {
    return HAS_COMMAND(hotkey) != 0;
}

inline bool phtvEngineHotkeyHasShift(const int hotkey) noexcept {
    return HAS_SHIFT(hotkey) != 0;
}

inline bool phtvEngineHotkeyHasKey(const int hotkey) noexcept {
    return HOTKEY_HAS_KEY(hotkey) != 0;
}

inline std::uint16_t phtvEngineHotkeySwitchKey(const int hotkey) noexcept {
    return static_cast<std::uint16_t>(GET_SWITCH_KEY(hotkey));
}

inline std::uint16_t phtvEngineHotkeyDisplayCharacter(const std::uint16_t keyCode) noexcept {
    return static_cast<std::uint16_t>(keyCodeToCharacter(static_cast<Uint32>(keyCode) | CAPS_MASK));
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

#endif

#endif /* PHTVEngineCxxInterop_hpp */
