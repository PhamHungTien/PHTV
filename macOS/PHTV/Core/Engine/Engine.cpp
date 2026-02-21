//
//  Engine.cpp
//  PHTV
//
//  Created byPhạm Hùng Tiến on 2026.
//  Copyright © 2026 phạm Hùng Tiến. All rights reserved.
//
#include <iostream>
#include <algorithm>
#include <map>
#include <unordered_set>
#include <string>
#include "PHTVEngineCBridge.inc"
#include "EngineDataTypes.inc"
#include <string.h>
#include <list>
#include <cstdio>

using namespace std;

void vPrimeUpperCaseFirstChar();
void* vKeyInit();
Uint32 getCharacterCode(const Uint32& data);
void vKeyHandleEvent(const vKeyEvent& event,
                     const vKeyEventState& state,
                     const Uint16& data,
                     const Uint8& capsStatus,
                     const bool& otherControlKey);
void startNewSession();
void vEnglishMode(const vKeyEventState& state, const Uint16& data, const bool& isCaps, const bool& otherControlKey);
void vTempOffSpellChecking();
void vSetCheckSpelling();
void vTempOffEngine(const bool& off);
bool vRestoreToRawKeys();
void vRestoreSessionWithWord(const std::wstring& word);

#include "VietnameseData.inc"

#include "EngineCoreLogic.inc"
#include "EngineBridgeExports.inc"
