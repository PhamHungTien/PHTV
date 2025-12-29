//
//  Macro.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef Macro_h
#define Macro_h

#include <vector>
#include <map>
#include <string>
#include "DataType.h"

using namespace std;

// Snippet types for dynamic content
enum SnippetTypeEnum {
    SNIPPET_STATIC = 0,     // Fixed text (default)
    SNIPPET_DATE = 1,       // Current date
    SNIPPET_TIME = 2,       // Current time
    SNIPPET_DATETIME = 3,   // Date and time
    SNIPPET_CLIPBOARD = 4,  // Clipboard content
    SNIPPET_RANDOM = 5,     // Random from list
    SNIPPET_COUNTER = 6     // Auto-increment number
};

struct MacroData {
    string macroText; //ex: "ms"
    string macroContent; //ex: "millisecond" or format string for snippets
    vector<Uint32> macroContentCode; //converted of macroContent
    int snippetType; //0=static, 1=date, 2=time, etc.
};

/**
 * Call when you need to load macro data from disk
 */
extern "C" {
    void initMacroMap(const Byte* pData, const int& size);
}

/**
 * convert all macro data to save on disk
 */
void getMacroSaveData(vector<Byte>& outData);

/**
 * Use to find full text by macro
 */
bool findMacro(vector<Uint32>& key, vector<Uint32>& macroContentCode);

/**
 * check has this macro or not
 */
bool hasMacro(const string& macroName);

/**
 * Get all macro to show on macro table
 */
void getAllMacro(vector<vector<Uint32>>& keys, vector<string>& macroTexts, vector<string>& macroContents);

/**
 * add new macro to memory
 */
bool addMacro(const string& macroText, const string& macroContent);

/**
 * delete macro from memory
 */
bool deleteMacro(const string& macroText);

/**
 * When table code changed, we have to call this function to reload all macroContentCode
 */
void onTableCodeChange();

/**
 * Save all macro data to disk
 */
void saveToFile(const string& path);

/**
 * Load macro data from disk
 */
void readFromFile(const string& path, const bool& append=true);

#endif /* Macro_h */
