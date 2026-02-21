//
//  PHTVEngineCBridge.h
//  PHTV
//

#ifndef PHTVEngineCBridge_h
#define PHTVEngineCBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    PHTV_ENGINE_EVENT_KEYBOARD = 0,
    PHTV_ENGINE_EVENT_MOUSE = 1,
    PHTV_ENGINE_EVENT_STATE_KEY_DOWN = 0,
    PHTV_ENGINE_EVENT_STATE_KEY_UP = 1,
    PHTV_ENGINE_EVENT_STATE_MOUSE_DOWN = 2,
    PHTV_ENGINE_EVENT_STATE_MOUSE_UP = 3
};

void phtvEngineHandleEvent(int event, int state, uint16_t data, uint8_t capsStatus, int otherControlKey);
void phtvEngineHandleEnglishMode(int state, uint16_t data, int isCaps, int otherControlKey);
void phtvEnginePrimeUpperCaseFirstChar(void);
int phtvEngineRestoreToRawKeys(void);
void phtvEngineTempOffSpellChecking(void);
void phtvEngineTempOff(int off);
void phtvEngineSetCheckSpelling(void);
void phtvEngineStartNewSession(void);
void phtvEngineInitialize(void);
int phtvEngineHookCode(void);
int phtvEngineHookExtCode(void);
int phtvEngineHookBackspaceCount(void);
void phtvEngineHookSetBackspaceCount(uint8_t count);
int phtvEngineHookNewCharCount(void);
uint32_t phtvEngineHookCharAt(int index);
int phtvEngineHookMacroDataSize(void);
uint32_t phtvEngineHookMacroDataAt(int index);

void phtvLoadMacroMapFromBinary(const uint8_t* data, int size);
int phtvFindMacroContentForNormalizedKeys(const uint32_t* normalizedKeyBuffer,
                                          int keyCount,
                                          int autoCapsEnabled,
                                          uint32_t* outputBuffer,
                                          int outputCapacity);

int phtvRuntimeAutoCapsMacroValue(void);
int phtvRuntimeRestoreOnEscapeEnabled(void);
int phtvRuntimeAutoRestoreEnglishWordEnabled(void);
int phtvRuntimeUpperCaseFirstCharEnabled(void);
int phtvRuntimeUpperCaseExcludedForCurrentApp(void);
int phtvRuntimeUseMacroEnabled(void);
int phtvRuntimeInputTypeValue(void);
int phtvRuntimeCodeTableValue(void);
int phtvRuntimeCheckSpellingValue(void);
void phtvRuntimeSetCheckSpellingValue(int value);
int phtvRuntimeUseModernOrthographyEnabled(void);
int phtvRuntimeQuickTelexEnabled(void);
int phtvRuntimeFreeMarkEnabled(void);
int phtvRuntimeAllowConsonantZFWJEnabled(void);
int phtvRuntimeQuickStartConsonantEnabled(void);
int phtvRuntimeQuickEndConsonantEnabled(void);

int phtvCustomDictionaryEnglishCount(void);
int phtvCustomDictionaryVietnameseCount(void);
int phtvCustomDictionaryContainsEnglishWord(const char* wordCString);
int phtvCustomDictionaryContainsVietnameseWord(const char* wordCString);
void phtvCustomDictionaryLoadJSON(const char* jsonData, int length);
void phtvCustomDictionaryClear(void);

int phtvDictionaryInitEnglish(const char* filePath);
int phtvDictionaryInitVietnamese(const char* filePath);
int phtvDictionaryIsEnglishInitialized(void);
int phtvDictionaryEnglishWordCount(void);
int phtvDictionaryVietnameseWordCount(void);
int phtvDictionaryContainsEnglishIndices(const uint8_t* indices, int length);
int phtvDictionaryContainsVietnameseIndices(const uint8_t* indices, int length);
void phtvDictionaryClear(void);

int phtvDetectorShouldRestoreEnglishWord(const uint32_t* keyStates, int stateIndex);
int phtvDetectorIsEnglishWordUtf8(const char* wordCString);
int phtvDetectorIsEnglishWordFromKeyStates(const uint32_t* keyStates, int stateIndex);
int phtvDetectorIsVietnameseWordFromKeyStates(const uint32_t* keyStates, int stateIndex);
int phtvDetectorKeyStatesToAscii(const uint32_t* keyStates,
                                 int count,
                                 char* outputBuffer,
                                 int outputBufferSize);

#ifdef __cplusplus
}
#endif

#endif /* PHTVEngineCBridge_h */
