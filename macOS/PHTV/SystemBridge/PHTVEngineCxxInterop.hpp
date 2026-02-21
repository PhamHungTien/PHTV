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

extern volatile int vSendKeyStepByStep;

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

inline int phtvRuntimeCheckSpelling() noexcept {
    return vCheckSpelling;
}

inline void phtvRuntimeSetCheckSpelling(const int value) noexcept {
    vCheckSpelling = value;
    phtvRuntimeBarrier();
}

inline int phtvEngineQuickConvertHotkey() noexcept {
    return gConvertToolOptions.hotKey;
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
