using System.Runtime.InteropServices;
using System.Text;

namespace PHTV.UI.Interop
{
    internal static class PhtvNative
    {
        private const string DllName = "PHTVCore.dll";

        // Core lifecycle
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_Init(string resourceDir);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_InstallHook();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_UninstallHook();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_LoadConfig();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SaveConfig();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_ResetConfig();

        // Setters
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetInputMethod(int type);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetLanguage(int lang);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetCodeTable(int table);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSpellCheck(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetModernOrthography(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickTelex(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAutoRestoreEnglishWord(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetMacro(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetMacroInEnglishMode(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAutoCapsMacro(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetFixRecommendBrowser(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSmartSwitchKey(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetUpperCaseFirstChar(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetUpperCaseExcludedForCurrentApp(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAllowConsonantZFWJ(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickStartConsonant(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickEndConsonant(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetFreeMark(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetRestoreOnEscape(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetCustomEscapeKey(int key);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetPauseKeyEnabled(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetPauseKey(int key);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSwitchKeyStatus(int status);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetOtherLanguage(int lang);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetRememberCode(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSendKeyStepByStep(bool enable);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetPerformLayoutCompat(bool enable);

        // Getters
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetInputMethod();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetLanguage();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetCodeTable();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetSpellCheck();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetModernOrthography();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickTelex();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAutoRestoreEnglishWord();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetMacro();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetMacroInEnglishMode();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAutoCapsMacro();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetFixRecommendBrowser();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetSmartSwitchKey();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetUpperCaseFirstChar();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetUpperCaseExcludedForCurrentApp();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAllowConsonantZFWJ();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickStartConsonant();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickEndConsonant();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetFreeMark();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetRestoreOnEscape();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetCustomEscapeKey();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetPauseKeyEnabled();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetPauseKey();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetSwitchKeyStatus();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetOtherLanguage();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetRememberCode();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetSendKeyStepByStep();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetPerformLayoutCompat();

        // Macro API
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroLoad(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroSave(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_MacroClear();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_MacroCount();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroGetAt(int index, StringBuilder key, int keyCap, StringBuilder value, int valueCap);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroAdd(string key, string value);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroDelete(string key);

        // App list API
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListLoad(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListSave(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_AppListClear();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_AppListCount();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListGetAt(int index, StringBuilder name, int nameCap, out int lang);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_AppListSet(string name, int lang);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListRemove(string name);

        // Uppercase excluded apps API
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedLoad(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedSave(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_UpperExcludedClear();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_UpperExcludedCount();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedGetAt(int index, StringBuilder name, int nameCap);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_UpperExcludedAdd(string name);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedRemove(string name);

        // Clipboard conversion
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_QuickConvertClipboard(int fromCode, int toCode);
    }
}
