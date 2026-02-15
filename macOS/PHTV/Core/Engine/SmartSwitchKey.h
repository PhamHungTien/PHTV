//
//  SmartSwitchKey.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef SmartSwitchKey_h
#define SmartSwitchKey_h

#include "DataType.h"
#include <string>

constexpr int SMART_SWITCH_NOT_FOUND = -1;
constexpr int SMART_SWITCH_LANGUAGE_MASK = 0x01;
constexpr int SMART_SWITCH_CODE_TABLE_SHIFT = 1;

inline int encodeSmartSwitchInputState(int inputMethod, int codeTable) {
    return (inputMethod & SMART_SWITCH_LANGUAGE_MASK) | (codeTable << SMART_SWITCH_CODE_TABLE_SHIFT);
}

inline int decodeSmartSwitchInputMethod(int state) {
    return state & SMART_SWITCH_LANGUAGE_MASK;
}

inline int decodeSmartSwitchCodeTable(int state) {
    return state >> SMART_SWITCH_CODE_TABLE_SHIFT;
}

void initSmartSwitchKey(const Byte* pData, int size);

/**
 * convert all data to save on disk
 */
void getSmartSwitchKeySaveData(std::vector<Byte>& outData);

/**
 * Find and get encoded input state for bundleId.
 * If not found, defaultInputState is inserted for this bundle.
 * return:
 * SMART_SWITCH_NOT_FOUND: bundleId was not present before this call.
 * Otherwise: encoded value from encodeSmartSwitchInputState().
 */
int getAppInputMethodStatus(const std::string& bundleId, int defaultInputState);

/**
 * Set encoded input state for this bundleId.
 */
void setAppInputMethodStatus(const std::string& bundleId, int inputState);

#endif /* SmartSwitchKey_h */
