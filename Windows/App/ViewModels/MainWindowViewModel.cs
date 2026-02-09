using Avalonia.Controls;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using PHTV.Windows.Dialogs;
using PHTV.Windows.Models;
using PHTV.Windows.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Input;

namespace PHTV.Windows.ViewModels;

public sealed class MainWindowViewModel : ObservableObject {
    private static readonly JsonSerializerOptions JsonOptions = new() {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };
    private static readonly HashSet<string> TransientStatePropertyNames = new(StringComparer.Ordinal) {
        nameof(SettingsState.SelectedCategory),
        nameof(SettingsState.SelectedMacro),
        nameof(SettingsState.SelectedExcludedApp),
        nameof(SettingsState.SelectedStepByStepApp),
        nameof(SettingsState.SwitchHotkeyDisplay),
        nameof(SettingsState.EmojiHotkeyDisplay),
        nameof(SettingsState.RestoreKeyEscSelected),
        nameof(SettingsState.RestoreKeyOptionSelected),
        nameof(SettingsState.RestoreKeyControlSelected),
        nameof(SettingsState.PauseKeyAltSelected),
        nameof(SettingsState.PauseKeyControlSelected),
        nameof(SettingsState.PauseKeyShiftSelected),
        nameof(SettingsState.SwitchHotkeyControl),
        nameof(SettingsState.SwitchHotkeyOption),
        nameof(SettingsState.SwitchHotkeyCommand),
        nameof(SettingsState.SwitchHotkeyShift),
        nameof(SettingsState.SwitchHotkeyFn),
        nameof(SettingsState.SwitchHotkeyPrimary),
        nameof(SettingsState.EmojiHotkeyControl),
        nameof(SettingsState.EmojiHotkeyOption),
        nameof(SettingsState.EmojiHotkeyCommand),
        nameof(SettingsState.EmojiHotkeyShift),
        nameof(SettingsState.EmojiHotkeyFn),
        nameof(SettingsState.EmojiHotkeyPrimary)
    };
    private static readonly HashSet<string> RuntimeSyncPropertyNames = new(StringComparer.Ordinal) {
        nameof(SettingsState.IsVietnameseEnabled),
        nameof(SettingsState.InputMethod),
        nameof(SettingsState.CodeTable),
        nameof(SettingsState.CheckSpelling),
        nameof(SettingsState.UseModernOrthography),
        nameof(SettingsState.UpperCaseFirstChar),
        nameof(SettingsState.AutoRestoreEnglishWord),
        nameof(SettingsState.QuickTelex),
        nameof(SettingsState.AllowConsonantZFWJ),
        nameof(SettingsState.QuickStartConsonant),
        nameof(SettingsState.QuickEndConsonant),
        nameof(SettingsState.SwitchHotkey),
        nameof(SettingsState.RestoreOnEscape),
        nameof(SettingsState.RestoreKey),
        nameof(SettingsState.PauseKeyEnabled),
        nameof(SettingsState.PauseKey),
        nameof(SettingsState.EmojiHotkeyEnabled),
        nameof(SettingsState.EmojiHotkey),
        nameof(SettingsState.UseMacro),
        nameof(SettingsState.UseMacroInEnglishMode),
        nameof(SettingsState.AutoCapsMacro),
        nameof(SettingsState.UseSmartSwitchKey),
        nameof(SettingsState.RememberCode),
        nameof(SettingsState.SendKeyStepByStep),
        nameof(SettingsState.PerformLayoutCompat)
    };
    private static readonly HashSet<string> HotkeyRestartPropertyNames = new(StringComparer.Ordinal) {
        nameof(SettingsState.SwitchHotkey),
        nameof(SettingsState.EmojiHotkey),
        nameof(SettingsState.EmojiHotkeyEnabled),
    };
    private static readonly HashSet<string> ImmediatePersistPropertyNames = new(StringComparer.Ordinal) {
        nameof(SettingsState.SwitchHotkey),
        nameof(SettingsState.RestoreOnEscape),
        nameof(SettingsState.RestoreKey),
        nameof(SettingsState.PauseKeyEnabled),
        nameof(SettingsState.PauseKey),
        nameof(SettingsState.EmojiHotkeyEnabled),
        nameof(SettingsState.EmojiHotkey),
        nameof(SettingsState.ShowSettingsOnStartup),
        nameof(SettingsState.RunOnStartup)
    };

    private readonly List<SidebarTabEntry> _allTabs;
    private readonly Dictionary<SettingsTabId, SettingsTabViewModel> _tabViewModels;
    private readonly SettingsPersistenceService _settingsPersistenceService;
    private readonly WindowsStartupService _startupService;
    private readonly BugReportService _bugReportService;
    private readonly RuntimeBridgeService _runtimeBridgeService;
    private readonly DispatcherTimer _saveDebounceTimer;
    private readonly DispatcherTimer _hotkeyRestartDebounceTimer;
    private readonly DispatcherTimer _daemonStatusTimer;

    private readonly AsyncRelayCommand _addCategoryCommand;
    private readonly AsyncRelayCommand _editCategoryCommand;
    private readonly AsyncRelayCommand _addMacroCommand;
    private readonly AsyncRelayCommand _editMacroCommand;
    private readonly RelayCommand _deleteMacroCommand;
    private readonly AsyncRelayCommand _exportMacrosCommand;
    private readonly AsyncRelayCommand _importMacrosCommand;

    private readonly RelayCommand<object> _addExcludedAppCommand;
    private readonly RelayCommand _removeExcludedAppCommand;
    private readonly RelayCommand<object> _addStepByStepAppCommand;
    private readonly RelayCommand _removeStepByStepAppCommand;

    private readonly RelayCommand _checkForUpdatesCommand;
    private readonly RelayCommand _openGuideCommand;
    private readonly AsyncRelayCommand _exportSettingsCommand;
    private readonly AsyncRelayCommand _importSettingsCommand;
    private readonly AsyncRelayCommand _resetSettingsCommand;

    private readonly AsyncRelayCommand _copyBugReportCommand;
    private readonly AsyncRelayCommand _saveBugReportCommand;
    private readonly RelayCommand _openGithubIssueCommand;
    private readonly RelayCommand _sendEmailCommand;
    private readonly RelayCommand _openRuntimeFolderCommand;

    private string _searchText = string.Empty;
    private SettingsTabId _selectedTabId = SettingsTabId.Typing;
    private SettingsTabViewModel _currentTab;
    private string _statusMessage = "Sẵn sàng";
    private bool _isApplyingSnapshot;
    private bool _isSyncingStartup;
    private bool _isInputDaemonRunning;
    private string _inputDaemonStatus = "Đang kiểm tra runtime daemon...";
    private bool _initialized;
    private DateTime _lastDaemonAutoRecoveryAttemptUtc = DateTime.MinValue;
    private Window? _window;

    public MainWindowViewModel() {
        _settingsPersistenceService = new SettingsPersistenceService();
        _startupService = new WindowsStartupService();
        _bugReportService = new BugReportService();
        _runtimeBridgeService = new RuntimeBridgeService();

        State = new SettingsState();

        // App commands must be created before _tabViewModels so that
        // AppsTabViewModel can expose them directly (MenuFlyout popups
        // render in a detached visual tree and cannot reach Window via
        // RelativeSource).
        _addExcludedAppCommand = new RelayCommand<object>(async p => await AddExcludedAppAsync(p));
        _removeExcludedAppCommand = new RelayCommand(RemoveExcludedApp, () => !string.IsNullOrWhiteSpace(State.SelectedExcludedApp));
        _addStepByStepAppCommand = new RelayCommand<object>(async p => await AddStepByStepAppAsync(p));
        _removeStepByStepAppCommand = new RelayCommand(RemoveStepByStepApp, () => !string.IsNullOrWhiteSpace(State.SelectedStepByStepApp));

        _tabViewModels = new Dictionary<SettingsTabId, SettingsTabViewModel> {
            { SettingsTabId.Typing, new TypingTabViewModel(State) },
            { SettingsTabId.Hotkeys, new HotkeysTabViewModel(State) },
            { SettingsTabId.Macro, new MacroTabViewModel(State) },
            { SettingsTabId.Apps, new AppsTabViewModel(State, _addExcludedAppCommand, _removeExcludedAppCommand, _addStepByStepAppCommand, _removeStepByStepAppCommand) },
            { SettingsTabId.System, new SystemTabViewModel(State) },
            { SettingsTabId.BugReport, new BugReportTabViewModel(State) },
            { SettingsTabId.About, new AboutTabViewModel(State) }
        };

        _allTabs = new List<SidebarTabEntry> {
            new(SettingsTabId.Typing, "Bộ gõ", "⌨", "Nhập liệu", 
                "telex", "vni", "simple", "chính tả", "spell", "bảng mã", "unicode", "tcvn3", "vni windows", "hiện đại", "viết hoa", "phụ âm", "zfwj"),
            new(SettingsTabId.Hotkeys, "Phím tắt", "", "Nhập liệu", 
                "hotkey", "shortcut", "tạm dừng", "pause", "khôi phục", "restore", "chuyển chế độ", "esc", "alt", "ctrl", "win", "fn", "picker", "emoji"),
            new(SettingsTabId.Macro, "Gõ tắt", "✎", "Nhập liệu", 
                "macro", "snippet", "danh mục", "category", "viết hoa macro", "auto caps", "xuất", "nhập", "export", "import"),
            new(SettingsTabId.Apps, "Ứng dụng", "▦", "Nhập liệu", 
                "apps", "loại trừ", "exclude", "tương thích", "compatibility", "layout", "dvorak", "colemak", "gửi từng phím", "step by step", "thanh địa chỉ", "browser", "chrome", "edge"),
            new(SettingsTabId.System, "Hệ thống", "⚙", "Hệ thống", 
                "startup", "khởi động cùng windows", "cập nhật", "update", "beta", "sao lưu", "backup", "reset", "mặc định", "topmost", "luôn hiện", "menubar", "khay hệ thống", "tray"),
            new(SettingsTabId.BugReport, "Báo lỗi", "⚠", "Hỗ trợ", 
                "bug", "report", "lỗi", "nhật ký", "logs", "crash", "hệ thống", "system info", "github", "email"),
            new(SettingsTabId.About, "Thông tin", "ⓘ", "Hỗ trợ", 
                "about", "phiên bản", "version", "tác giả", "phạm hùng tiến", "donate", "ủng hộ", "website", "github source")
        };

        SidebarEntries = new ObservableCollection<SidebarEntry>();

        SelectTabCommand = new RelayCommand<SettingsTabId>(OnSelectTab);

        _addCategoryCommand = new AsyncRelayCommand(AddCategoryAsync);
        _editCategoryCommand = new AsyncRelayCommand(EditCategoryAsync, () => !string.IsNullOrWhiteSpace(State.SelectedCategory));
        _addMacroCommand = new AsyncRelayCommand(AddMacroAsync);
        _editMacroCommand = new AsyncRelayCommand(EditMacroAsync, () => State.SelectedMacro is not null);
        _deleteMacroCommand = new RelayCommand(DeleteMacro, () => State.SelectedMacro is not null);
        _exportMacrosCommand = new AsyncRelayCommand(ExportMacrosAsync, () => State.Macros.Count > 0);
        _importMacrosCommand = new AsyncRelayCommand(ImportMacrosAsync);

        _checkForUpdatesCommand = new RelayCommand(CheckForUpdates);
        _openGuideCommand = new RelayCommand(OpenGuide);
        _exportSettingsCommand = new AsyncRelayCommand(ExportSettingsAsync);
        _importSettingsCommand = new AsyncRelayCommand(ImportSettingsAsync);
        _resetSettingsCommand = new AsyncRelayCommand(ResetSettingsAsync);

        _copyBugReportCommand = new AsyncRelayCommand(CopyBugReportAsync);
        _saveBugReportCommand = new AsyncRelayCommand(SaveBugReportAsync);
        _openGithubIssueCommand = new RelayCommand(OpenGithubIssue);
        _sendEmailCommand = new RelayCommand(SendEmail);
        _openRuntimeFolderCommand = new RelayCommand(OpenRuntimeFolder);

        OpenWebsiteCommand = new RelayCommand(() => OpenUrl("https://phamhungtien.com/PHTV/"));
        OpenGitHubCommand = new RelayCommand(() => OpenUrl("https://github.com/PhamHungTien/PHTV"));
        OpenDonateCommand = new RelayCommand(() => OpenUrl("https://phamhungtien.com/PHTV/#donate"));

        AddCategoryCommand = _addCategoryCommand;
        EditCategoryCommand = _editCategoryCommand;
        AddMacroCommand = _addMacroCommand;
        EditMacroCommand = _editMacroCommand;
        DeleteMacroCommand = _deleteMacroCommand;
        ExportMacrosCommand = _exportMacrosCommand;
        ImportMacrosCommand = _importMacrosCommand;

        AddExcludedAppCommand = _addExcludedAppCommand;
        RemoveExcludedAppCommand = _removeExcludedAppCommand;
        AddStepByStepAppCommand = _addStepByStepAppCommand;
        RemoveStepByStepAppCommand = _removeStepByStepAppCommand;

        CheckForUpdatesCommand = _checkForUpdatesCommand;
        OpenGuideCommand = _openGuideCommand;
        ExportSettingsCommand = _exportSettingsCommand;
        ImportSettingsCommand = _importSettingsCommand;
        ResetSettingsCommand = _resetSettingsCommand;

        CopyBugReportCommand = _copyBugReportCommand;
        SaveBugReportCommand = _saveBugReportCommand;
        OpenGithubIssueCommand = _openGithubIssueCommand;
        SendEmailCommand = _sendEmailCommand;
        OpenRuntimeFolderCommand = _openRuntimeFolderCommand;


        _saveDebounceTimer = new DispatcherTimer {
            Interval = TimeSpan.FromMilliseconds(420)
        };
        _saveDebounceTimer.Tick += (_, _) => {
            _saveDebounceTimer.Stop();
            PersistStateNow();
        };
        _hotkeyRestartDebounceTimer = new DispatcherTimer {
            Interval = TimeSpan.FromMilliseconds(800)
        };
        _hotkeyRestartDebounceTimer.Tick += (_, _) => {
            _hotkeyRestartDebounceTimer.Stop();
            RestartDaemonForHotkeyChange();
        };
        _daemonStatusTimer = new DispatcherTimer {
            Interval = TimeSpan.FromSeconds(2)
        };
        _daemonStatusTimer.Tick += (_, _) => {
            RefreshInputDaemonStatus();
            AutoRecoverInputDaemon();
            SyncLanguageStateFromRuntime();
        };

        _currentTab = _tabViewModels[_selectedTabId];
        RebuildSidebar();
        MarkSelectedTab();

        RefreshCommandStates();
    }

    public SettingsState State { get; }
    public ObservableCollection<SidebarEntry> SidebarEntries { get; }
    public ICommand SelectTabCommand { get; }

    public ICommand AddCategoryCommand { get; }
    public ICommand EditCategoryCommand { get; }
    public ICommand AddMacroCommand { get; }
    public ICommand EditMacroCommand { get; }
    public ICommand DeleteMacroCommand { get; }
    public ICommand ExportMacrosCommand { get; }
    public ICommand ImportMacrosCommand { get; }

    public ICommand AddExcludedAppCommand { get; }
    public ICommand RemoveExcludedAppCommand { get; }
    public ICommand AddStepByStepAppCommand { get; }
    public ICommand RemoveStepByStepAppCommand { get; }

    public ICommand CheckForUpdatesCommand { get; }
    public ICommand OpenGuideCommand { get; }
    public ICommand ExportSettingsCommand { get; }
    public ICommand ImportSettingsCommand { get; }
    public ICommand ResetSettingsCommand { get; }

    public ICommand CopyBugReportCommand { get; }
    public ICommand SaveBugReportCommand { get; }
    public ICommand OpenGithubIssueCommand { get; }
    public ICommand SendEmailCommand { get; }
    public ICommand OpenRuntimeFolderCommand { get; }

    public ICommand OpenWebsiteCommand { get; }
    public ICommand OpenGitHubCommand { get; }
    public ICommand OpenDonateCommand { get; }

    public string SearchText {
        get => _searchText;
        set {
            if (SetProperty(ref _searchText, value)) {
                RebuildSidebar();
            }
        }
    }

    public SettingsTabId SelectedTabId {
        get => _selectedTabId;
        private set {
            if (SetProperty(ref _selectedTabId, value)) {
                CurrentTab = _tabViewModels[value];
                MarkSelectedTab();
            }
        }
    }

    public SettingsTabViewModel CurrentTab {
        get => _currentTab;
        private set => SetProperty(ref _currentTab, value);
    }

    public string StatusMessage {
        get => _statusMessage;
        private set => SetProperty(ref _statusMessage, value);
    }

    public bool IsInputDaemonRunning {
        get => _isInputDaemonRunning;
        private set => SetProperty(ref _isInputDaemonRunning, value);
    }

    public string InputDaemonStatus {
        get => _inputDaemonStatus;
        private set => SetProperty(ref _inputDaemonStatus, value);
    }

    public void AttachWindow(Window window) {
        _window = window;
        ApplyWindowTopmost();
        ApplyWindowShowInTaskbar();
    }

    public void InitializeAfterWindowReady() {
        if (_initialized) {
            return;
        }

        _initialized = true;
        LoadInitialSettings();
        HookStateEvents();
        ApplyWindowTopmost();
        ApplyWindowShowInTaskbar();
        RefreshCommandStates();
        InitializeRuntimeBridge();
        _daemonStatusTimer.Start();
    }

    public void ToggleVietnameseEnabled() {
        SetVietnameseEnabled(!State.IsVietnameseEnabled);
    }

    public bool TryStopDaemon() {
        if (!_runtimeBridgeService.IsSupported) return true;
        var result = _runtimeBridgeService.TryStopDaemon(out _);
        RefreshInputDaemonStatus();
        return result;
    }

    public void SetVietnameseEnabled(bool enabled) {
        if (State.IsVietnameseEnabled == enabled) {
            return;
        }

        State.IsVietnameseEnabled = enabled;
        PersistStateNow();

        if (_runtimeBridgeService.IsSupported) {
            if (!_runtimeBridgeService.TryRestartDaemon(out var daemonMessage)) {
                RefreshInputDaemonStatus();
                StatusMessage = $"Đã chuyển sang {(enabled ? "Tiếng Việt" : "Tiếng Anh")} nhưng không thể áp dụng runtime: {daemonMessage}";
                return;
            }

            RefreshInputDaemonStatus();
        }

        StatusMessage = enabled ? "Đã chuyển sang Tiếng Việt." : "Đã chuyển sang Tiếng Anh.";
    }

    public void SetInputMethodOption(string inputMethod) {
        if (string.IsNullOrWhiteSpace(inputMethod)) {
            return;
        }

        if (!State.InputMethodOptions.Contains(inputMethod)) {
            return;
        }

        if (string.Equals(State.InputMethod, inputMethod, StringComparison.Ordinal)) {
            return;
        }

        State.InputMethod = inputMethod;
        StatusMessage = $"Đã chuyển phương pháp gõ: {inputMethod}.";
        PersistStateNow();
    }

    public void SetCodeTableOption(string codeTable) {
        if (string.IsNullOrWhiteSpace(codeTable)) {
            return;
        }

        if (!State.CodeTableOptions.Contains(codeTable)) {
            return;
        }

        if (string.Equals(State.CodeTable, codeTable, StringComparison.Ordinal)) {
            return;
        }

        State.CodeTable = codeTable;
        StatusMessage = $"Đã chuyển bảng mã: {codeTable}.";
        PersistStateNow();
    }

    public void SetCheckSpellingEnabled(bool enabled) {
        if (State.CheckSpelling == enabled) {
            return;
        }

        State.CheckSpelling = enabled;
        StatusMessage = enabled ? "Đã bật kiểm tra chính tả." : "Đã tắt kiểm tra chính tả.";
    }

    public void SetUseMacroEnabled(bool enabled) {
        if (State.UseMacro == enabled) {
            return;
        }

        State.UseMacro = enabled;
        StatusMessage = enabled ? "Đã bật gõ tắt." : "Đã tắt gõ tắt.";
    }

    public void SetQuickTelexEnabled(bool enabled) {
        if (State.QuickTelex == enabled) {
            return;
        }

        State.QuickTelex = enabled;
        StatusMessage = enabled ? "Đã bật Quick Telex." : "Đã tắt Quick Telex.";
    }

    public void SetRunOnStartupEnabled(bool enabled) {
        if (State.RunOnStartup == enabled) {
            return;
        }

        State.RunOnStartup = enabled;
    }

    public void ShowTab(SettingsTabId tabId) {
        SelectedTabId = tabId;
    }

    public void OpenLatestReleasePage() {
        CheckForUpdates();
    }

    public void OpenGuidePage() {
        OpenGuide();
    }

    private void OnSelectTab(SettingsTabId tabId) {
        SelectedTabId = tabId;
    }

    private void RebuildSidebar() {
        SidebarEntries.Clear();

        IEnumerable<SidebarTabEntry> tabs = _allTabs;
        if (!string.IsNullOrWhiteSpace(SearchText)) {
            tabs = tabs.Where(t =>
                t.Title.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                t.Keywords.Any(k => k.Contains(SearchText, StringComparison.OrdinalIgnoreCase)));
        }

        var grouped = tabs
            .GroupBy(t => t.Section)
            .OrderBy(g => GetSectionOrder(g.Key));

        foreach (var group in grouped) {
            SidebarEntries.Add(new SidebarSectionEntry(group.Key));
            foreach (var tab in group) {
                SidebarEntries.Add(tab);
            }
        }

        MarkSelectedTab();
    }

    private void MarkSelectedTab() {
        foreach (var entry in _allTabs) {
            entry.IsSelected = entry.TabId == SelectedTabId;
        }

        RaisePropertyChanged(nameof(SidebarEntries));
    }

    private static int GetSectionOrder(string section) {
        return section switch {
            "Nhập liệu" => 0,
            "Hệ thống" => 1,
            "Hỗ trợ" => 2,
            _ => 99
        };
    }

    private void LoadInitialSettings() {
        _isApplyingSnapshot = true;
        try {
            var snapshot = _settingsPersistenceService.Load();
            snapshot?.ApplyTo(State);

            if (_startupService.IsSupported) {
                var isStartupEnabled = _startupService.IsEnabled();
                State.RunOnStartup = isStartupEnabled;

                // Normalize legacy startup entries so future launches can detect startup activation reliably.
                if (isStartupEnabled) {
                    _startupService.TrySetEnabled(true, out _);
                }
            }
        } catch (Exception ex) {
            StatusMessage = $"Không tải được cấu hình: {ex.Message}";
        } finally {
            _isApplyingSnapshot = false;
        }
    }

    private void HookStateEvents() {
        State.PropertyChanged += OnStatePropertyChanged;
        State.Macros.CollectionChanged += OnMacrosCollectionChanged;
        State.Categories.CollectionChanged += OnSimpleCollectionChanged;
        State.ExcludedApps.CollectionChanged += OnSimpleCollectionChanged;
        State.StepByStepApps.CollectionChanged += OnSimpleCollectionChanged;

        foreach (var macro in State.Macros) {
            macro.PropertyChanged += OnMacroItemPropertyChanged;
        }
    }

    private void OnStatePropertyChanged(object? sender, PropertyChangedEventArgs e) {
        var propertyName = e.PropertyName ?? string.Empty;

        if (propertyName.Length == 0) {
            return;
        }

        if (propertyName is nameof(SettingsState.SelectedCategory)
            or nameof(SettingsState.SelectedMacro)
            or nameof(SettingsState.SelectedExcludedApp)
            or nameof(SettingsState.SelectedStepByStepApp)) {
            RefreshCommandStates();
            return;
        }

        if (TransientStatePropertyNames.Contains(propertyName)) {
            return;
        }

        if (propertyName == nameof(SettingsState.SettingsWindowAlwaysOnTop)) {
            ApplyWindowTopmost();
        }

        if (propertyName == nameof(SettingsState.ShowIconOnDock)) {
            ApplyWindowShowInTaskbar();
        }

        if (propertyName == nameof(SettingsState.RunOnStartup)) {
            SyncRunOnStartupSetting();
        }

        if (RuntimeSyncPropertyNames.Contains(propertyName)) {
            TrySyncRuntimeArtifactsImmediately();
        }

        if (HotkeyRestartPropertyNames.Contains(propertyName)) {
            ScheduleHotkeyDaemonRestart();
        }

        if (ImmediatePersistPropertyNames.Contains(propertyName)) {
            PersistStateNow();
            return;
        }

        ScheduleSave();
    }

    private void OnSimpleCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e) {
        if (!string.IsNullOrWhiteSpace(State.SelectedCategory) &&
            !State.Categories.Contains(State.SelectedCategory)) {
            State.SelectedCategory = null;
        }

        if (!string.IsNullOrWhiteSpace(State.SelectedExcludedApp) &&
            !State.ExcludedApps.Contains(State.SelectedExcludedApp)) {
            State.SelectedExcludedApp = null;
        }

        if (!string.IsNullOrWhiteSpace(State.SelectedStepByStepApp) &&
            !State.StepByStepApps.Contains(State.SelectedStepByStepApp)) {
            State.SelectedStepByStepApp = null;
        }

        RefreshCommandStates();

        if (ReferenceEquals(sender, State.ExcludedApps) || ReferenceEquals(sender, State.StepByStepApps)) {
            TrySyncRuntimeArtifactsImmediately();
        }

        ScheduleSave();
    }

    private void OnMacrosCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e) {
        if (e.OldItems is not null) {
            foreach (var item in e.OldItems.OfType<MacroEntry>()) {
                item.PropertyChanged -= OnMacroItemPropertyChanged;
            }
        }

        if (e.NewItems is not null) {
            foreach (var item in e.NewItems.OfType<MacroEntry>()) {
                item.PropertyChanged += OnMacroItemPropertyChanged;
            }
        }

        if (State.SelectedMacro is not null && !State.Macros.Contains(State.SelectedMacro)) {
            State.SelectedMacro = null;
        }

        RefreshCommandStates();
        TrySyncRuntimeArtifactsImmediately();
        ScheduleSave();
    }

    private void OnMacroItemPropertyChanged(object? sender, PropertyChangedEventArgs e) {
        TrySyncRuntimeArtifactsImmediately();
        ScheduleSave();
    }

    private void RefreshCommandStates() {
        _editCategoryCommand.RaiseCanExecuteChanged();
        _editMacroCommand.RaiseCanExecuteChanged();
        _deleteMacroCommand.RaiseCanExecuteChanged();
        _exportMacrosCommand.RaiseCanExecuteChanged();
        _removeExcludedAppCommand.RaiseCanExecuteChanged();
        _removeStepByStepAppCommand.RaiseCanExecuteChanged();
    }

    private void ScheduleSave() {
        if (_isApplyingSnapshot) {
            return;
        }

        _saveDebounceTimer.Stop();
        _saveDebounceTimer.Start();
    }

    private void PersistStateNow() {
        if (_isApplyingSnapshot) {
            return;
        }

        _saveDebounceTimer.Stop();

        try {
            var snapshot = SettingsSnapshot.FromState(State);
            _settingsPersistenceService.Save(snapshot);
            SyncRuntimeArtifacts();
            StatusMessage = $"Đã lưu cấu hình lúc {DateTime.Now:HH:mm:ss}";
        } catch (Exception ex) {
            StatusMessage = $"Không lưu được cấu hình: {ex.Message}";
        }
    }

    private void ApplyWindowTopmost() {
        if (_window is not null) {
            _window.Topmost = State.SettingsWindowAlwaysOnTop;
        }
    }

    private void ApplyWindowShowInTaskbar() {
        if (_window is not null) {
            _window.ShowInTaskbar = State.ShowIconOnDock;
        }
    }

    private void SyncRunOnStartupSetting() {
        if (_isApplyingSnapshot || _isSyncingStartup || !_startupService.IsSupported) {
            return;
        }

        _isSyncingStartup = true;
        try {
            if (!_startupService.TrySetEnabled(State.RunOnStartup, out var error)) {
                StatusMessage = $"Không cập nhật startup: {error}";
                State.RunOnStartup = _startupService.IsEnabled();
                return;
            }

            StatusMessage = State.RunOnStartup
                ? "Đã bật khởi động cùng Windows."
                : "Đã tắt khởi động cùng Windows.";
        } finally {
            _isSyncingStartup = false;
        }
    }

    private void InitializeRuntimeBridge() {
        try {
            SyncRuntimeArtifacts();
        } catch (Exception ex) {
            InputDaemonStatus = $"Không đồng bộ runtime config: {ex.Message}";
            return;
        }

        if (!_runtimeBridgeService.IsSupported) {
            RefreshInputDaemonStatus();
            return;
        }

        // Always restart once on app startup to avoid stale daemon binaries/process state.
        if (_runtimeBridgeService.TryRestartDaemon(out var restartMessage)) {
            RefreshInputDaemonStatus();
            StatusMessage = restartMessage;
            return;
        }

        // Fallback to start-only path when restart cannot recover.
        if (_runtimeBridgeService.TryStartDaemon(out var startMessage)) {
            RefreshInputDaemonStatus();
            StatusMessage = startMessage;
            return;
        }

        RefreshInputDaemonStatus();
        InputDaemonStatus = $"Hook daemon chưa chạy: {startMessage}";
    }

    private void SyncRuntimeArtifacts() {
        _runtimeBridgeService.WriteRuntimeArtifacts(State);
    }

    private void ScheduleHotkeyDaemonRestart() {
        if (_isApplyingSnapshot || !_runtimeBridgeService.IsSupported) {
            return;
        }

        _hotkeyRestartDebounceTimer.Stop();
        _hotkeyRestartDebounceTimer.Start();
    }

    private void RestartDaemonForHotkeyChange() {
        if (!_runtimeBridgeService.IsSupported) {
            return;
        }

        try {
            SyncRuntimeArtifacts();

            if (_runtimeBridgeService.TryRestartDaemon(out var message)) {
                RefreshInputDaemonStatus();
                StatusMessage = $"Đã cập nhật phím tắt: {message}";
            } else {
                RefreshInputDaemonStatus();
                StatusMessage = $"Không khởi động lại daemon sau khi đổi phím tắt: {message}";
            }
        } catch (Exception ex) {
            StatusMessage = $"Lỗi khi đồng bộ phím tắt: {ex.Message}";
        }
    }

    private void TrySyncRuntimeArtifactsImmediately() {
        if (_isApplyingSnapshot) {
            return;
        }

        try {
            SyncRuntimeArtifacts();
        } catch (Exception ex) {
            InputDaemonStatus = $"Không đồng bộ runtime config: {ex.Message}";
        }
    }

    private void RefreshInputDaemonStatus() {
        if (!_runtimeBridgeService.IsSupported) {
            IsInputDaemonRunning = false;
            InputDaemonStatus = "Runtime daemon chỉ khả dụng trên Windows.";
            return;
        }

        var isRunning = _runtimeBridgeService.IsDaemonRunning();
        IsInputDaemonRunning = isRunning;

        if (isRunning) {
            InputDaemonStatus = "Hook daemon: Đang chạy.";
            return;
        }

        var daemonPath = _runtimeBridgeService.ResolveDaemonPath();
        InputDaemonStatus = string.IsNullOrWhiteSpace(daemonPath)
            ? "Hook daemon: Chưa chạy (không tìm thấy executable)."
            : $"Hook daemon: Chưa chạy (sẵn sàng tại {daemonPath}).";
    }

    private void SyncLanguageStateFromRuntime() {
        if (!_runtimeBridgeService.IsSupported) {
            return;
        }

        if (!_runtimeBridgeService.TryReadRuntimeLanguage(out var runtimeVietnameseEnabled)) {
            return;
        }

        if (State.IsVietnameseEnabled == runtimeVietnameseEnabled) {
            return;
        }

        State.IsVietnameseEnabled = runtimeVietnameseEnabled;
    }

    private void AutoRecoverInputDaemon() {
        if (!_runtimeBridgeService.IsSupported || IsInputDaemonRunning) {
            return;
        }

        var nowUtc = DateTime.UtcNow;
        if ((nowUtc - _lastDaemonAutoRecoveryAttemptUtc) < TimeSpan.FromSeconds(5)) {
            return;
        }

        _lastDaemonAutoRecoveryAttemptUtc = nowUtc;
        if (_runtimeBridgeService.TryStartDaemon(out var message)) {
            RefreshInputDaemonStatus();
            StatusMessage = $"Daemon tự khôi phục: {message}";
        }
    }

    private void OpenRuntimeFolder() {
        try {
            Directory.CreateDirectory(_runtimeBridgeService.RuntimeDirectory);
            Process.Start(new ProcessStartInfo {
                FileName = _runtimeBridgeService.RuntimeDirectory,
                UseShellExecute = true
            });
        } catch (Exception ex) {
            StatusMessage = $"Không mở được thư mục runtime: {ex.Message}";
        }
    }

    private async Task AddCategoryAsync() {
        var owner = GetOwnerWindow();
        if (owner is null) {
            return;
        }

        var name = await TextPromptWindow.ShowAsync(
            owner,
            "Thêm danh mục",
            "Nhập tên danh mục mới",
            watermark: "Ví dụ: Công việc");
        if (string.IsNullOrWhiteSpace(name)) {
            return;
        }

        var normalized = name.Trim();
        if (State.Categories.Any(c => string.Equals(c, normalized, StringComparison.OrdinalIgnoreCase))) {
            StatusMessage = "Danh mục đã tồn tại.";
            return;
        }

        State.Categories.Add(normalized);
        State.SelectedCategory = normalized;
        StatusMessage = $"Đã thêm danh mục '{normalized}'.";
    }

    private async Task EditCategoryAsync() {
        var owner = GetOwnerWindow();
        var selected = State.SelectedCategory;
        if (owner is null || string.IsNullOrWhiteSpace(selected)) {
            return;
        }

        var updated = await TextPromptWindow.ShowAsync(
            owner,
            "Sửa danh mục",
            "Cập nhật tên danh mục",
            initialValue: selected,
            watermark: "Tên mới");
        if (string.IsNullOrWhiteSpace(updated)) {
            return;
        }

        var newName = updated.Trim();
        if (string.Equals(newName, selected, StringComparison.Ordinal)) {
            return;
        }

        if (State.Categories.Any(c => !string.Equals(c, selected, StringComparison.OrdinalIgnoreCase) &&
                                      string.Equals(c, newName, StringComparison.OrdinalIgnoreCase))) {
            StatusMessage = "Tên danh mục bị trùng.";
            return;
        }

        var index = State.Categories.IndexOf(selected);
        if (index >= 0) {
            State.Categories[index] = newName;
        }

        foreach (var macro in State.Macros.Where(m => string.Equals(m.Category, selected, StringComparison.OrdinalIgnoreCase))) {
            macro.Category = newName;
        }

        State.SelectedCategory = newName;
        StatusMessage = $"Đã đổi danh mục thành '{newName}'.";
    }

    private async Task AddMacroAsync() {
        var owner = GetOwnerWindow();
        if (owner is null) {
            return;
        }

        var shortcut = await TextPromptWindow.ShowAsync(
            owner,
            "Thêm gõ tắt",
            "Nhập từ viết tắt (shortcut)",
            watermark: "Ví dụ: btw");
        if (string.IsNullOrWhiteSpace(shortcut)) {
            return;
        }

        var content = await TextPromptWindow.ShowAsync(
            owner,
            "Nội dung mở rộng",
            "Nhập nội dung sẽ được chèn",
            watermark: "Ví dụ: by the way",
            isMultiline: true);
        if (string.IsNullOrWhiteSpace(content)) {
            return;
        }

        var defaultCategory = State.SelectedCategory ?? State.Categories.FirstOrDefault() ?? "Chung";
        var category = await TextPromptWindow.ShowAsync(
            owner,
            "Danh mục",
            "Nhập danh mục cho macro",
            initialValue: defaultCategory,
            watermark: "Ví dụ: Email");
        if (string.IsNullOrWhiteSpace(category)) {
            category = "Chung";
        }

        var normalizedCategory = category.Trim();
        if (!State.Categories.Any(c => string.Equals(c, normalizedCategory, StringComparison.OrdinalIgnoreCase))) {
            State.Categories.Add(normalizedCategory);
        }

        var normalizedShortcut = shortcut.Trim();
        var existing = State.Macros.FirstOrDefault(m =>
            string.Equals(m.Shortcut, normalizedShortcut, StringComparison.OrdinalIgnoreCase));
        if (existing is not null) {
            existing.Content = content;
            existing.Category = normalizedCategory;
            State.SelectedMacro = existing;
            StatusMessage = $"Shortcut '{normalizedShortcut}' đã tồn tại, đã cập nhật nội dung.";
            return;
        }

        var macro = new MacroEntry(normalizedShortcut, content, normalizedCategory);
        State.Macros.Add(macro);
        State.SelectedMacro = macro;
        State.SelectedCategory = normalizedCategory;
        StatusMessage = $"Đã thêm gõ tắt '{normalizedShortcut}'.";
    }

    private async Task EditMacroAsync() {
        var owner = GetOwnerWindow();
        var selected = State.SelectedMacro;
        if (owner is null || selected is null) {
            return;
        }

        var shortcut = await TextPromptWindow.ShowAsync(
            owner,
            "Sửa shortcut",
            "Cập nhật từ viết tắt",
            initialValue: selected.Shortcut,
            watermark: "Shortcut");
        if (string.IsNullOrWhiteSpace(shortcut)) {
            return;
        }

        var content = await TextPromptWindow.ShowAsync(
            owner,
            "Sửa nội dung",
            "Cập nhật nội dung mở rộng",
            initialValue: selected.Content,
            watermark: "Nội dung",
            isMultiline: true);
        if (string.IsNullOrWhiteSpace(content)) {
            return;
        }

        var category = await TextPromptWindow.ShowAsync(
            owner,
            "Sửa danh mục",
            "Cập nhật danh mục macro",
            initialValue: selected.Category,
            watermark: "Danh mục");
        if (string.IsNullOrWhiteSpace(category)) {
            category = selected.Category;
        }

        var normalizedCategory = category.Trim();
        if (!State.Categories.Any(c => string.Equals(c, normalizedCategory, StringComparison.OrdinalIgnoreCase))) {
            State.Categories.Add(normalizedCategory);
        }

        selected.Shortcut = shortcut.Trim();
        selected.Content = content;
        selected.Category = normalizedCategory;
        State.SelectedCategory = normalizedCategory;
        StatusMessage = "Đã cập nhật macro.";
    }

    private void DeleteMacro() {
        var selected = State.SelectedMacro;
        if (selected is null) {
            return;
        }

        State.Macros.Remove(selected);
        StatusMessage = "Đã xóa macro.";
    }

    private async Task ExportMacrosAsync() {
        var export = new MacroExportFile {
            Version = "1.0",
            ExportDate = DateTimeOffset.Now.ToString("o"),
            Categories = State.Categories.ToList(),
            Macros = State.Macros.Select(m => new MacroExportItem {
                Shortcut = m.Shortcut,
                Expansion = m.Content,
                Content = m.Content,
                Category = m.Category
            }).ToList()
        };

        var json = JsonSerializer.Serialize(export, JsonOptions);
        var file = await PickSaveFileAsync(
            "Xuất danh sách macro",
            $"phtv-macros-{DateTime.Now:yyyyMMdd-HHmmss}.json",
            "json",
            "JSON");

        if (file is not null) {
            await WriteTextToStorageFileAsync(file, json);
            StatusMessage = "Đã xuất danh sách macro.";
            return;
        }

        var fallback = _settingsPersistenceService.BuildDefaultExportPath("phtv-macros");
        await File.WriteAllTextAsync(fallback, json);
        StatusMessage = $"Đã xuất macro tại: {fallback}";
    }

    private async Task ImportMacrosAsync() {
        var file = await PickOpenFileAsync("Nhập danh sách macro", "json", "JSON");
        if (file is null) {
            return;
        }

        var payload = await ReadTextFromStorageFileAsync(file);
        if (string.IsNullOrWhiteSpace(payload)) {
            StatusMessage = "File macro rỗng.";
            return;
        }

        var imported = ParseImportedMacros(payload);
        if (imported.Count == 0) {
            StatusMessage = "Không tìm thấy macro hợp lệ trong file.";
            return;
        }

        var mergedCategories = new HashSet<string>(State.Categories, StringComparer.OrdinalIgnoreCase);
        foreach (var macro in imported) {
            mergedCategories.Add(macro.Category);
        }

        var mergedByShortcut = State.Macros
            .ToDictionary(m => m.Shortcut, m => m, StringComparer.OrdinalIgnoreCase);
        foreach (var incoming in imported) {
            mergedByShortcut[incoming.Shortcut] = incoming;
        }

        _isApplyingSnapshot = true;
        try {
            State.Macros.Clear();
            foreach (var macro in mergedByShortcut.Values.OrderBy(m => m.Shortcut, StringComparer.OrdinalIgnoreCase)) {
                State.Macros.Add(macro);
            }

            State.Categories.Clear();
            foreach (var category in mergedCategories.OrderBy(c => c, StringComparer.OrdinalIgnoreCase)) {
                State.Categories.Add(category);
            }
            if (State.Categories.Count == 0) {
                State.Categories.Add("Chung");
            }
        } finally {
            _isApplyingSnapshot = false;
        }

        State.SelectedMacro = State.Macros.FirstOrDefault();
        State.SelectedCategory = State.SelectedMacro?.Category ?? State.Categories.FirstOrDefault();
        RefreshCommandStates();
        ScheduleSave();
        StatusMessage = $"Đã nhập {imported.Count} macro.";
    }

    private static List<MacroEntry> ParseImportedMacros(string payload) {
        var output = new List<MacroEntry>();

        if (TryParseMacrosFromJson(payload, output)) {
            return output;
        }

        foreach (var rawLine in payload.Split('\n')) {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#')) {
                continue;
            }

            var separators = new[] { "=>", "=", "\t", "|" };
            var splitIndex = -1;
            var token = string.Empty;
            foreach (var sep in separators) {
                splitIndex = line.IndexOf(sep, StringComparison.Ordinal);
                if (splitIndex > 0) {
                    token = sep;
                    break;
                }
            }

            if (splitIndex <= 0 || string.IsNullOrEmpty(token)) {
                continue;
            }

            var shortcut = line[..splitIndex].Trim();
            var content = line[(splitIndex + token.Length)..].Trim();
            if (string.IsNullOrWhiteSpace(shortcut) || string.IsNullOrWhiteSpace(content)) {
                continue;
            }

            output.Add(new MacroEntry(shortcut, content, "Chung"));
        }

        return output;
    }

    private static bool TryParseMacrosFromJson(string payload, List<MacroEntry> output) {
        try {
            using var document = JsonDocument.Parse(payload);
            var root = document.RootElement;

            if (root.ValueKind == JsonValueKind.Array) {
                foreach (var item in root.EnumerateArray()) {
                    TryAddMacroFromJson(item, output);
                }
                return output.Count > 0;
            }

            if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("macros", out var macrosElement) &&
                macrosElement.ValueKind == JsonValueKind.Array) {
                foreach (var item in macrosElement.EnumerateArray()) {
                    TryAddMacroFromJson(item, output);
                }
                return output.Count > 0;
            }
        } catch {
            return false;
        }

        return false;
    }

    private static void TryAddMacroFromJson(JsonElement item, List<MacroEntry> output) {
        var shortcut = GetJsonString(item, "shortcut");
        var content = GetJsonString(item, "expansion");
        if (string.IsNullOrWhiteSpace(content)) {
            content = GetJsonString(item, "content");
        }
        var category = GetJsonString(item, "category");
        if (string.IsNullOrWhiteSpace(category)) {
            category = "Chung";
        }

        if (string.IsNullOrWhiteSpace(shortcut) || string.IsNullOrWhiteSpace(content)) {
            return;
        }

        output.Add(new MacroEntry(shortcut.Trim(), content, category.Trim()));
    }

    private static string GetJsonString(JsonElement element, string propertyName) {
        if (!element.TryGetProperty(propertyName, out var value)) {
            return string.Empty;
        }

        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
    }

    private async Task AddExcludedAppAsync(object? parameter) {
        var owner = GetOwnerWindow();
        if (owner is null) return;

        string? appToExclude = null;
        string mode = parameter as string ?? "Running";

        if (mode == "Running") {
            appToExclude = await AppPickerWindow.ShowAsync(owner);
        } else if (mode == "File") {
            var files = await owner.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions {
                Title = "Chọn ứng dụng (.exe)",
                AllowMultiple = false,
                FileTypeFilter = new List<FilePickerFileType> {
                    new("Executable") { Patterns = new[] { "*.exe" } }
                }
            });
            appToExclude = Path.GetFileName(files.FirstOrDefault()?.TryGetLocalPath());
        } else {
            appToExclude = await TextPromptWindow.ShowAsync(owner, "Thêm thủ công", "Nhập tên tiến trình (ví dụ: notepad.exe)");
        }

        if (string.IsNullOrWhiteSpace(appToExclude)) return;

        var normalized = appToExclude.Trim();
        if (!State.ExcludedApps.Contains(normalized, StringComparer.OrdinalIgnoreCase)) {
            State.ExcludedApps.Add(normalized);
            StatusMessage = $"Đã thêm '{normalized}' vào danh sách loại trừ.";
        }
    }

    private void RemoveExcludedApp() {
        var selected = State.SelectedExcludedApp;
        if (string.IsNullOrWhiteSpace(selected)) {
            return;
        }

        State.ExcludedApps.Remove(selected);
        StatusMessage = $"Đã xóa '{selected}' khỏi danh sách loại trừ.";
    }

    private async Task AddStepByStepAppAsync(object? parameter) {
        var owner = GetOwnerWindow();
        if (owner is null) return;

        string? appToAdd = null;
        string mode = parameter as string ?? "Running";

        if (mode == "Running") {
            appToAdd = await AppPickerWindow.ShowAsync(owner);
        } else if (mode == "File") {
            var files = await owner.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions {
                Title = "Chọn ứng dụng (.exe)",
                AllowMultiple = false,
                FileTypeFilter = new List<FilePickerFileType> {
                    new("Executable") { Patterns = new[] { "*.exe" } }
                }
            });
            appToAdd = Path.GetFileName(files.FirstOrDefault()?.TryGetLocalPath());
        } else {
            appToAdd = await TextPromptWindow.ShowAsync(owner, "Thêm thủ công", "Nhập tên tiến trình (ví dụ: putty.exe)");
        }

        if (string.IsNullOrWhiteSpace(appToAdd)) return;

        var normalized = appToAdd.Trim();
        if (!State.StepByStepApps.Contains(normalized, StringComparer.OrdinalIgnoreCase)) {
            State.StepByStepApps.Add(normalized);
            StatusMessage = $"Đã thêm '{normalized}' vào danh sách gửi từng phím.";
        }
    }

    private void RemoveStepByStepApp() {
        var selected = State.SelectedStepByStepApp;
        if (string.IsNullOrWhiteSpace(selected)) {
            return;
        }

        State.StepByStepApps.Remove(selected);
        StatusMessage = $"Đã xóa '{selected}' khỏi danh sách gửi từng phím.";
    }

    private void CheckForUpdates() {
        OpenUrl("https://github.com/PhamHungTien/PHTV/releases/latest");
    }

    private void OpenGuide() {
        OpenUrl("https://phamhungtien.com/PHTV/");
    }

    private async Task ExportSettingsAsync() {
        var snapshot = SettingsSnapshot.FromState(State);
        var json = JsonSerializer.Serialize(snapshot, JsonOptions);

        var file = await PickSaveFileAsync(
            "Xuất cấu hình",
            $"phtv-settings-{DateTime.Now:yyyyMMdd-HHmmss}.json",
            "json",
            "JSON");

        if (file is not null) {
            await WriteTextToStorageFileAsync(file, json);
            StatusMessage = "Đã xuất cấu hình.";
            return;
        }

        var fallback = _settingsPersistenceService.BuildDefaultExportPath("phtv-settings");
        await File.WriteAllTextAsync(fallback, json);
        StatusMessage = $"Đã xuất cấu hình tại: {fallback}";
    }

    private async Task ImportSettingsAsync() {
        var file = await PickOpenFileAsync("Nhập cấu hình", "json", "JSON");
        if (file is null) {
            return;
        }

        var json = await ReadTextFromStorageFileAsync(file);
        if (string.IsNullOrWhiteSpace(json)) {
            StatusMessage = "File cấu hình rỗng.";
            return;
        }

        SettingsSnapshot? snapshot;
        try {
            snapshot = JsonSerializer.Deserialize<SettingsSnapshot>(json, JsonOptions);
        } catch (Exception ex) {
            StatusMessage = $"File cấu hình không hợp lệ: {ex.Message}";
            return;
        }

        if (snapshot is null) {
            StatusMessage = "Không đọc được cấu hình từ file.";
            return;
        }

        ApplySnapshot(snapshot);
        StatusMessage = "Đã nhập cấu hình.";
    }

    private async Task ResetSettingsAsync() {
        var owner = GetOwnerWindow();
        if (owner is null) {
            return;
        }

        var confirm = await TextPromptWindow.ShowAsync(
            owner,
            "Khôi phục mặc định",
            "Nhập RESET để xác nhận khôi phục toàn bộ cài đặt về mặc định.",
            watermark: "RESET");
        if (!string.Equals(confirm, "RESET", StringComparison.Ordinal)) {
            StatusMessage = "Đã hủy khôi phục mặc định.";
            return;
        }

        var defaults = new SettingsSnapshot();
        ApplySnapshot(defaults);
        StatusMessage = "Đã khôi phục cài đặt mặc định.";
    }

    private void ApplySnapshot(SettingsSnapshot snapshot) {
        _isApplyingSnapshot = true;
        try {
            snapshot.ApplyTo(State);
        } finally {
            _isApplyingSnapshot = false;
        }

        if (_startupService.IsSupported) {
            _isSyncingStartup = true;
            try {
                State.RunOnStartup = _startupService.IsEnabled();
            } finally {
                _isSyncingStartup = false;
            }
        }

        ApplyWindowTopmost();
        RefreshCommandStates();
        PersistStateNow();
    }

    private async Task CopyBugReportAsync() {
        var owner = GetOwnerWindow();
        if (owner?.Clipboard is null) {
            StatusMessage = "Clipboard chưa sẵn sàng.";
            return;
        }

        var report = _bugReportService.BuildReport(State);
        await owner.Clipboard.SetTextAsync(report);
        StatusMessage = "Đã sao chép nội dung báo lỗi vào clipboard.";
    }

    private async Task SaveBugReportAsync() {
        var report = _bugReportService.BuildReport(State);
        var file = await PickSaveFileAsync(
            "Lưu file báo lỗi",
            _bugReportService.BuildDefaultFileName(),
            "md",
            "Markdown");

        if (file is not null) {
            await WriteTextToStorageFileAsync(file, report);
            StatusMessage = "Đã lưu file báo lỗi.";
            return;
        }

        var fallback = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            _bugReportService.BuildDefaultFileName());
        await File.WriteAllTextAsync(fallback, report);
        StatusMessage = $"Đã lưu file báo lỗi tại: {fallback}";
    }

    private void OpenGithubIssue() {
        var report = _bugReportService.BuildReport(State);
        var url = _bugReportService.BuildGitHubIssueUrl(State, report);
        OpenUrl(url);
    }

    private void SendEmail() {
        var report = _bugReportService.BuildReport(State);
        var url = _bugReportService.BuildMailToUrl(State, report);
        OpenUrl(url);
    }

    private Window? GetOwnerWindow() {
        return _window;
    }

    private void OpenUrl(string url) {
        try {
            Process.Start(new ProcessStartInfo {
                FileName = url,
                UseShellExecute = true
            });
        } catch (Exception ex) {
            StatusMessage = $"Không mở được liên kết: {ex.Message}";
        }
    }

    private async Task<IStorageFile?> PickSaveFileAsync(string title, string suggestedName, string extension, string label) {
        if (_window?.StorageProvider is null) {
            return null;
        }

        var file = await _window.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions {
            Title = title,
            SuggestedFileName = suggestedName,
            DefaultExtension = extension,
            FileTypeChoices = new List<FilePickerFileType> {
                new(label) {
                    Patterns = new[] { $"*.{extension}" }
                }
            }
        });

        return file;
    }

    private async Task<IStorageFile?> PickOpenFileAsync(string title, string extension, string label) {
        if (_window?.StorageProvider is null) {
            return null;
        }

        var files = await _window.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions {
            Title = title,
            AllowMultiple = false,
            FileTypeFilter = new List<FilePickerFileType> {
                new(label) {
                    Patterns = new[] { $"*.{extension}" }
                }
            }
        });

        return files.FirstOrDefault();
    }

    private static async Task<string?> ReadTextFromStorageFileAsync(IStorageFile file) {
        var localPath = file.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(localPath)) {
            return await File.ReadAllTextAsync(localPath);
        }

        await using var stream = await file.OpenReadAsync();
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return await reader.ReadToEndAsync();
    }

    private static async Task WriteTextToStorageFileAsync(IStorageFile file, string content) {
        var localPath = file.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(localPath)) {
            await File.WriteAllTextAsync(localPath, content);
            return;
        }

        await using var stream = await file.OpenWriteAsync();
        using var writer = new StreamWriter(stream, Encoding.UTF8);
        await writer.WriteAsync(content);
        await writer.FlushAsync();
    }

    private sealed class MacroExportFile {
        public string Version { get; set; } = "1.0";
        public string ExportDate { get; set; } = DateTimeOffset.Now.ToString("o");
        public List<string> Categories { get; set; } = new();
        public List<MacroExportItem> Macros { get; set; } = new();
    }

    private sealed class MacroExportItem {
        public string Shortcut { get; set; } = string.Empty;
        public string Expansion { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string Category { get; set; } = "Chung";
    }
}
