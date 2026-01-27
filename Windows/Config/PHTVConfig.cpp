//
//  PHTVConfig.cpp
//  PHTV - Windows Configuration Manager implementation
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#include "PHTVConfig.h"
#include <windows.h>
#include <shlwapi.h> // For Path functions

// Link with shlwapi.lib
#pragma comment(lib, "shlwapi.lib")

// Define Global Variables
volatile int vInputType = 0;       
volatile int vLanguage = 1;        
volatile int vCodeTable = 0;
int vFreeMark = 1;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 1;
volatile int vQuickTelex = 1;
volatile int vRestoreIfWrongSpelling = 1;
volatile int vUseMacro = 0;

// Placeholder for other externs likely needed by Engine.cpp but not yet in Config.h
// Add these to prevent linker errors if Engine.cpp uses them
volatile int vFixRecommendBrowser = 0;
volatile int vUseMacroInEnglishMode = 0;
volatile int vAutoCapsMacro = 0;
volatile int vUseSmartSwitchKey = 0;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;
volatile int vTempOffSpelling = 0;
volatile int vAllowConsonantZFWJ = 1;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;
volatile int vRememberCode = 0;
volatile int vOtherLanguage = 0;
volatile int vTempOffPHTV = 0;
volatile int vRestoreOnEscape = 1;
volatile int vCustomEscapeKey = 0; // 0 means default ESC
volatile int vPauseKeyEnabled = 0;
volatile int vPauseKey = 0; // Default (e.g., VK_LMENU)
volatile int vAutoRestoreEnglishWord = 1;
volatile int vSwitchKeyStatus = 0; // For tracking modifier keys

PHTVConfig::PHTVConfig() {
    // Get path to executable
    wchar_t buffer[MAX_PATH];
    GetModuleFileNameW(NULL, buffer, MAX_PATH);
    PathRemoveFileSpecW(buffer);
    PathAppendW(buffer, L"PHTV.ini");
    configFilePath = buffer;
}

PHTVConfig& PHTVConfig::Shared() {
    static PHTVConfig instance;
    return instance;
}

void PHTVConfig::Load() {
    // Read Integer values from INI file
    vInputType = GetPrivateProfileIntW(L"Settings", L"InputType", 0, configFilePath.c_str());
    vLanguage = GetPrivateProfileIntW(L"Settings", L"Language", 1, configFilePath.c_str());
    vCodeTable = GetPrivateProfileIntW(L"Settings", L"CodeTable", 0, configFilePath.c_str());
    
    vCheckSpelling = GetPrivateProfileIntW(L"Features", L"CheckSpelling", 1, configFilePath.c_str());
    vUseModernOrthography = GetPrivateProfileIntW(L"Features", L"ModernOrthography", 1, configFilePath.c_str());
    vQuickTelex = GetPrivateProfileIntW(L"Features", L"QuickTelex", 1, configFilePath.c_str());
    vUseMacro = GetPrivateProfileIntW(L"Features", L"UseMacro", 0, configFilePath.c_str());
    vAutoRestoreEnglishWord = GetPrivateProfileIntW(L"Features", L"AutoRestoreEnglishWord", 1, configFilePath.c_str());
}

void PHTVConfig::Save() {
    // Write Integer values to INI file (converted to string)
    WritePrivateProfileStringW(L"Settings", L"InputType", std::to_wstring(vInputType).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Settings", L"Language", std::to_wstring(vLanguage).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Settings", L"CodeTable", std::to_wstring(vCodeTable).c_str(), configFilePath.c_str());
    
    WritePrivateProfileStringW(L"Features", L"CheckSpelling", std::to_wstring(vCheckSpelling).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Features", L"ModernOrthography", std::to_wstring(vUseModernOrthography).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Features", L"QuickTelex", std::to_wstring(vQuickTelex).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Features", L"UseMacro", std::to_wstring(vUseMacro).c_str(), configFilePath.c_str());
    WritePrivateProfileStringW(L"Features", L"AutoRestoreEnglishWord", std::to_wstring(vAutoRestoreEnglishWord).c_str(), configFilePath.c_str());
}

void PHTVConfig::ResetDefaults() {
    vInputType = 0;
    vLanguage = 1;
    vCodeTable = 0;
    vCheckSpelling = 1;
    vUseModernOrthography = 1;
    vQuickTelex = 1;
    vUseMacro = 0;
    Save();
}

std::wstring PHTVConfig::GetConfigPath() {
    return configFilePath;
}
