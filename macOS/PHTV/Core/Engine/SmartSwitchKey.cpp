//
//  SmartSwitchKey.cpp
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#include "SmartSwitchKey.h"
#include <limits>
#include <map>

//main data, i use `map` because it has O(Log(n))
static std::map<std::string, Int8> _smartSwitchKeyData;
static std::string _cacheKey = ""; //use cache for faster
static Int8 _cacheData = 0; //use cache for faster

namespace {
Int8 clampToSmartSwitchStorageValue(int value) {
    if (value < std::numeric_limits<Int8>::min()) {
        return std::numeric_limits<Int8>::min();
    }
    if (value > std::numeric_limits<Int8>::max()) {
        return std::numeric_limits<Int8>::max();
    }
    return static_cast<Int8>(value);
}
}

void initSmartSwitchKey(const Byte* pData, int size) {
    _smartSwitchKeyData.clear();
    _cacheKey.clear();
    _cacheData = 0;

    if (pData == nullptr || size < 2) {
        return;
    }

    const size_t maxSize = static_cast<size_t>(size);
    const Uint16 count = static_cast<Uint16>(pData[0] | (pData[1] << 8));
    size_t cursor = 2;

    for (Uint16 i = 0; i < count; ++i) {
        if (cursor >= maxSize) {
            break;
        }

        const Uint8 bundleIdSize = pData[cursor++];
        if (cursor + bundleIdSize + 1 > maxSize) {
            break;
        }

        std::string bundleId(reinterpret_cast<const char*>(pData + cursor), bundleIdSize);
        cursor += bundleIdSize;
        const Int8 inputState = static_cast<Int8>(pData[cursor++]);
        _smartSwitchKeyData[bundleId] = inputState;
    }
}

void getSmartSwitchKeySaveData(std::vector<Byte>& outData) {
    outData.clear();
    size_t count = 0;
    size_t totalBytes = 2;
    const size_t maxCount = std::numeric_limits<Uint16>::max();
    const size_t maxBundleIdSize = std::numeric_limits<Uint8>::max();

    for (std::map<std::string, Int8>::const_iterator it = _smartSwitchKeyData.begin(); it != _smartSwitchKeyData.end(); ++it) {
        if (it->first.size() > maxBundleIdSize) {
            continue;
        }
        if (count >= maxCount) {
            break;
        }
        totalBytes += 1 + it->first.size() + 1;
        ++count;
    }

    outData.reserve(totalBytes);
    const Uint16 headerCount = static_cast<Uint16>(count);
    outData.push_back(static_cast<Byte>(headerCount & 0xFF));
    outData.push_back(static_cast<Byte>((headerCount >> 8) & 0xFF));

    size_t written = 0;
    for (std::map<std::string, Int8>::const_iterator it = _smartSwitchKeyData.begin(); it != _smartSwitchKeyData.end() && written < count; ++it) {
        if (it->first.size() > maxBundleIdSize) {
            continue;
        }

        outData.push_back(static_cast<Byte>(it->first.length()));
        for (size_t j = 0; j < it->first.length(); ++j) {
            outData.push_back(static_cast<Byte>(it->first[j]));
        }
        outData.push_back(static_cast<Byte>(it->second));
        ++written;
    }
}

int getAppInputMethodStatus(const std::string& bundleId, int defaultInputState) {
    if (_cacheKey.compare(bundleId) == 0) {
        return _cacheData;
    }

    std::map<std::string, Int8>::const_iterator it = _smartSwitchKeyData.find(bundleId);
    if (it != _smartSwitchKeyData.end()) {
        _cacheKey = bundleId;
        _cacheData = it->second;
        return _cacheData;
    }

    _cacheKey = bundleId;
    _cacheData = clampToSmartSwitchStorageValue(defaultInputState);
    _smartSwitchKeyData[bundleId] = _cacheData;
    return SMART_SWITCH_NOT_FOUND;
}

void setAppInputMethodStatus(const std::string& bundleId, int inputState) {
    const Int8 normalizedInputState = clampToSmartSwitchStorageValue(inputState);
    _smartSwitchKeyData[bundleId] = normalizedInputState;
    _cacheKey = bundleId;
    _cacheData = normalizedInputState;
}
