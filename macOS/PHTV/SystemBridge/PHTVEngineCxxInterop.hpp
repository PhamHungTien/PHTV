//
//  PHTVEngineCxxInterop.hpp
//  PHTV
//
//  Swift-facing C++ interop wrappers around engine hotkey/character helpers.
//

#ifndef PHTVEngineCxxInterop_hpp
#define PHTVEngineCxxInterop_hpp

#ifdef __cplusplus

#include <cstdint>

#include "../Core/Engine/ConvertTool.h"
#include "../Core/Engine/DataType.h"
#include "../Core/Engine/Vietnamese.h"
#include "../Core/PHTVHotkey.h"

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
