//
//  PHTVEngineDataCoreBridge.h
//  PHTV
//
//  C bridge for C++ engine data APIs consumed by Swift.
//

#ifndef PHTVEngineDataCoreBridge_h
#define PHTVEngineDataCoreBridge_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void PHTVEngineInitializeMacroMap(const unsigned char *_Nullable data, int length);

bool PHTVEngineInitializeEnglishDictionary(const char *_Nullable path);
unsigned long PHTVEngineEnglishDictionarySize(void);

bool PHTVEngineInitializeVietnameseDictionary(const char *_Nullable path);
unsigned long PHTVEngineVietnameseDictionarySize(void);

void PHTVEngineInitializeCustomDictionary(const char *_Nullable jsonData, int length);
unsigned long PHTVEngineCustomEnglishWordCount(void);
unsigned long PHTVEngineCustomVietnameseWordCount(void);
void PHTVEngineClearCustomDictionary(void);

void PHTVEngineSetCheckSpellingValue(int value);
void PHTVEngineApplyCheckSpelling(void);
void PHTVEngineNotifyTableCodeChanged(void);

int PHTVEngineQuickConvertHotkey(void);
bool PHTVEngineHotkeyHasControl(int hotkey);
bool PHTVEngineHotkeyHasOption(int hotkey);
bool PHTVEngineHotkeyHasCommand(int hotkey);
bool PHTVEngineHotkeyHasShift(int hotkey);
bool PHTVEngineHotkeyHasKey(int hotkey);
uint16_t PHTVEngineHotkeySwitchKey(int hotkey);
uint16_t PHTVEngineHotkeyDisplayCharacter(uint16_t keyCode);
int PHTVEngineSpaceKeyCode(void);

#ifdef __cplusplus
}
#endif

#endif /* PHTVEngineDataCoreBridge_h */
