#pragma once

#ifdef PHTV_EXPORTS
#define PHTV_API __declspec(dllexport)
#else
#define PHTV_API __declspec(dllimport)
#endif

extern "C" {
    // Core Control
    PHTV_API void __cdecl PHTV_Init();
    PHTV_API void __cdecl PHTV_InstallHook();
    PHTV_API void __cdecl PHTV_UninstallHook();
    PHTV_API void __cdecl PHTV_LoadConfig();
    PHTV_API void __cdecl PHTV_SaveConfig();
    PHTV_API void __cdecl PHTV_ResetConfig();
    
    // Configuration Setters
    PHTV_API void __cdecl PHTV_SetInputMethod(int type); // 0: Telex, 1: VNI
    PHTV_API void __cdecl PHTV_SetLanguage(int lang);    // 0: Eng, 1: Vie
    PHTV_API void __cdecl PHTV_SetCodeTable(int table);
    PHTV_API void __cdecl PHTV_SetSpellCheck(bool enable);
    PHTV_API void __cdecl PHTV_SetModernOrthography(bool enable);
    PHTV_API void __cdecl PHTV_SetQuickTelex(bool enable);
    PHTV_API void __cdecl PHTV_SetAutoRestoreEnglishWord(bool enable);
    PHTV_API void __cdecl PHTV_SetMacro(bool enable);
    PHTV_API void __cdecl PHTV_SetMacroInEnglishMode(bool enable);
    PHTV_API void __cdecl PHTV_SetAutoCapsMacro(bool enable);
    PHTV_API void __cdecl PHTV_SetFixRecommendBrowser(bool enable);
    PHTV_API void __cdecl PHTV_SetSmartSwitchKey(bool enable);
    PHTV_API void __cdecl PHTV_SetUpperCaseFirstChar(bool enable);
    PHTV_API void __cdecl PHTV_SetUpperCaseExcludedForCurrentApp(bool enable);
    PHTV_API void __cdecl PHTV_SetAllowConsonantZFWJ(bool enable);
    PHTV_API void __cdecl PHTV_SetQuickStartConsonant(bool enable);
    PHTV_API void __cdecl PHTV_SetQuickEndConsonant(bool enable);
    PHTV_API void __cdecl PHTV_SetFreeMark(bool enable);
    PHTV_API void __cdecl PHTV_SetRestoreOnEscape(bool enable);
    PHTV_API void __cdecl PHTV_SetCustomEscapeKey(int key);
    PHTV_API void __cdecl PHTV_SetPauseKeyEnabled(bool enable);
    PHTV_API void __cdecl PHTV_SetPauseKey(int key);
    PHTV_API void __cdecl PHTV_SetSwitchKeyStatus(int status);
    PHTV_API void __cdecl PHTV_SetOtherLanguage(int lang);

    // Configuration Getters
    PHTV_API int __cdecl PHTV_GetInputMethod();
    PHTV_API int __cdecl PHTV_GetLanguage();
    PHTV_API int __cdecl PHTV_GetCodeTable();
    PHTV_API bool __cdecl PHTV_GetSpellCheck();
    PHTV_API bool __cdecl PHTV_GetModernOrthography();
    PHTV_API bool __cdecl PHTV_GetQuickTelex();
    PHTV_API bool __cdecl PHTV_GetAutoRestoreEnglishWord();
    PHTV_API bool __cdecl PHTV_GetMacro();
    PHTV_API bool __cdecl PHTV_GetMacroInEnglishMode();
    PHTV_API bool __cdecl PHTV_GetAutoCapsMacro();
    PHTV_API bool __cdecl PHTV_GetFixRecommendBrowser();
    PHTV_API bool __cdecl PHTV_GetSmartSwitchKey();
    PHTV_API bool __cdecl PHTV_GetUpperCaseFirstChar();
    PHTV_API bool __cdecl PHTV_GetUpperCaseExcludedForCurrentApp();
    PHTV_API bool __cdecl PHTV_GetAllowConsonantZFWJ();
    PHTV_API bool __cdecl PHTV_GetQuickStartConsonant();
    PHTV_API bool __cdecl PHTV_GetQuickEndConsonant();
    PHTV_API bool __cdecl PHTV_GetFreeMark();
    PHTV_API bool __cdecl PHTV_GetRestoreOnEscape();
    PHTV_API int __cdecl PHTV_GetCustomEscapeKey();
    PHTV_API bool __cdecl PHTV_GetPauseKeyEnabled();
    PHTV_API int __cdecl PHTV_GetPauseKey();
    PHTV_API int __cdecl PHTV_GetSwitchKeyStatus();
    PHTV_API int __cdecl PHTV_GetOtherLanguage();
    
    // Helper
    PHTV_API bool __cdecl PHTV_IsRunning();

    // Macro management
    PHTV_API bool __cdecl PHTV_MacroLoad(const wchar_t* path);
    PHTV_API bool __cdecl PHTV_MacroSave(const wchar_t* path);
    PHTV_API void __cdecl PHTV_MacroClear();
    PHTV_API int __cdecl PHTV_MacroCount();
    PHTV_API bool __cdecl PHTV_MacroGetAt(int index, wchar_t* outKey, int keyCap, wchar_t* outValue, int valueCap);
    PHTV_API bool __cdecl PHTV_MacroAdd(const wchar_t* key, const wchar_t* value);
    PHTV_API bool __cdecl PHTV_MacroDelete(const wchar_t* key);

    // App-specific input method mapping
    PHTV_API bool __cdecl PHTV_AppListLoad(const wchar_t* path);
    PHTV_API bool __cdecl PHTV_AppListSave(const wchar_t* path);
    PHTV_API void __cdecl PHTV_AppListClear();
    PHTV_API int __cdecl PHTV_AppListCount();
    PHTV_API bool __cdecl PHTV_AppListGetAt(int index, wchar_t* outName, int nameCap, int* outLang);
    PHTV_API void __cdecl PHTV_AppListSet(const wchar_t* name, int lang);
    PHTV_API bool __cdecl PHTV_AppListRemove(const wchar_t* name);
}
