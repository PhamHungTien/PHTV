using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace PHTV.Windows.ViewModels;

public sealed class SettingsState : ObservableObject {
    private bool _isVietnameseEnabled = true;
    private string _inputMethod = "Telex";
    private string _codeTable = "Unicode";
    private bool _checkSpelling = true;
    private bool _useModernOrthography = true;
    private bool _upperCaseFirstChar;
    private bool _autoRestoreEnglishWord = true;
    private bool _quickTelex;
    private bool _allowConsonantZFWJ = true;
    private bool _quickStartConsonant;
    private bool _quickEndConsonant;

    private string _switchHotkey = "Ctrl + Shift";
    private bool _restoreOnEscape = true;
    private string _restoreKey = "ESC";
    private bool _pauseKeyEnabled;
    private string _pauseKey = "Alt";
    private bool _emojiHotkeyEnabled = true;
    private string _emojiHotkey = "Ctrl + E";

    private bool _useMacro = true;
    private bool _useMacroInEnglishMode = true;
    private bool _autoCapsMacro;

    private bool _useSmartSwitchKey = true;
    private bool _rememberCode = true;
    private bool _sendKeyStepByStep;
    private bool _performLayoutCompat;
    private bool _safeMode;

    private bool _runOnStartup;
    private bool _settingsWindowAlwaysOnTop;
    private bool _useVietnameseMenubarIcon = true;
    private double _menuBarIconSize = 16;
    private bool _showIconOnDock = true;
    private string _updateCheckFrequency = "Mỗi ngày";
    private bool _autoInstallUpdates;
    private bool _betaChannelEnabled;

    private string _bugTitle = string.Empty;
    private string _bugDescription = string.Empty;
    private string _stepsToReproduce = string.Empty;
    private string _expectedResult = string.Empty;
    private string _actualResult = string.Empty;
    private string _contactEmail = string.Empty;
    private string _bugSeverity = "Bình thường";
    private string _bugArea = "Gõ tiếng Việt";
    private bool _includeSystemInfo = true;
    private bool _includeLogs;
    private bool _includeCrashLogs = true;

    private string? _selectedCategory;
    private MacroEntry? _selectedMacro;
    private string? _selectedExcludedApp;
    private string? _selectedStepByStepApp;

    public SettingsState() {
        Macros = new ObservableCollection<MacroEntry> {
            new("btw", "by the way", "Chung"),
            new("addr", "123 Main Street", "Công việc"),
            new("sig", "Trân trọng,\nPHTV Team", "Email")
        };

        Categories = new ObservableCollection<string> {
            "Chung", "Công việc", "Email"
        };

        ExcludedApps = new ObservableCollection<string> {
            "Adobe Photoshop", "Final Cut Pro"
        };

        StepByStepApps = new ObservableCollection<string> {
            "Remote Desktop", "Legacy ERP"
        };
    }

    public bool IsVietnameseEnabled { get => _isVietnameseEnabled; set => SetProperty(ref _isVietnameseEnabled, value); }
    public string InputMethod { get => _inputMethod; set => SetProperty(ref _inputMethod, value); }
    public string CodeTable { get => _codeTable; set => SetProperty(ref _codeTable, value); }
    public bool CheckSpelling { get => _checkSpelling; set => SetProperty(ref _checkSpelling, value); }
    public bool UseModernOrthography { get => _useModernOrthography; set => SetProperty(ref _useModernOrthography, value); }
    public bool UpperCaseFirstChar { get => _upperCaseFirstChar; set => SetProperty(ref _upperCaseFirstChar, value); }
    public bool AutoRestoreEnglishWord { get => _autoRestoreEnglishWord; set => SetProperty(ref _autoRestoreEnglishWord, value); }
    public bool QuickTelex { get => _quickTelex; set => SetProperty(ref _quickTelex, value); }
    public bool AllowConsonantZFWJ { get => _allowConsonantZFWJ; set => SetProperty(ref _allowConsonantZFWJ, value); }
    public bool QuickStartConsonant { get => _quickStartConsonant; set => SetProperty(ref _quickStartConsonant, value); }
    public bool QuickEndConsonant { get => _quickEndConsonant; set => SetProperty(ref _quickEndConsonant, value); }

    public string SwitchHotkey { get => _switchHotkey; set => SetProperty(ref _switchHotkey, value); }
    public bool RestoreOnEscape { get => _restoreOnEscape; set => SetProperty(ref _restoreOnEscape, value); }
    public string RestoreKey { get => _restoreKey; set => SetProperty(ref _restoreKey, value); }
    public bool PauseKeyEnabled { get => _pauseKeyEnabled; set => SetProperty(ref _pauseKeyEnabled, value); }
    public string PauseKey { get => _pauseKey; set => SetProperty(ref _pauseKey, value); }
    public bool EmojiHotkeyEnabled { get => _emojiHotkeyEnabled; set => SetProperty(ref _emojiHotkeyEnabled, value); }
    public string EmojiHotkey { get => _emojiHotkey; set => SetProperty(ref _emojiHotkey, value); }

    public bool UseMacro { get => _useMacro; set => SetProperty(ref _useMacro, value); }
    public bool UseMacroInEnglishMode { get => _useMacroInEnglishMode; set => SetProperty(ref _useMacroInEnglishMode, value); }
    public bool AutoCapsMacro { get => _autoCapsMacro; set => SetProperty(ref _autoCapsMacro, value); }

    public bool UseSmartSwitchKey { get => _useSmartSwitchKey; set => SetProperty(ref _useSmartSwitchKey, value); }
    public bool RememberCode { get => _rememberCode; set => SetProperty(ref _rememberCode, value); }
    public bool SendKeyStepByStep { get => _sendKeyStepByStep; set => SetProperty(ref _sendKeyStepByStep, value); }
    public bool PerformLayoutCompat { get => _performLayoutCompat; set => SetProperty(ref _performLayoutCompat, value); }
    public bool SafeMode { get => _safeMode; set => SetProperty(ref _safeMode, value); }

    public bool RunOnStartup { get => _runOnStartup; set => SetProperty(ref _runOnStartup, value); }
    public bool SettingsWindowAlwaysOnTop { get => _settingsWindowAlwaysOnTop; set => SetProperty(ref _settingsWindowAlwaysOnTop, value); }
    public bool UseVietnameseMenubarIcon { get => _useVietnameseMenubarIcon; set => SetProperty(ref _useVietnameseMenubarIcon, value); }
    public double MenuBarIconSize { get => _menuBarIconSize; set => SetProperty(ref _menuBarIconSize, value); }
    public bool ShowIconOnDock { get => _showIconOnDock; set => SetProperty(ref _showIconOnDock, value); }
    public string UpdateCheckFrequency { get => _updateCheckFrequency; set => SetProperty(ref _updateCheckFrequency, value); }
    public bool AutoInstallUpdates { get => _autoInstallUpdates; set => SetProperty(ref _autoInstallUpdates, value); }
    public bool BetaChannelEnabled { get => _betaChannelEnabled; set => SetProperty(ref _betaChannelEnabled, value); }

    public string BugTitle { get => _bugTitle; set => SetProperty(ref _bugTitle, value); }
    public string BugDescription { get => _bugDescription; set => SetProperty(ref _bugDescription, value); }
    public string StepsToReproduce { get => _stepsToReproduce; set => SetProperty(ref _stepsToReproduce, value); }
    public string ExpectedResult { get => _expectedResult; set => SetProperty(ref _expectedResult, value); }
    public string ActualResult { get => _actualResult; set => SetProperty(ref _actualResult, value); }
    public string ContactEmail { get => _contactEmail; set => SetProperty(ref _contactEmail, value); }
    public string BugSeverity { get => _bugSeverity; set => SetProperty(ref _bugSeverity, value); }
    public string BugArea { get => _bugArea; set => SetProperty(ref _bugArea, value); }
    public bool IncludeSystemInfo { get => _includeSystemInfo; set => SetProperty(ref _includeSystemInfo, value); }
    public bool IncludeLogs { get => _includeLogs; set => SetProperty(ref _includeLogs, value); }
    public bool IncludeCrashLogs { get => _includeCrashLogs; set => SetProperty(ref _includeCrashLogs, value); }

    public string? SelectedCategory { get => _selectedCategory; set => SetProperty(ref _selectedCategory, value); }
    public MacroEntry? SelectedMacro { get => _selectedMacro; set => SetProperty(ref _selectedMacro, value); }
    public string? SelectedExcludedApp { get => _selectedExcludedApp; set => SetProperty(ref _selectedExcludedApp, value); }
    public string? SelectedStepByStepApp { get => _selectedStepByStepApp; set => SetProperty(ref _selectedStepByStepApp, value); }

    public ObservableCollection<MacroEntry> Macros { get; }
    public ObservableCollection<string> Categories { get; }
    public ObservableCollection<string> ExcludedApps { get; }
    public ObservableCollection<string> StepByStepApps { get; }

    public IReadOnlyList<string> InputMethodOptions { get; } = new[] {
        "Telex", "VNI", "Simple Telex 1", "Simple Telex 2"
    };

    public IReadOnlyList<string> CodeTableOptions { get; } = new[] {
        "Unicode", "TCVN3", "VNI Windows", "Unicode Compound"
    };

    public IReadOnlyList<string> RestoreKeyOptions { get; } = new[] {
        "ESC", "Option", "Control"
    };

    public IReadOnlyList<string> PauseKeyOptions { get; } = new[] {
        "Alt", "Control", "Shift"
    };

    public IReadOnlyList<string> UpdateCheckFrequencyOptions { get; } = new[] {
        "Mỗi ngày", "Mỗi tuần", "Thủ công"
    };

    public IReadOnlyList<string> BugSeverityOptions { get; } = new[] {
        "Nhẹ", "Bình thường", "Nghiêm trọng", "Khẩn cấp"
    };

    public IReadOnlyList<string> BugAreaOptions { get; } = new[] {
        "Gõ tiếng Việt", "Hotkey", "Menu bar", "Cài đặt", "Macro", "Khác"
    };
}

public sealed class MacroEntry : ObservableObject {
    private string _shortcut;
    private string _content;
    private string _category;

    public MacroEntry(string shortcut, string content, string category) {
        _shortcut = shortcut;
        _content = content;
        _category = category;
    }

    public string Shortcut { get => _shortcut; set => SetProperty(ref _shortcut, value); }
    public string Content { get => _content; set => SetProperty(ref _content, value); }
    public string Category { get => _category; set => SetProperty(ref _category, value); }
}
