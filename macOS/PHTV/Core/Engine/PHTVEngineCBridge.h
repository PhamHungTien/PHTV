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

#ifdef __cplusplus
}
#endif

#endif /* PHTVEngineCBridge_h */
