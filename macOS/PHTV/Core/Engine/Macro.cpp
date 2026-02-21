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
#include <memory.h>
#include <cstring>
#include <mutex>

using namespace std;

//main data
map<vector<Uint32>, MacroData> macroMap;

// Thread safety: protect macroMap access between main thread (AppDelegate) and event tap thread
static std::mutex macroMapMutex;

extern "C" int phtvComputeSnippetContent(int snippetType,
                                         const char* format,
                                         char* outputBuffer,
                                         int outputCapacity);
extern "C" int phtvConvertUtf8ToMacroCode(const char* utf8CString,
                                          Uint32* outputBuffer,
                                          int outputCapacity);

static string computeSnippet(const int snippetType, const string& format) {
    const int requiredLength = phtvComputeSnippetContent(
        snippetType,
        format.c_str(),
        nullptr,
        0
    );
    if (requiredLength <= 0) {
        return "";
    }

    vector<char> buffer(static_cast<size_t>(requiredLength) + 1, '\0');
    const int actualLength = phtvComputeSnippetContent(
        snippetType,
        format.c_str(),
        buffer.data(),
        static_cast<int>(buffer.size())
    );
    if (actualLength <= 0) {
        return "";
    }

    return string(buffer.data(), static_cast<size_t>(actualLength));
}

extern volatile int vCodeTable;
//local variable
static int c = 0;
static bool _macroFlag = false;
static Uint16 _kChar = 0;
static Uint32 _charBuff;
static int _kMacro;

static void convert(const string& str, vector<Uint32>& outData) {
    outData.clear();
    if (str.empty()) {
        return;
    }

    const int requiredLength = phtvConvertUtf8ToMacroCode(
        str.c_str(),
        nullptr,
        0
    );
    if (requiredLength <= 0) {
        return;
    }

    vector<Uint32> bridgeBuffer(static_cast<size_t>(requiredLength), 0);
    const int actualLength = phtvConvertUtf8ToMacroCode(
        str.c_str(),
        bridgeBuffer.data(),
        static_cast<int>(bridgeBuffer.size())
    );
    if (actualLength > 0 && actualLength <= static_cast<int>(bridgeBuffer.size())) {
        outData.assign(bridgeBuffer.begin(), bridgeBuffer.begin() + static_cast<size_t>(actualLength));
        return;
    }
}

/**
 * data structure:
 * byte 0 and 1: macro count
 *
 * byte n: macroText size (macroTextSize)
 * byte n + macroTextSize: macroText data
 *
 * byte m, m+1: macroContentSize
 * byte m+1 + macroContentSize: macroContent data
 *
 * byte p: snippetType (0=static, 1=date, 2=time, etc.)
 *
 * ...
 * next macro
 */
extern "C" {
void initMacroMap(const Byte* pData, const int& size) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    macroMap.clear();

    // Handle empty or null data
    if (!pData || size < 2) {
        return;
    }

    Uint16 macroCount = 0;
    Uint32 cursor = 0;
    memcpy(&macroCount, pData + cursor, 2);
    cursor+=2;

    Uint8 macroTextSize;
    Uint16 macroContentSize;
    Uint8 snippetType;
    for (int i = 0; i < macroCount; i++) {
        macroTextSize = pData[cursor++];
        string macroText((char*)pData + cursor, macroTextSize);
        cursor += macroTextSize;

        memcpy(&macroContentSize, pData + cursor, 2);
        cursor+=2;
        string macroContent((char*)pData + cursor, macroContentSize);
        cursor += macroContentSize;

        // Read snippetType (1 byte) - defaults to 0 if not present (backward compat)
        snippetType = 0;
        if (cursor < size) {
            snippetType = pData[cursor++];
        }

        MacroData data;
        data.macroText = macroText;
        data.macroContent = macroContent;
        data.snippetType = snippetType;

        vector<Uint32> key;
        convert(macroText, key);

        // For static snippets, pre-convert content
        // For dynamic snippets, content will be computed at runtime
        if (snippetType == SNIPPET_STATIC) {
            convert(macroContent, data.macroContentCode);
        }

        macroMap[key] = data;
    }
}
}

static bool modifyCaseUnicode(Uint32& code, const bool& isUpperCase=true) {
    _charBuff = code;
    if (!(code & CHAR_CODE_MASK)) { //for normal char
        code &= isUpperCase ? CAPS_MASK :  ~CAPS_MASK;
        return code != _charBuff;
    }
    
    //for unicode character
    for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[vCodeTable].begin(); it != _codeTable[vCodeTable].end(); ++it) {
        for (_kMacro = 0; _kMacro < it->second.size(); _kMacro++) {
            if ((Uint16)code == it->second[_kMacro]) {
                if (_kMacro % 2 == 0 && !isUpperCase)
                    _kMacro++;
                else if (_kMacro % 2 != 0 && isUpperCase)
                    _kMacro--;
                code = _codeTable[vCodeTable][it->first][_kMacro] | CHAR_CODE_MASK;
                return code != _charBuff;;
            }//end if
        }
    }
    return false;
}

// Helper to get content code for a macro (handles dynamic snippets)
static void getMacroContentCode(const MacroData& data, vector<Uint32>& outCode, bool applyAutoCaps = false, bool allCaps = false) {
    outCode.clear();

    if (data.snippetType == SNIPPET_STATIC) {
        // Static content - use pre-converted code
        outCode = data.macroContentCode;
    } else if (data.snippetType == SNIPPET_CLIPBOARD) {
        // Clipboard - content will be empty, handled by AppDelegate
        // Just return empty, the Objective-C layer will handle it
        return;
    } else {
        // Dynamic snippet - compute content now
        string dynamicContent = computeSnippet(data.snippetType, data.macroContent);
        convert(dynamicContent, outCode);
    }

    // Apply auto-caps if needed
    if (applyAutoCaps && !outCode.empty()) {
        for (c = 0; c < outCode.size(); c++) {
            if (c == 0 || allCaps) {
                _kChar = keyCodeToCharacter(outCode[c]);
                if (_kChar != 0) {
                    _kChar = toupper(_kChar);
                    outCode[c] = _characterMap[_kChar];
                } else if (outCode[c] & CHAR_CODE_MASK) {
                    modifyCaseUnicode(outCode[c]);
                }
            }
        }
    }
}

bool findMacro(vector<Uint32>& key, vector<Uint32>& macroContentCode) {
    std::lock_guard<std::mutex> lock(macroMapMutex);

    // Normalize character codes once
    for (c = 0; c < key.size(); c++) {
        key[c] = getCharacterCode(key[c]);
    }

    // First attempt: direct match
    auto it = macroMap.find(key);
    if (it != macroMap.end()) {
        getMacroContentCode(it->second, macroContentCode);
        return true;
    }

    // Second attempt: auto-caps matching (only if enabled)
    if (!vAutoCapsMacro || key.empty()) {
        return false;
    }

    _macroFlag = false;

    // Try lowercase first character (for auto-caps first letter)
    if (key.size() > 0 && modifyCaseUnicode(key[0], false)) {
        // Also try lowercase remaining characters
        if (key.size() > 1 && modifyCaseUnicode(key[1], false)) {
            _macroFlag = true;
            for (c = 2; c < key.size(); c++) {
                modifyCaseUnicode(key[c], false);
            }
        }

        // Check again with lowercase
        it = macroMap.find(key);
        if (it != macroMap.end()) {
            getMacroContentCode(it->second, macroContentCode, true, _macroFlag);
            return true;
        }
    }

    return false;
}
