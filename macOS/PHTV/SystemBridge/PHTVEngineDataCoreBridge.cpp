//
//  PHTVEngineDataCoreBridge.cpp
//  PHTV
//
//  C bridge implementation for C++ engine data APIs.
//

#include "PHTVEngineDataCoreBridge.h"
#include "../Core/Engine/Engine.h"

extern "C" {

void PHTVEngineInitializeMacroMap(const unsigned char *data, int length) {
    if (!data || length <= 0) {
        initMacroMap(nullptr, 0);
        return;
    }
    initMacroMap(data, length);
}

bool PHTVEngineInitializeEnglishDictionary(const char *path) {
    if (!path || path[0] == '\0') {
        return false;
    }
    return initEnglishDictionary(std::string(path));
}

unsigned long PHTVEngineEnglishDictionarySize(void) {
    return (unsigned long)getEnglishDictionarySize();
}

bool PHTVEngineInitializeVietnameseDictionary(const char *path) {
    if (!path || path[0] == '\0') {
        return false;
    }
    return initVietnameseDictionary(std::string(path));
}

unsigned long PHTVEngineVietnameseDictionarySize(void) {
    return (unsigned long)getVietnameseDictionarySize();
}

void PHTVEngineInitializeCustomDictionary(const char *jsonData, int length) {
    if (!jsonData || length <= 0) {
        initCustomDictionary(nullptr, 0);
        return;
    }
    initCustomDictionary(jsonData, length);
}

unsigned long PHTVEngineCustomEnglishWordCount(void) {
    return (unsigned long)getCustomEnglishWordCount();
}

unsigned long PHTVEngineCustomVietnameseWordCount(void) {
    return (unsigned long)getCustomVietnameseWordCount();
}

void PHTVEngineClearCustomDictionary(void) {
    clearCustomDictionary();
}

void PHTVEngineSetCheckSpellingValue(int value) {
    vCheckSpelling = value;
}

int PHTVEngineQuickConvertHotkey(void) {
    return gConvertToolOptions.hotKey;
}

bool PHTVEngineHotkeyHasControl(int hotkey) {
    return HAS_CONTROL(hotkey);
}

bool PHTVEngineHotkeyHasOption(int hotkey) {
    return HAS_OPTION(hotkey);
}

bool PHTVEngineHotkeyHasCommand(int hotkey) {
    return HAS_COMMAND(hotkey);
}

bool PHTVEngineHotkeyHasShift(int hotkey) {
    return HAS_SHIFT(hotkey);
}

bool PHTVEngineHotkeyHasKey(int hotkey) {
    return HOTKEY_HAS_KEY(hotkey);
}

uint16_t PHTVEngineHotkeySwitchKey(int hotkey) {
    return (uint16_t)GET_SWITCH_KEY(hotkey);
}

uint16_t PHTVEngineHotkeyDisplayCharacter(uint16_t keyCode) {
    return (uint16_t)keyCodeToCharacter((Uint32)keyCode | CAPS_MASK);
}

int PHTVEngineSpaceKeyCode(void) {
    return KEY_SPACE;
}

} // extern "C"
