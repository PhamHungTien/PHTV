using System;
using System.Collections.Generic;
using System.Linq;
using PHTV.Windows.ViewModels;

namespace PHTV.Windows.Models;

public sealed class SettingsSnapshot {
    public bool IsVietnameseEnabled { get; set; } = true;
    public string InputMethod { get; set; } = "Telex";
    public string CodeTable { get; set; } = "Unicode";
    public bool CheckSpelling { get; set; } = true;
    public bool UseModernOrthography { get; set; } = true;
    public bool UpperCaseFirstChar { get; set; }
    public bool AutoRestoreEnglishWord { get; set; } = true;
    public bool QuickTelex { get; set; }
    public bool AllowConsonantZFWJ { get; set; } = true;
    public bool QuickStartConsonant { get; set; }
    public bool QuickEndConsonant { get; set; }

    public string SwitchHotkey { get; set; } = "Ctrl + Shift";
    public bool RestoreOnEscape { get; set; } = true;
    public string RestoreKey { get; set; } = "ESC";
    public bool PauseKeyEnabled { get; set; }
    public string PauseKey { get; set; } = "Alt";
    public bool EmojiHotkeyEnabled { get; set; } = true;
    public string EmojiHotkey { get; set; } = "Ctrl + E";

    public bool UseMacro { get; set; } = true;
    public bool UseMacroInEnglishMode { get; set; } = true;
    public bool AutoCapsMacro { get; set; }

    public bool UseSmartSwitchKey { get; set; } = true;
    public bool RememberCode { get; set; } = true;
    public bool SendKeyStepByStep { get; set; }
    public bool PerformLayoutCompat { get; set; }
    public bool SafeMode { get; set; }

    public bool RunOnStartup { get; set; }
    public bool ShowSettingsOnStartup { get; set; }
    public bool SettingsWindowAlwaysOnTop { get; set; }
    public bool UseVietnameseMenubarIcon { get; set; } = true;
    public bool ShowIconOnDock { get; set; } = true;
    public string UpdateCheckFrequency { get; set; } = "Mỗi ngày";
    public bool AutoInstallUpdates { get; set; }
    public bool BetaChannelEnabled { get; set; }

    public string BugTitle { get; set; } = string.Empty;
    public string BugDescription { get; set; } = string.Empty;
    public string StepsToReproduce { get; set; } = string.Empty;
    public string ExpectedResult { get; set; } = string.Empty;
    public string ActualResult { get; set; } = string.Empty;
    public string ContactEmail { get; set; } = string.Empty;
    public string BugSeverity { get; set; } = "Bình thường";
    public string BugArea { get; set; } = "Gõ tiếng Việt";
    public bool IncludeSystemInfo { get; set; } = true;
    public bool IncludeLogs { get; set; }
    public bool IncludeCrashLogs { get; set; } = true;

    public List<MacroEntrySnapshot> Macros { get; set; } = new();
    public List<string> Categories { get; set; } = new();
    public List<string> ExcludedApps { get; set; } = new();
    public List<string> StepByStepApps { get; set; } = new();

    public static SettingsSnapshot FromState(SettingsState state) {
        return new SettingsSnapshot {
            IsVietnameseEnabled = state.IsVietnameseEnabled,
            InputMethod = state.InputMethod,
            CodeTable = state.CodeTable,
            CheckSpelling = state.CheckSpelling,
            UseModernOrthography = state.UseModernOrthography,
            UpperCaseFirstChar = state.UpperCaseFirstChar,
            AutoRestoreEnglishWord = state.AutoRestoreEnglishWord,
            QuickTelex = state.QuickTelex,
            AllowConsonantZFWJ = state.AllowConsonantZFWJ,
            QuickStartConsonant = state.QuickStartConsonant,
            QuickEndConsonant = state.QuickEndConsonant,

            SwitchHotkey = state.SwitchHotkey,
            RestoreOnEscape = state.RestoreOnEscape,
            RestoreKey = state.RestoreKey,
            PauseKeyEnabled = state.PauseKeyEnabled,
            PauseKey = state.PauseKey,
            EmojiHotkeyEnabled = state.EmojiHotkeyEnabled,
            EmojiHotkey = state.EmojiHotkey,

            UseMacro = state.UseMacro,
            UseMacroInEnglishMode = state.UseMacroInEnglishMode,
            AutoCapsMacro = state.AutoCapsMacro,

            UseSmartSwitchKey = state.UseSmartSwitchKey,
            RememberCode = state.RememberCode,
            SendKeyStepByStep = state.SendKeyStepByStep,
            PerformLayoutCompat = state.PerformLayoutCompat,
            SafeMode = state.SafeMode,

            RunOnStartup = state.RunOnStartup,
            ShowSettingsOnStartup = state.ShowSettingsOnStartup,
            SettingsWindowAlwaysOnTop = state.SettingsWindowAlwaysOnTop,
            UseVietnameseMenubarIcon = state.UseVietnameseMenubarIcon,
            ShowIconOnDock = state.ShowIconOnDock,
            UpdateCheckFrequency = state.UpdateCheckFrequency,
            AutoInstallUpdates = state.AutoInstallUpdates,
            BetaChannelEnabled = state.BetaChannelEnabled,

            BugTitle = state.BugTitle,
            BugDescription = state.BugDescription,
            StepsToReproduce = state.StepsToReproduce,
            ExpectedResult = state.ExpectedResult,
            ActualResult = state.ActualResult,
            ContactEmail = state.ContactEmail,
            BugSeverity = state.BugSeverity,
            BugArea = state.BugArea,
            IncludeSystemInfo = state.IncludeSystemInfo,
            IncludeLogs = state.IncludeLogs,
            IncludeCrashLogs = state.IncludeCrashLogs,

            Macros = state.Macros.Select(m => new MacroEntrySnapshot {
                Shortcut = m.Shortcut,
                Content = m.Content,
                Category = m.Category
            }).ToList(),
            Categories = state.Categories.ToList(),
            ExcludedApps = state.ExcludedApps.ToList(),
            StepByStepApps = state.StepByStepApps.ToList()
        };
    }

    public void ApplyTo(SettingsState state) {
        state.IsVietnameseEnabled = IsVietnameseEnabled;
        state.InputMethod = InputMethod;
        state.CodeTable = CodeTable;
        state.CheckSpelling = CheckSpelling;
        state.UseModernOrthography = UseModernOrthography;
        state.UpperCaseFirstChar = UpperCaseFirstChar;
        state.AutoRestoreEnglishWord = AutoRestoreEnglishWord;
        state.QuickTelex = QuickTelex;
        state.AllowConsonantZFWJ = AllowConsonantZFWJ;
        state.QuickStartConsonant = QuickStartConsonant;
        state.QuickEndConsonant = QuickEndConsonant;

        state.SwitchHotkey = SwitchHotkey;
        state.RestoreOnEscape = RestoreOnEscape;
        state.RestoreKey = RestoreKey;
        state.PauseKeyEnabled = PauseKeyEnabled;
        state.PauseKey = PauseKey;
        state.EmojiHotkeyEnabled = EmojiHotkeyEnabled;
        state.EmojiHotkey = EmojiHotkey;

        state.UseMacro = UseMacro;
        state.UseMacroInEnglishMode = UseMacroInEnglishMode;
        state.AutoCapsMacro = AutoCapsMacro;

        state.UseSmartSwitchKey = UseSmartSwitchKey;
        state.RememberCode = RememberCode;
        state.SendKeyStepByStep = SendKeyStepByStep;
        state.PerformLayoutCompat = PerformLayoutCompat;
        state.SafeMode = SafeMode;

        state.RunOnStartup = RunOnStartup;
        state.ShowSettingsOnStartup = ShowSettingsOnStartup;
        state.SettingsWindowAlwaysOnTop = SettingsWindowAlwaysOnTop;
        state.UseVietnameseMenubarIcon = UseVietnameseMenubarIcon;
        state.ShowIconOnDock = ShowIconOnDock;
        state.UpdateCheckFrequency = UpdateCheckFrequency;
        state.AutoInstallUpdates = AutoInstallUpdates;
        state.BetaChannelEnabled = BetaChannelEnabled;

        state.BugTitle = BugTitle;
        state.BugDescription = BugDescription;
        state.StepsToReproduce = StepsToReproduce;
        state.ExpectedResult = ExpectedResult;
        state.ActualResult = ActualResult;
        state.ContactEmail = ContactEmail;
        state.BugSeverity = BugSeverity;
        state.BugArea = BugArea;
        state.IncludeSystemInfo = IncludeSystemInfo;
        state.IncludeLogs = IncludeLogs;
        state.IncludeCrashLogs = IncludeCrashLogs;

        state.Macros.Clear();
        foreach (var macro in Macros) {
            state.Macros.Add(new MacroEntry(
                macro.Shortcut,
                macro.Content,
                string.IsNullOrWhiteSpace(macro.Category) ? "Chung" : macro.Category));
        }

        state.Categories.Clear();
        foreach (var category in Categories.Where(c => !string.IsNullOrWhiteSpace(c))) {
            state.Categories.Add(category.Trim());
        }
        if (state.Categories.Count == 0) {
            state.Categories.Add("Chung");
        }

        state.ExcludedApps.Clear();
        foreach (var app in ExcludedApps.Where(a => !string.IsNullOrWhiteSpace(a))) {
            state.ExcludedApps.Add(app.Trim());
        }

        state.StepByStepApps.Clear();
        foreach (var app in StepByStepApps.Where(a => !string.IsNullOrWhiteSpace(a))) {
            state.StepByStepApps.Add(app.Trim());
        }

        state.SelectedCategory = null;
        state.SelectedMacro = null;
        state.SelectedExcludedApp = null;
        state.SelectedStepByStepApp = null;
    }
}

public sealed class MacroEntrySnapshot {
    public string Shortcut { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string Category { get; set; } = "Chung";
}
