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
    
    // Configuration Setters
    PHTV_API void __cdecl PHTV_SetInputMethod(int type); // 0: Telex, 1: VNI
    PHTV_API void __cdecl PHTV_SetLanguage(int lang);    // 0: Eng, 1: Vie
    PHTV_API void __cdecl PHTV_SetSpellCheck(bool enable);
    PHTV_API void __cdecl PHTV_SetModernOrthography(bool enable);
    PHTV_API void __cdecl PHTV_SetMacro(bool enable);
    
    // Helper
    PHTV_API bool __cdecl PHTV_IsRunning();
}
