//
//  Macro.cpp
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#include "Macro.h"
#include "Vietnamese.h"
#include "Engine.h"

using namespace std;

extern "C" void phtvLoadMacroMapFromBinary(const Byte* data, int size);
extern "C" int phtvFindMacroContentForNormalizedKeys(const Uint32* normalizedKeyBuffer,
                                                     int keyCount,
                                                     int autoCapsEnabled,
                                                     Uint32* outputBuffer,
                                                     int outputCapacity);

extern "C" {
void initMacroMap(const Byte* pData, const int& size) {
    phtvLoadMacroMapFromBinary(pData, size);
}
}

bool findMacro(vector<Uint32>& key, vector<Uint32>& macroContentCode) {
    for (size_t i = 0; i < key.size(); i++) {
        key[i] = getCharacterCode(key[i]);
    }

    const Uint32* keyBuffer = key.empty() ? nullptr : key.data();
    const int keyCount = static_cast<int>(key.size());

    const int requiredLength = phtvFindMacroContentForNormalizedKeys(
        keyBuffer,
        keyCount,
        vAutoCapsMacro,
        nullptr,
        0
    );
    if (requiredLength < 0) {
        macroContentCode.clear();
        return false;
    }

    if (requiredLength == 0) {
        macroContentCode.clear();
        return true;
    }

    macroContentCode.assign(static_cast<size_t>(requiredLength), 0);
    const int actualLength = phtvFindMacroContentForNormalizedKeys(
        keyBuffer,
        keyCount,
        vAutoCapsMacro,
        macroContentCode.data(),
        requiredLength
    );
    if (actualLength < 0) {
        macroContentCode.clear();
        return false;
    }

    if (actualLength < requiredLength) {
        macroContentCode.resize(static_cast<size_t>(actualLength));
    }

    return true;
}
