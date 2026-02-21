//
//  Engine.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef Engine_h
#define Engine_h

#include <locale>
#include <codecvt>
#include <string>

#include "DataType.h"
#include "../PHTVHotkey.h"
#include "Vietnamese.h"
#include "Macro.h"
#include "EnglishWordDetector.h"

#ifndef LOBYTE
#define LOBYTE(data) (data & 0xFF)
#endif // !LOBYTE
#ifndef HIBYTE
#define HIBYTE(data) ((data>>8) & 0xFF)
#endif // !HIBYTE

//define these variable in your application
//API
/*
 * 0: Telex
 * 1: VNI
 * VOLATILE: Read by event tap thread, written by main thread
 */
extern volatile int vInputType;

/**
 * 0: No
 * 1: Yes
 */
extern int vFreeMark;

/*
 * 0: Unicode
 * 1: TCVN3 (ABC)
 * 2: VNI-Windows
 * VOLATILE: Read by event tap thread, written by main thread
 */
extern volatile int vCodeTable;

/**
 * 0: No
 * 1: Yes
 */
extern volatile int vCheckSpelling;

/*
 * 0: òa, úy
 * 1: oà uý
*/
extern volatile int vUseModernOrthography;

/**
 * 0: No
 * 1: Yes
 * (cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th, uu=ươ)
 */
extern volatile int vQuickTelex;

/**
 * Work together with vCheckSpelling
 * 0: No
 * 1: Yes
 *
 */

/**
 * Macro on or off
 */
extern volatile int vUseMacro;

/**
 * Ex: define: btw -> by the way
 * Type: `Btw` -> `By the way`
 * Type: `BTW` -> `BY THE WAY`
 */
extern volatile int vAutoCapsMacro;

/**
 * Auto write upper case character for first letter.
 * 0: No
 * 1: Yes
 */
extern volatile int vUpperCaseFirstChar;

/**
 * Current app is excluded from uppercase first char feature.
 * 0: No (apply uppercase)
 * 1: Yes (skip uppercase for this app)
 */
extern volatile int vUpperCaseExcludedForCurrentApp;

/**
 * Allow write word with consonant Z, F, W, J
 * 0: No
 * 1: Yes
 */
extern volatile int vAllowConsonantZFWJ;

/**
 * 0: No; 1: Yes
 * f -> ph: fanh -> phanh,...
 * j ->gi: jang -> giang,...
 * w ->qu: wen -> quen,...
 */
extern volatile int vQuickStartConsonant;

/**
 * 0: No; 1: Yes
 * g -> ng: hag -> hang,...
 * h -> nh: vih -> vinh,...
 * k -> ch: bak -> bach,...
 */
extern volatile int vQuickEndConsonant;

/**
 * Auto restore English word feature
 * When enabled, automatically restores English words when typed in Vietnamese mode
 * Example: typing "tẻminal" → restores to "terminal"
 * 0: Disabled
 * 1: Enabled
 */
extern volatile int vAutoRestoreEnglishWord;

/**
 * Prime uppercase for the next character when auto-capitalization is enabled.
 */
void vPrimeUpperCaseFirstChar();

/**
 * Call this function first to receive data pointer
 */
void* vKeyInit();

/**
 * Convert engine character to real character
 */
Uint32 getCharacterCode(const Uint32& data);

/**
 * MAIN entry point for each key
 * event: mouse or keyboard event
 * state: additional state for event
 * data: key code
 * isCaps: caplock is on or shift key is pressing
 * otherControlKey: ctrl, option,... is pressing
 */
void vKeyHandleEvent(const vKeyEvent& event,
                     const vKeyEventState& state,
                     const Uint16& data,
                     const Uint8& capsStatus=0,
                     const bool& otherControlKey=false);

/**
 * Start a new word
 */
void startNewSession();

/**
 * do some task in english mode (use for macro)
 */
void vEnglishMode(const vKeyEventState& state, const Uint16& data, const bool& isCaps, const bool& otherControlKey);

/**
 * temporarily turn off spell checking
 */
void vTempOffSpellChecking();

/**
 * reset spelling value
 */
void vSetCheckSpelling();

/**
 * temporarily turn off PHTV engine
 */
void vTempOffEngine(const bool& off=true);

/**
 * Manually trigger restore to raw keys
 * Returns true if restore was successful
 */
bool vRestoreToRawKeys();

/**
 * Restore session with word
 */
void vRestoreSessionWithWord(const std::wstring& word);

/**
 * some utils function
 */
std::wstring utf8ToWideString(const std::string& str);
std::string wideStringToUtf8(const std::wstring& str);

#endif /* Engine_h */
