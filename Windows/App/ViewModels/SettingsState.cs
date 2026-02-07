using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace PHTV.Windows.ViewModels;

public sealed class SettingsState : ObservableObject {
    private const string NoPrimaryHotkeyText = "Không";

    private static readonly IReadOnlyList<string> SwitchPrimaryOptionValues = new[] {
        NoPrimaryHotkeyText,
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "Space", "Tab", "Enter", "Return", "Esc", "Backspace",
        "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/"
    };

    private static readonly IReadOnlyList<string> EmojiPrimaryOptionValues = new[] {
        NoPrimaryHotkeyText,
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "Space", "Tab", "Enter", "Esc"
    };

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
    private bool _switchHotkeyControl = true;
    private bool _switchHotkeyOption;
    private bool _switchHotkeyCommand;
    private bool _switchHotkeyShift = true;
    private bool _switchHotkeyFn;
    private string _switchHotkeyPrimary = NoPrimaryHotkeyText;

    private bool _restoreOnEscape = true;
    private string _restoreKey = "ESC";
    private bool _pauseKeyEnabled;
    private string _pauseKey = "Alt";

    private bool _emojiHotkeyEnabled = true;
    private string _emojiHotkey = "Ctrl + E";
    private bool _emojiHotkeyControl = true;
    private bool _emojiHotkeyOption;
    private bool _emojiHotkeyCommand;
    private bool _emojiHotkeyShift;
    private bool _emojiHotkeyFn;
    private string _emojiHotkeyPrimary = "E";

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

    private bool _isSyncingSwitchHotkeyParts;
    private bool _isSyncingEmojiHotkeyParts;

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

        SyncSwitchHotkeyPartsFromText(_switchHotkey);
        SyncEmojiHotkeyPartsFromText(_emojiHotkey);
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

    public string SwitchHotkey {
        get => _switchHotkey;
        set {
            if (!SetProperty(ref _switchHotkey, value)) {
                return;
            }

            SyncSwitchHotkeyPartsFromText(value);
        }
    }

    public bool SwitchHotkeyControl {
        get => _switchHotkeyControl;
        set {
            if (SetProperty(ref _switchHotkeyControl, value)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public bool SwitchHotkeyOption {
        get => _switchHotkeyOption;
        set {
            if (SetProperty(ref _switchHotkeyOption, value)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public bool SwitchHotkeyCommand {
        get => _switchHotkeyCommand;
        set {
            if (SetProperty(ref _switchHotkeyCommand, value)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public bool SwitchHotkeyShift {
        get => _switchHotkeyShift;
        set {
            if (SetProperty(ref _switchHotkeyShift, value)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public bool SwitchHotkeyFn {
        get => _switchHotkeyFn;
        set {
            if (SetProperty(ref _switchHotkeyFn, value)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public string SwitchHotkeyPrimary {
        get => _switchHotkeyPrimary;
        set {
            var normalized = NormalizePrimarySelection(value, SwitchPrimaryOptionValues, NoPrimaryHotkeyText);
            if (SetProperty(ref _switchHotkeyPrimary, normalized)) {
                UpdateSwitchHotkeyFromParts();
            }
        }
    }

    public string SwitchHotkeyDisplay => BuildHotkeyDisplay(
        _switchHotkeyControl,
        _switchHotkeyOption,
        _switchHotkeyCommand,
        _switchHotkeyShift,
        _switchHotkeyFn,
        _switchHotkeyPrimary,
        SwitchPrimaryOptionValues);

    public bool RestoreOnEscape { get => _restoreOnEscape; set => SetProperty(ref _restoreOnEscape, value); }
    public string RestoreKey {
        get => _restoreKey;
        set {
            var normalized = NormalizeRestoreKey(value);
            if (!SetProperty(ref _restoreKey, normalized)) {
                return;
            }

            NotifyRestoreKeySelectionChanged();
        }
    }

    public bool RestoreKeyEscSelected {
        get => _restoreKey.Equals("ESC", StringComparison.OrdinalIgnoreCase);
        set => ApplyRestoreKeySelection(value, "ESC", nameof(RestoreKeyEscSelected));
    }

    public bool RestoreKeyOptionSelected {
        get => _restoreKey.Equals("Option", StringComparison.OrdinalIgnoreCase);
        set => ApplyRestoreKeySelection(value, "Option", nameof(RestoreKeyOptionSelected));
    }

    public bool RestoreKeyControlSelected {
        get => _restoreKey.Equals("Control", StringComparison.OrdinalIgnoreCase);
        set => ApplyRestoreKeySelection(value, "Control", nameof(RestoreKeyControlSelected));
    }

    public bool PauseKeyEnabled { get => _pauseKeyEnabled; set => SetProperty(ref _pauseKeyEnabled, value); }
    public string PauseKey {
        get => _pauseKey;
        set {
            var normalized = NormalizePauseKey(value);
            if (!SetProperty(ref _pauseKey, normalized)) {
                return;
            }

            NotifyPauseKeySelectionChanged();
        }
    }

    public bool PauseKeyAltSelected {
        get => _pauseKey.Equals("Alt", StringComparison.OrdinalIgnoreCase);
        set => ApplyPauseKeySelection(value, "Alt", nameof(PauseKeyAltSelected));
    }

    public bool PauseKeyControlSelected {
        get => _pauseKey.Equals("Control", StringComparison.OrdinalIgnoreCase);
        set => ApplyPauseKeySelection(value, "Control", nameof(PauseKeyControlSelected));
    }

    public bool PauseKeyShiftSelected {
        get => _pauseKey.Equals("Shift", StringComparison.OrdinalIgnoreCase);
        set => ApplyPauseKeySelection(value, "Shift", nameof(PauseKeyShiftSelected));
    }

    public bool EmojiHotkeyEnabled { get => _emojiHotkeyEnabled; set => SetProperty(ref _emojiHotkeyEnabled, value); }

    public string EmojiHotkey {
        get => _emojiHotkey;
        set {
            if (!SetProperty(ref _emojiHotkey, value)) {
                return;
            }

            SyncEmojiHotkeyPartsFromText(value);
        }
    }

    public bool EmojiHotkeyControl {
        get => _emojiHotkeyControl;
        set {
            if (SetProperty(ref _emojiHotkeyControl, value)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public bool EmojiHotkeyOption {
        get => _emojiHotkeyOption;
        set {
            if (SetProperty(ref _emojiHotkeyOption, value)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public bool EmojiHotkeyCommand {
        get => _emojiHotkeyCommand;
        set {
            if (SetProperty(ref _emojiHotkeyCommand, value)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public bool EmojiHotkeyShift {
        get => _emojiHotkeyShift;
        set {
            if (SetProperty(ref _emojiHotkeyShift, value)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public bool EmojiHotkeyFn {
        get => _emojiHotkeyFn;
        set {
            if (SetProperty(ref _emojiHotkeyFn, value)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public string EmojiHotkeyPrimary {
        get => _emojiHotkeyPrimary;
        set {
            var normalized = NormalizePrimarySelection(value, EmojiPrimaryOptionValues, "E");
            if (SetProperty(ref _emojiHotkeyPrimary, normalized)) {
                UpdateEmojiHotkeyFromParts();
            }
        }
    }

    public string EmojiHotkeyDisplay => BuildHotkeyDisplay(
        _emojiHotkeyControl,
        _emojiHotkeyOption,
        _emojiHotkeyCommand,
        _emojiHotkeyShift,
        _emojiHotkeyFn,
        _emojiHotkeyPrimary,
        EmojiPrimaryOptionValues);

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

    public IReadOnlyList<string> SwitchHotkeyPrimaryOptions { get; } = SwitchPrimaryOptionValues;

    public IReadOnlyList<string> RestoreKeyOptions { get; } = new[] {
        "ESC", "Option", "Control"
    };

    public IReadOnlyList<string> PauseKeyOptions { get; } = new[] {
        "Alt", "Control", "Shift"
    };

    public IReadOnlyList<string> EmojiHotkeyPrimaryOptions { get; } = EmojiPrimaryOptionValues;

    public IReadOnlyList<string> UpdateCheckFrequencyOptions { get; } = new[] {
        "Mỗi ngày", "Mỗi tuần", "Thủ công"
    };

    public IReadOnlyList<string> BugSeverityOptions { get; } = new[] {
        "Nhẹ", "Bình thường", "Nghiêm trọng", "Khẩn cấp"
    };

    public IReadOnlyList<string> BugAreaOptions { get; } = new[] {
        "Gõ tiếng Việt", "Hotkey", "Menu bar", "Cài đặt", "Macro", "Khác"
    };

    private void ApplyRestoreKeySelection(bool selected, string key, string propertyName) {
        if (selected) {
            RestoreKey = key;
            return;
        }

        if (_restoreKey.Equals(key, StringComparison.OrdinalIgnoreCase)) {
            // Keep one choice always selected (radio-like behavior with ToggleButton).
            RaisePropertyChanged(propertyName);
        }
    }

    private void ApplyPauseKeySelection(bool selected, string key, string propertyName) {
        if (selected) {
            PauseKey = key;
            return;
        }

        if (_pauseKey.Equals(key, StringComparison.OrdinalIgnoreCase)) {
            // Keep one choice always selected (radio-like behavior with ToggleButton).
            RaisePropertyChanged(propertyName);
        }
    }

    private void NotifyRestoreKeySelectionChanged() {
        RaisePropertyChanged(nameof(RestoreKeyEscSelected));
        RaisePropertyChanged(nameof(RestoreKeyOptionSelected));
        RaisePropertyChanged(nameof(RestoreKeyControlSelected));
    }

    private void NotifyPauseKeySelectionChanged() {
        RaisePropertyChanged(nameof(PauseKeyAltSelected));
        RaisePropertyChanged(nameof(PauseKeyControlSelected));
        RaisePropertyChanged(nameof(PauseKeyShiftSelected));
    }

    private void UpdateSwitchHotkeyFromParts() {
        if (_isSyncingSwitchHotkeyParts) {
            return;
        }

        EnsureSwitchHotkeyHasAtLeastOneModifier();
        var normalized = BuildHotkeyText(
            _switchHotkeyControl,
            _switchHotkeyOption,
            _switchHotkeyCommand,
            _switchHotkeyShift,
            _switchHotkeyFn,
            _switchHotkeyPrimary,
            SwitchPrimaryOptionValues);

        if (!string.Equals(_switchHotkey, normalized, StringComparison.Ordinal)) {
            _switchHotkey = normalized;
            RaisePropertyChanged(nameof(SwitchHotkey));
        }

        RaisePropertyChanged(nameof(SwitchHotkeyDisplay));
    }

    private void UpdateEmojiHotkeyFromParts() {
        if (_isSyncingEmojiHotkeyParts) {
            return;
        }

        EnsureEmojiHotkeyHasAtLeastOneModifier();
        var normalized = BuildHotkeyText(
            _emojiHotkeyControl,
            _emojiHotkeyOption,
            _emojiHotkeyCommand,
            _emojiHotkeyShift,
            _emojiHotkeyFn,
            _emojiHotkeyPrimary,
            EmojiPrimaryOptionValues);

        if (!string.Equals(_emojiHotkey, normalized, StringComparison.Ordinal)) {
            _emojiHotkey = normalized;
            RaisePropertyChanged(nameof(EmojiHotkey));
        }

        RaisePropertyChanged(nameof(EmojiHotkeyDisplay));
    }

    private void EnsureSwitchHotkeyHasAtLeastOneModifier() {
        if (_switchHotkeyControl || _switchHotkeyOption || _switchHotkeyCommand || _switchHotkeyShift || _switchHotkeyFn) {
            return;
        }

        _switchHotkeyControl = true;
        RaisePropertyChanged(nameof(SwitchHotkeyControl));
    }

    private void EnsureEmojiHotkeyHasAtLeastOneModifier() {
        if (_emojiHotkeyControl || _emojiHotkeyOption || _emojiHotkeyCommand || _emojiHotkeyShift || _emojiHotkeyFn) {
            return;
        }

        _emojiHotkeyControl = true;
        RaisePropertyChanged(nameof(EmojiHotkeyControl));
    }

    private void SyncSwitchHotkeyPartsFromText(string hotkeyText) {
        var parsed = ParseHotkeyParts(
            hotkeyText,
            fallback: new HotkeyParts {
                Control = true,
                Shift = true,
                Primary = NoPrimaryHotkeyText
            });
        var normalized = BuildHotkeyText(
            parsed.Control,
            parsed.Option,
            parsed.Command,
            parsed.Shift,
            parsed.Fn,
            parsed.Primary,
            SwitchPrimaryOptionValues);

        _isSyncingSwitchHotkeyParts = true;
        try {
            SetField(ref _switchHotkeyControl, parsed.Control, nameof(SwitchHotkeyControl));
            SetField(ref _switchHotkeyOption, parsed.Option, nameof(SwitchHotkeyOption));
            SetField(ref _switchHotkeyCommand, parsed.Command, nameof(SwitchHotkeyCommand));
            SetField(ref _switchHotkeyShift, parsed.Shift, nameof(SwitchHotkeyShift));
            SetField(ref _switchHotkeyFn, parsed.Fn, nameof(SwitchHotkeyFn));
            SetField(ref _switchHotkeyPrimary, NormalizePrimarySelection(parsed.Primary, SwitchPrimaryOptionValues, NoPrimaryHotkeyText), nameof(SwitchHotkeyPrimary));

            if (!string.Equals(_switchHotkey, normalized, StringComparison.Ordinal)) {
                _switchHotkey = normalized;
                RaisePropertyChanged(nameof(SwitchHotkey));
            }
        } finally {
            _isSyncingSwitchHotkeyParts = false;
        }

        RaisePropertyChanged(nameof(SwitchHotkeyDisplay));
    }

    private void SyncEmojiHotkeyPartsFromText(string hotkeyText) {
        var parsed = ParseHotkeyParts(
            hotkeyText,
            fallback: new HotkeyParts {
                Control = true,
                Primary = "E"
            });
        var normalized = BuildHotkeyText(
            parsed.Control,
            parsed.Option,
            parsed.Command,
            parsed.Shift,
            parsed.Fn,
            parsed.Primary,
            EmojiPrimaryOptionValues);

        _isSyncingEmojiHotkeyParts = true;
        try {
            SetField(ref _emojiHotkeyControl, parsed.Control, nameof(EmojiHotkeyControl));
            SetField(ref _emojiHotkeyOption, parsed.Option, nameof(EmojiHotkeyOption));
            SetField(ref _emojiHotkeyCommand, parsed.Command, nameof(EmojiHotkeyCommand));
            SetField(ref _emojiHotkeyShift, parsed.Shift, nameof(EmojiHotkeyShift));
            SetField(ref _emojiHotkeyFn, parsed.Fn, nameof(EmojiHotkeyFn));
            SetField(ref _emojiHotkeyPrimary, NormalizePrimarySelection(parsed.Primary, EmojiPrimaryOptionValues, "E"), nameof(EmojiHotkeyPrimary));

            if (!string.Equals(_emojiHotkey, normalized, StringComparison.Ordinal)) {
                _emojiHotkey = normalized;
                RaisePropertyChanged(nameof(EmojiHotkey));
            }
        } finally {
            _isSyncingEmojiHotkeyParts = false;
        }

        RaisePropertyChanged(nameof(EmojiHotkeyDisplay));
    }

    private void SetField(ref bool field, bool value, string propertyName) {
        if (field == value) {
            return;
        }

        field = value;
        RaisePropertyChanged(propertyName);
    }

    private void SetField(ref string field, string value, string propertyName) {
        if (string.Equals(field, value, StringComparison.Ordinal)) {
            return;
        }

        field = value;
        RaisePropertyChanged(propertyName);
    }

    private static string BuildHotkeyText(
        bool control,
        bool option,
        bool command,
        bool shift,
        bool fn,
        string primary,
        IReadOnlyList<string> options) {
        var parts = new List<string>(6);
        if (control) {
            parts.Add("Ctrl");
        }

        if (option) {
            parts.Add("Alt");
        }

        if (command) {
            parts.Add("Win");
        }

        if (shift) {
            parts.Add("Shift");
        }

        if (fn) {
            parts.Add("Fn");
        }

        var normalizedPrimary = NormalizePrimarySelection(primary, options, NoPrimaryHotkeyText);
        if (!IsNoPrimarySelection(normalizedPrimary)) {
            parts.Add(normalizedPrimary);
        }

        return string.Join(" + ", parts);
    }

    private static string BuildHotkeyDisplay(
        bool control,
        bool option,
        bool command,
        bool shift,
        bool fn,
        string primary,
        IReadOnlyList<string> options) {
        var text = BuildHotkeyText(control, option, command, shift, fn, primary, options);
        return string.IsNullOrWhiteSpace(text) ? "Chưa đặt" : text;
    }

    private static HotkeyParts ParseHotkeyParts(string hotkeyText, HotkeyParts fallback) {
        var parts = new HotkeyParts();
        var hasModifier = false;
        var hasPrimary = false;

        var tokens = string.IsNullOrWhiteSpace(hotkeyText)
            ? Array.Empty<string>()
            : hotkeyText.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);

        foreach (var token in tokens) {
            if (IsControlToken(token)) {
                parts.Control = true;
                hasModifier = true;
                continue;
            }

            if (IsOptionToken(token)) {
                parts.Option = true;
                hasModifier = true;
                continue;
            }

            if (IsCommandToken(token)) {
                parts.Command = true;
                hasModifier = true;
                continue;
            }

            if (IsShiftToken(token)) {
                parts.Shift = true;
                hasModifier = true;
                continue;
            }

            if (IsFnToken(token)) {
                parts.Fn = true;
                hasModifier = true;
                continue;
            }

            if (TryNormalizePrimaryToken(token, out var normalizedPrimary)) {
                parts.Primary = normalizedPrimary;
                hasPrimary = true;
                continue;
            }

            if (IsNoPrimarySelection(token)) {
                parts.Primary = NoPrimaryHotkeyText;
                hasPrimary = true;
            }
        }

        if (!hasModifier) {
            parts.Control = fallback.Control;
            parts.Option = fallback.Option;
            parts.Command = fallback.Command;
            parts.Shift = fallback.Shift;
            parts.Fn = fallback.Fn;
        }

        if (!hasPrimary) {
            parts.Primary = fallback.Primary;
        }

        return parts;
    }

    private static bool IsControlToken(string token) {
        return token.Equals("ctrl", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("control", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("⌃", StringComparison.Ordinal);
    }

    private static bool IsOptionToken(string token) {
        return token.Equals("alt", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("option", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("⌥", StringComparison.Ordinal);
    }

    private static bool IsCommandToken(string token) {
        return token.Equals("win", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("windows", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("cmd", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("command", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("⌘", StringComparison.Ordinal);
    }

    private static bool IsShiftToken(string token) {
        return token.Equals("shift", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("⇧", StringComparison.Ordinal);
    }

    private static bool IsFnToken(string token) {
        return token.Equals("fn", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("function", StringComparison.OrdinalIgnoreCase);
    }

    private static bool TryNormalizePrimaryToken(string token, out string normalizedPrimary) {
        normalizedPrimary = string.Empty;

        if (string.IsNullOrWhiteSpace(token)) {
            return false;
        }

        var value = token.Trim();
        if (value.Length == 1) {
            var ch = value[0];
            if (char.IsLetter(ch)) {
                normalizedPrimary = char.ToUpperInvariant(ch).ToString();
                return true;
            }

            if (char.IsDigit(ch) || IsSymbolPrimary(ch)) {
                normalizedPrimary = value;
                return true;
            }
        }

        if (value.Equals("space", StringComparison.OrdinalIgnoreCase) ||
            value.Equals("spacebar", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Space";
            return true;
        }

        if (value.Equals("tab", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Tab";
            return true;
        }

        if (value.Equals("enter", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Enter";
            return true;
        }

        if (value.Equals("return", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Return";
            return true;
        }

        if (value.Equals("esc", StringComparison.OrdinalIgnoreCase) ||
            value.Equals("escape", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Esc";
            return true;
        }

        if (value.Equals("delete", StringComparison.OrdinalIgnoreCase) ||
            value.Equals("backspace", StringComparison.OrdinalIgnoreCase)) {
            normalizedPrimary = "Backspace";
            return true;
        }

        return false;
    }

    private static bool IsSymbolPrimary(char ch) {
        return ch is '`' or '-' or '=' or '[' or ']' or '\\' or ';' or '\'' or ',' or '.' or '/';
    }

    private static string NormalizePrimarySelection(string value, IReadOnlyList<string> options, string fallback) {
        if (string.IsNullOrWhiteSpace(value)) {
            return fallback;
        }

        if (IsNoPrimarySelection(value) && ContainsOption(options, NoPrimaryHotkeyText)) {
            return NoPrimaryHotkeyText;
        }

        if (TryNormalizePrimaryToken(value, out var normalizedToken) && ContainsOption(options, normalizedToken)) {
            return normalizedToken;
        }

        foreach (var option in options) {
            if (option.Equals(value, StringComparison.OrdinalIgnoreCase)) {
                return option;
            }
        }

        return fallback;
    }

    private static bool ContainsOption(IReadOnlyList<string> options, string value) {
        foreach (var option in options) {
            if (option.Equals(value, StringComparison.Ordinal)) {
                return true;
            }
        }

        return false;
    }

    private static bool IsNoPrimarySelection(string value) {
        return value.Equals(NoPrimaryHotkeyText, StringComparison.OrdinalIgnoreCase) ||
               value.Equals("khong", StringComparison.OrdinalIgnoreCase) ||
               value.Equals("none", StringComparison.OrdinalIgnoreCase) ||
               value.Equals("no key", StringComparison.OrdinalIgnoreCase) ||
               value.Equals("modifier only", StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeRestoreKey(string value) {
        if (string.IsNullOrWhiteSpace(value)) {
            return "ESC";
        }

        var normalized = value.Trim();
        if (normalized.Equals("esc", StringComparison.OrdinalIgnoreCase) ||
            normalized.Equals("escape", StringComparison.OrdinalIgnoreCase)) {
            return "ESC";
        }

        if (normalized.Equals("option", StringComparison.OrdinalIgnoreCase) ||
            normalized.Equals("alt", StringComparison.OrdinalIgnoreCase)) {
            return "Option";
        }

        if (normalized.Equals("control", StringComparison.OrdinalIgnoreCase) ||
            normalized.Equals("ctrl", StringComparison.OrdinalIgnoreCase)) {
            return "Control";
        }

        return "ESC";
    }

    private static string NormalizePauseKey(string value) {
        if (string.IsNullOrWhiteSpace(value)) {
            return "Alt";
        }

        var normalized = value.Trim();
        if (normalized.Equals("alt", StringComparison.OrdinalIgnoreCase) ||
            normalized.Equals("option", StringComparison.OrdinalIgnoreCase)) {
            return "Alt";
        }

        if (normalized.Equals("control", StringComparison.OrdinalIgnoreCase) ||
            normalized.Equals("ctrl", StringComparison.OrdinalIgnoreCase)) {
            return "Control";
        }

        if (normalized.Equals("shift", StringComparison.OrdinalIgnoreCase)) {
            return "Shift";
        }

        return "Alt";
    }

    private struct HotkeyParts {
        public bool Control;
        public bool Option;
        public bool Command;
        public bool Shift;
        public bool Fn;
        public string Primary;
    }
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
