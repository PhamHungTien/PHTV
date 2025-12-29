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
#include <iostream>
#include <memory.h>
#include <fstream>
#include <mutex>
#include <ctime>
#include <sstream>
#include <iomanip>
#include <random>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#endif

using namespace std;

//main data
map<vector<Uint32>, MacroData> macroMap;

// Thread safety: protect macroMap access between main thread (AppDelegate) and event tap thread
static std::mutex macroMapMutex;

// Counter storage for SNIPPET_COUNTER type
static std::map<std::string, int> counterValues;
static std::mutex counterMutex;

// ============================================================================
// Snippet Helper Functions
// ============================================================================

// Format date/time using custom format string
// d=day, M=month, y=year, H=hour, m=minute, s=second
static string formatDateTime(const string& format, bool includeTime) {
    time_t now = time(nullptr);
    tm* ltm = localtime(&now);

    ostringstream oss;
    bool inEscape = false;
    char lastChar = 0;
    int repeatCount = 0;

    auto flushRepeat = [&]() {
        if (repeatCount == 0) return;
        switch (lastChar) {
            case 'd':
                if (repeatCount >= 2)
                    oss << setfill('0') << setw(2) << ltm->tm_mday;
                else
                    oss << ltm->tm_mday;
                break;
            case 'M':
                if (repeatCount >= 2)
                    oss << setfill('0') << setw(2) << (ltm->tm_mon + 1);
                else
                    oss << (ltm->tm_mon + 1);
                break;
            case 'y':
                if (repeatCount >= 4)
                    oss << (ltm->tm_year + 1900);
                else
                    oss << setfill('0') << setw(2) << ((ltm->tm_year + 1900) % 100);
                break;
            case 'H':
                if (repeatCount >= 2)
                    oss << setfill('0') << setw(2) << ltm->tm_hour;
                else
                    oss << ltm->tm_hour;
                break;
            case 'm':
                if (repeatCount >= 2)
                    oss << setfill('0') << setw(2) << ltm->tm_min;
                else
                    oss << ltm->tm_min;
                break;
            case 's':
                if (repeatCount >= 2)
                    oss << setfill('0') << setw(2) << ltm->tm_sec;
                else
                    oss << ltm->tm_sec;
                break;
            default:
                for (int i = 0; i < repeatCount; i++) oss << lastChar;
                break;
        }
        repeatCount = 0;
    };

    for (char c : format) {
        if (c == lastChar && (c == 'd' || c == 'M' || c == 'y' || c == 'H' || c == 'm' || c == 's')) {
            repeatCount++;
        } else {
            flushRepeat();
            lastChar = c;
            repeatCount = 1;
        }
    }
    flushRepeat();

    return oss.str();
}

static string getCurrentDate(const string& format) {
    if (format.empty()) {
        return formatDateTime("dd/MM/yyyy", false);
    }
    return formatDateTime(format, false);
}

static string getCurrentTime(const string& format) {
    if (format.empty()) {
        return formatDateTime("HH:mm:ss", true);
    }
    return formatDateTime(format, true);
}

static string getCurrentDateTime(const string& format) {
    if (format.empty()) {
        return formatDateTime("dd/MM/yyyy HH:mm", true);
    }
    return formatDateTime(format, true);
}

static string getRandomFromList(const string& listStr) {
    if (listStr.empty()) return "";

    vector<string> items;
    stringstream ss(listStr);
    string item;
    while (getline(ss, item, ',')) {
        // Trim whitespace
        size_t start = item.find_first_not_of(" \t");
        size_t end = item.find_last_not_of(" \t");
        if (start != string::npos && end != string::npos) {
            items.push_back(item.substr(start, end - start + 1));
        }
    }

    if (items.empty()) return listStr;

    // Random selection
    static random_device rd;
    static mt19937 gen(rd());
    uniform_int_distribution<> dis(0, (int)items.size() - 1);
    return items[dis(gen)];
}

static string getAndIncrementCounter(const string& prefix) {
    std::lock_guard<std::mutex> lock(counterMutex);
    int value = ++counterValues[prefix];
    return prefix + to_string(value);
}

// Reset counter for a specific prefix or all counters
extern "C" {
void resetSnippetCounter(const char* prefix) {
    std::lock_guard<std::mutex> lock(counterMutex);
    if (prefix && strlen(prefix) > 0) {
        counterValues.erase(prefix);
    } else {
        counterValues.clear();
    }
}
}

// Compute dynamic snippet content based on type
static string computeSnippet(int snippetType, const string& format) {
    switch (snippetType) {
        case SNIPPET_DATE:
            return getCurrentDate(format);
        case SNIPPET_TIME:
            return getCurrentTime(format);
        case SNIPPET_DATETIME:
            return getCurrentDateTime(format);
        case SNIPPET_CLIPBOARD:
            // Clipboard will be handled by Objective-C bridge
            return ""; // Placeholder, actual content set by AppDelegate
        case SNIPPET_RANDOM:
            return getRandomFromList(format);
        case SNIPPET_COUNTER:
            return getAndIncrementCounter(format);
        default:
            return format;
    }
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
    wstring data = utf8ToWideString(str);
    Uint32 t = 0;
    int kSign = -1;
    int k = 0;
    for (int i = 0; i < data.size(); i++) {
        t = (Uint32)data[i];
        
        //find normal character fist
        if (_characterMap.find(t) != _characterMap.end()) {
            outData.push_back(_characterMap[t]);
            continue;
        }
        
        //find character which has tone/mark
        for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[0].begin(); it != _codeTable[0].end(); ++it) {
            kSign = -1;
            k = 0;
            for (int j = 0; j < it->second.size(); j++) {
                if ((Uint16)t == it->second[j]) {
                    kSign = 0;
                    outData.push_back(_codeTable[vCodeTable][it->first][k] | CHAR_CODE_MASK);
                    break;
                }//end if
                k++;
            }
            if (kSign != -1)
                break;
        }
        if (kSign != -1)
            continue;
        
        //find other character
        outData.push_back(t | PURE_CHARACTER_MASK); //mark it as pure character
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

void getMacroSaveData(vector<Byte>& outData) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    Uint16 totalMacro = (Uint16)macroMap.size();
    outData.push_back((Byte)totalMacro);
    outData.push_back((Byte)(totalMacro>>8));
    
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        outData.push_back((Byte)it->second.macroText.size());
        for (int j = 0; j < it->second.macroText.size(); j++) {
            outData.push_back(it->second.macroText[j]);
        }
        
        Uint16 macroContentSize = (Uint16)it->second.macroContent.size();
        outData.push_back((Byte)macroContentSize);
        outData.push_back(macroContentSize>>8);
        for (int j = 0; j < macroContentSize; j++) {
            outData.push_back(it->second.macroContent[j]);
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

bool hasMacro(const string& macroName) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    vector<Uint32> key;
    convert(macroName, key);
    return (macroMap.find(key) != macroMap.end());
}

void getAllMacro(vector<vector<Uint32>>& keys, vector<string>& macroTexts, vector<string>& macroContents) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    keys.clear();
    macroTexts.clear();
    macroContents.clear();
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        keys.push_back(it->first);
        macroTexts.push_back(it->second.macroText);
        macroContents.push_back(it->second.macroContent);
    }
}

bool addMacro(const string& macroText, const string& macroContent) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    vector<Uint32> key;
    convert(macroText, key);
    if (macroMap.find(key) == macroMap.end()) { //add new macro
        MacroData data;
        data.macroText = macroText;
        data.macroContent = macroContent;
        convert(macroContent, data.macroContentCode);
        macroMap[key] = data;
    } else { //edit this macro
        macroMap[key].macroContent = macroContent;
        convert(macroContent, macroMap[key].macroContentCode);
    }
    return true;
}

bool deleteMacro(const string& macroText) {
    std::lock_guard<std::mutex> lock(macroMapMutex);
    vector<Uint32> key;
    convert(macroText, key);
    if (macroMap.find(key) != macroMap.end()) {
        macroMap.erase(key);
        return true;
    }
    return false;
}

void onTableCodeChange() {
    std::lock_guard<std::mutex> lock(macroMapMutex);

    // vCodeTable affects how both macro keys and macro contents are converted.
    // Rebuild the whole map to keep macros working immediately when the code table changes.
    std::map<std::vector<Uint32>, MacroData> rebuilt;

    for (auto &entry : macroMap) {
        MacroData data = entry.second;

        std::vector<Uint32> newKey;
        convert(data.macroText, newKey);
        convert(data.macroContent, data.macroContentCode);
        rebuilt[std::move(newKey)] = std::move(data);
    }

    macroMap.swap(rebuilt);
}

void saveToFile(const string& path) {
    ofstream myfile;
    myfile.open(path.c_str());
    myfile << ";Compatible PHTV Macro Data file for UniKey*** version=1 ***\n";
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        myfile <<it->second.macroText << ":" << it->second.macroContent<<"\n";
    }
    myfile.close();
}

void readFromFile(const string& path, const bool& append) {
    ifstream myfile(path.c_str());
    string line;
    int k = 0;
    size_t pos = 0;
    string name, content;
    if (myfile.is_open()) {
        if (!append) {
            macroMap.clear();
        }
        while (getline (myfile,line) ) {
            k++;
            if (k == 1) continue;
            pos = line.find(":");
            if (string::npos != pos) {
                name = line.substr(0, pos);
                content = line.substr(pos + 1, line.length() - pos - 1);
				while (name.compare("") == 0 && content.compare("") != 0) {
					pos = content.find(":");
					if (string::npos != pos) {
						name += ":";
						name += content.substr(0, pos);
						content = content.substr(pos + 1, line.length() - pos - 1);
					} else {
						break;
					}
				}

                if (name.compare("") != 0 && !hasMacro(name)) {
                    addMacro(name, content);
                }
            }
        }
        myfile.close();
    }
}
