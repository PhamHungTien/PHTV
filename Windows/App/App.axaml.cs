using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using Avalonia.Threading;
using PHTV.Windows.ViewModels;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Threading;

namespace PHTV.Windows;

public sealed partial class App : Application {
    private MainWindow? _mainWindow;
    private MainWindowViewModel? _mainWindowViewModel;
    private TrayIcon? _trayIcon;
    private WindowIcon? _vietnameseTrayIcon;
    private WindowIcon? _inactiveTrayIcon;

    private NativeMenuItem? _languageStatusItem;
    private NativeMenuItem? _toggleLanguageItem;
    
    // Typing options
    private NativeMenuItem? _quickTelexItem;
    private NativeMenuItem? _upperCaseFirstCharItem;
    private NativeMenuItem? _allowConsonantZFWJItem;
    private NativeMenuItem? _quickStartConsonantItem;
    private NativeMenuItem? _quickEndConsonantItem;
    private NativeMenuItem? _checkSpellingItem;
    private NativeMenuItem? _useModernOrthographyItem;

    // Feature options
    private NativeMenuItem? _autoRestoreEnglishWordItem;
    private NativeMenuItem? _useMacroItem;
    private NativeMenuItem? _useMacroInEnglishModeItem;
    private NativeMenuItem? _autoCapsMacroItem;
    private NativeMenuItem? _useSmartSwitchKeyItem;
    private NativeMenuItem? _rememberCodeItem;
    private NativeMenuItem? _restoreOnEscapeItem;
    private NativeMenuItem? _pauseKeyEnabledItem;

    // Compatibility options
    private NativeMenuItem? _sendKeyStepByStepItem;
    private NativeMenuItem? _performLayoutCompatItem;

    // System options
    private NativeMenuItem? _runOnStartupItem;
    private NativeMenuItem? _showIconOnDockItem;

    private readonly Dictionary<string, NativeMenuItem> _inputMethodItems = new(StringComparer.Ordinal);
    private readonly Dictionary<string, NativeMenuItem> _codeTableItems = new(StringComparer.Ordinal);
    private bool _isUpdatingTrayMenu;
    private EventWaitHandle? _activateEvent;
    private RegisteredWaitHandle? _activateEventWaitHandle;

    public override void Initialize() {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted() {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop) {
            _mainWindowViewModel = new MainWindowViewModel();
            _mainWindow = new MainWindow(_mainWindowViewModel);
            desktop.MainWindow = _mainWindow;
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;

            _mainWindowViewModel.State.PropertyChanged += OnViewModelStatePropertyChanged;
            SetupTrayIcon(desktop);
            StartSingleInstanceActivationListener();
            desktop.Exit += (_, _) => StopSingleInstanceActivationListener();
        }

        base.OnFrameworkInitializationCompleted();
    }

    private void SetupTrayIcon(IClassicDesktopStyleApplicationLifetime desktop) {
        _vietnameseTrayIcon = TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_vi.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_vi.png");
        _inactiveTrayIcon = TryLoadWindowIcon("avares://PHTV.Windows/Assets/menubar_icon.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/menubar_icon.png")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_en.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_en.png");
        var fallbackIcon = TryLoadWindowIcon("avares://PHTV.Windows/Assets/PHTV.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/icon.png");
        var isVietnamese = _mainWindowViewModel?.State.IsVietnameseEnabled ?? true;

        _trayIcon = new TrayIcon {
            Icon = isVietnamese
                ? (_vietnameseTrayIcon ?? _inactiveTrayIcon ?? fallbackIcon)
                : (_inactiveTrayIcon ?? _vietnameseTrayIcon ?? fallbackIcon),
            ToolTipText = "PHTV",
            Menu = BuildTrayMenu(desktop),
            IsVisible = true
        };
        _trayIcon.Clicked += OnTrayIconClicked;

        TrayIcon.SetIcons(this, new TrayIcons { _trayIcon });
        UpdateTrayPresentation();
    }

    private NativeMenu BuildTrayMenu(IClassicDesktopStyleApplicationLifetime desktop) {
        var menu = new NativeMenu();

        // 1. Trạng thái (Checkmark style)
        _languageStatusItem = new NativeMenuItem("Tiếng Việt (V)") { ToggleType = NativeMenuItemToggleType.Radio };
        _languageStatusItem.Click += (_, _) => _mainWindowViewModel?.SetVietnameseEnabled(true);
        menu.Add(_languageStatusItem);

        _toggleLanguageItem = new NativeMenuItem("Tiếng Anh (E)") { ToggleType = NativeMenuItemToggleType.Radio };
        _toggleLanguageItem.Click += (_, _) => _mainWindowViewModel?.SetVietnameseEnabled(false);
        menu.Add(_toggleLanguageItem);

        menu.Add(new NativeMenuItemSeparator());

        // 2. Bộ gõ (Submenu)
        var typingMenu = new NativeMenu();
        
        var inputMethodSubMenu = new NativeMenu();
        if (_mainWindowViewModel is not null) {
            foreach (var method in _mainWindowViewModel.State.InputMethodOptions) {
                var item = new NativeMenuItem(method) { ToggleType = NativeMenuItemToggleType.Radio };
                item.Click += (_, _) => { if (!_isUpdatingTrayMenu) _mainWindowViewModel.SetInputMethodOption(method); };
                _inputMethodItems[method] = item;
                inputMethodSubMenu.Add(item);
            }
        }
        typingMenu.Add(new NativeMenuItem("⌨  Phương pháp gõ") { Menu = inputMethodSubMenu });

        var codeTableSubMenu = new NativeMenu();
        if (_mainWindowViewModel is not null) {
            foreach (var table in _mainWindowViewModel.State.CodeTableOptions) {
                var item = new NativeMenuItem(table) { ToggleType = NativeMenuItemToggleType.Radio };
                item.Click += (_, _) => { if (!_isUpdatingTrayMenu) _mainWindowViewModel.SetCodeTableOption(table); };
                _codeTableItems[table] = item;
                codeTableSubMenu.Add(item);
            }
        }
        typingMenu.Add(new NativeMenuItem("⛭  Bảng mã") { Menu = codeTableSubMenu });

        typingMenu.Add(new NativeMenuItemSeparator());

        _quickTelexItem = CreateToggleItem("⌨  Gõ nhanh (Quick Telex)", () => _mainWindowViewModel!.State.QuickTelex, v => _mainWindowViewModel!.SetQuickTelexEnabled(v));
        typingMenu.Add(_quickTelexItem);

        _upperCaseFirstCharItem = CreateToggleItem("⇪  Viết hoa đầu câu", () => _mainWindowViewModel!.State.UpperCaseFirstChar, v => _mainWindowViewModel!.State.UpperCaseFirstChar = v);
        typingMenu.Add(_upperCaseFirstCharItem);

        _allowConsonantZFWJItem = CreateToggleItem("Å  Phụ âm Z, F, W, J", () => _mainWindowViewModel!.State.AllowConsonantZFWJ, v => _mainWindowViewModel!.State.AllowConsonantZFWJ = v);
        typingMenu.Add(_allowConsonantZFWJItem);

        _quickStartConsonantItem = CreateToggleItem("↦  Phụ âm đầu nhanh", () => _mainWindowViewModel!.State.QuickStartConsonant, v => _mainWindowViewModel!.State.QuickStartConsonant = v);
        typingMenu.Add(_quickStartConsonantItem);

        _quickEndConsonantItem = CreateToggleItem("↤  Phụ âm cuối nhanh", () => _mainWindowViewModel!.State.QuickEndConsonant, v => _mainWindowViewModel!.State.QuickEndConsonant = v);
        typingMenu.Add(_quickEndConsonantItem);

        typingMenu.Add(new NativeMenuItemSeparator());

        _checkSpellingItem = CreateToggleItem("✎  Kiểm tra chính tả", () => _mainWindowViewModel!.State.CheckSpelling, v => _mainWindowViewModel!.SetCheckSpellingEnabled(v));
        typingMenu.Add(_checkSpellingItem);

        _useModernOrthographyItem = CreateToggleItem("📖  Chính tả mới (oà, uý)", () => _mainWindowViewModel!.State.UseModernOrthography, v => _mainWindowViewModel!.State.UseModernOrthography = v);
        typingMenu.Add(_useModernOrthographyItem);

        menu.Add(new NativeMenuItem("⌨  Bộ gõ") { Menu = typingMenu });

        // 3. Tính năng (Submenu)
        var featuresMenu = new NativeMenu();
        
        _autoRestoreEnglishWordItem = CreateToggleItem("↺  Tự động khôi phục tiếng Anh", () => _mainWindowViewModel!.State.AutoRestoreEnglishWord, v => _mainWindowViewModel!.State.AutoRestoreEnglishWord = v);
        featuresMenu.Add(_autoRestoreEnglishWordItem);

        featuresMenu.Add(new NativeMenuItemSeparator());

        _useMacroItem = CreateToggleItem("⚑  Bật gõ tắt", () => _mainWindowViewModel!.State.UseMacro, v => _mainWindowViewModel!.SetUseMacroEnabled(v));
        featuresMenu.Add(_useMacroItem);

        _useMacroInEnglishModeItem = CreateToggleItem("⚐  Gõ tắt khi ở chế độ Anh", () => _mainWindowViewModel!.State.UseMacroInEnglishMode, v => _mainWindowViewModel!.State.UseMacroInEnglishMode = v);
        featuresMenu.Add(_useMacroInEnglishModeItem);

        _autoCapsMacroItem = CreateToggleItem("Aa  Tự động viết hoa macro", () => _mainWindowViewModel!.State.AutoCapsMacro, v => _mainWindowViewModel!.State.AutoCapsMacro = v);
        featuresMenu.Add(_autoCapsMacroItem);

        featuresMenu.Add(new NativeMenuItemSeparator());

        _useSmartSwitchKeyItem = CreateToggleItem("⚙  Chuyển thông minh theo ứng dụng", () => _mainWindowViewModel!.State.UseSmartSwitchKey, v => _mainWindowViewModel!.State.UseSmartSwitchKey = v);
        featuresMenu.Add(_useSmartSwitchKeyItem);

        _rememberCodeItem = CreateToggleItem("⛃  Nhớ bảng mã theo ứng dụng", () => _mainWindowViewModel!.State.RememberCode, v => _mainWindowViewModel!.State.RememberCode = v);
        featuresMenu.Add(_rememberCodeItem);

        featuresMenu.Add(new NativeMenuItemSeparator());

        _restoreOnEscapeItem = CreateToggleItem("⎋  Khôi phục khi nhấn ESC", () => _mainWindowViewModel!.State.RestoreOnEscape, v => _mainWindowViewModel!.State.RestoreOnEscape = v);
        featuresMenu.Add(_restoreOnEscapeItem);

        _pauseKeyEnabledItem = CreateToggleItem("⏸  Tạm dừng khi giữ phím", () => _mainWindowViewModel!.State.PauseKeyEnabled, v => _mainWindowViewModel!.State.PauseKeyEnabled = v);
        featuresMenu.Add(_pauseKeyEnabledItem);

        menu.Add(new NativeMenuItem("⛭  Tính năng") { Menu = featuresMenu });

        // 4. Tương thích (Submenu)
        var compatibilityMenu = new NativeMenu();
        
        _sendKeyStepByStepItem = CreateToggleItem("⇶  Gửi phím từng bước", () => _mainWindowViewModel!.State.SendKeyStepByStep, v => _mainWindowViewModel!.State.SendKeyStepByStep = v);
        compatibilityMenu.Add(_sendKeyStepByStepItem);

        _performLayoutCompatItem = CreateToggleItem("⌨  Tương thích layout", () => _mainWindowViewModel!.State.PerformLayoutCompat, v => _mainWindowViewModel!.State.PerformLayoutCompat = v);
        compatibilityMenu.Add(_performLayoutCompatItem);

        menu.Add(new NativeMenuItem("🛠  Tương thích") { Menu = compatibilityMenu });

        // 5. Hệ thống (Submenu)
        var systemMenu = new NativeMenu();
        
        _runOnStartupItem = CreateToggleItem("⏻  Khởi động cùng máy", () => _mainWindowViewModel!.State.RunOnStartup, v => _mainWindowViewModel!.State.RunOnStartup = v);
        systemMenu.Add(_runOnStartupItem);

        _showIconOnDockItem = CreateToggleItem("▭  Hiện icon trên Taskbar", () => _mainWindowViewModel!.State.ShowIconOnDock, v => _mainWindowViewModel!.State.ShowIconOnDock = v);
        systemMenu.Add(_showIconOnDockItem);

        menu.Add(new NativeMenuItem("💻  Hệ thống") { Menu = systemMenu });

        menu.Add(new NativeMenuItemSeparator());

        // 6. Công cụ
        var toolsMenu = new NativeMenu();
        toolsMenu.Add(new NativeMenuItem("⚒  Chuyển đổi bảng mã...") { IsEnabled = false });
        menu.Add(new NativeMenuItem("⚒  Công cụ") { Menu = toolsMenu });

        menu.Add(new NativeMenuItemSeparator());

        // 7. Cài đặt
        var settingsItem = new NativeMenuItem("⚙  Mở Cài đặt...");
        settingsItem.Click += (_, _) => ShowSettingsWindow(SettingsTabId.Typing);
        menu.Add(settingsItem);

        menu.Add(new NativeMenuItemSeparator());

        var aboutItem = new NativeMenuItem("ⓘ  Về PHTV");
        aboutItem.Click += (_, _) => ShowSettingsWindow(SettingsTabId.About);
        menu.Add(aboutItem);

        var updateItem = new NativeMenuItem("↻  Kiểm tra cập nhật");
        updateItem.Click += (_, _) => _mainWindowViewModel?.OpenLatestReleasePage();
        menu.Add(updateItem);

        var exitItem = new NativeMenuItem("✕  Thoát");
        exitItem.Click += (_, _) => ExitApplication(desktop);
        menu.Add(exitItem);

        return menu;
    }

    private NativeMenuItem CreateToggleItem(string header, Func<bool> getter, Action<bool> setter) {
        var item = new NativeMenuItem(header) {
            ToggleType = NativeMenuItemToggleType.CheckBox
        };
        item.Click += (_, _) => {
            if (_isUpdatingTrayMenu || _mainWindowViewModel is null) return;
            setter(!getter());
        };
        return item;
    }

    private void OnTrayIconClicked(object? sender, EventArgs e) {
        Dispatcher.UIThread.Post(() => {
            _mainWindowViewModel?.ToggleVietnameseEnabled();
            UpdateTrayPresentation();
        });
    }

    private void OnViewModelStatePropertyChanged(object? sender, PropertyChangedEventArgs e) {
        UpdateTrayPresentation();
    }

    private void UpdateTrayPresentation() {
        if (_mainWindowViewModel is null || _trayIcon is null) {
            return;
        }

        var state = _mainWindowViewModel.State;
        var isVietnamese = state.IsVietnameseEnabled;
        var useVietnameseIcon = state.UseVietnameseMenubarIcon;
        var vietnameseModeIcon = useVietnameseIcon ? _vietnameseTrayIcon : _inactiveTrayIcon;

        _trayIcon.Icon = isVietnamese
            ? (vietnameseModeIcon ?? _inactiveTrayIcon ?? _vietnameseTrayIcon ?? _trayIcon.Icon)
            : (_inactiveTrayIcon ?? vietnameseModeIcon ?? _vietnameseTrayIcon ?? _trayIcon.Icon);
        _trayIcon.ToolTipText = isVietnamese ? "PHTV - Tiếng Việt" : "PHTV - Tiếng Anh";

        _isUpdatingTrayMenu = true;
        try {
            if (_languageStatusItem is not null) _languageStatusItem.IsChecked = isVietnamese;
            if (_toggleLanguageItem is not null) _toggleLanguageItem.IsChecked = !isVietnamese;

            // Typing
            if (_quickTelexItem is not null) _quickTelexItem.IsChecked = state.QuickTelex;
            if (_upperCaseFirstCharItem is not null) _upperCaseFirstCharItem.IsChecked = state.UpperCaseFirstChar;
            if (_allowConsonantZFWJItem is not null) _allowConsonantZFWJItem.IsChecked = state.AllowConsonantZFWJ;
            if (_quickStartConsonantItem is not null) _quickStartConsonantItem.IsChecked = state.QuickStartConsonant;
            if (_quickEndConsonantItem is not null) _quickEndConsonantItem.IsChecked = state.QuickEndConsonant;
            if (_checkSpellingItem is not null) _checkSpellingItem.IsChecked = state.CheckSpelling;
            if (_useModernOrthographyItem is not null) _useModernOrthographyItem.IsChecked = state.UseModernOrthography;

            // Features
            if (_autoRestoreEnglishWordItem is not null) _autoRestoreEnglishWordItem.IsChecked = state.AutoRestoreEnglishWord;
            if (_useMacroItem is not null) _useMacroItem.IsChecked = state.UseMacro;
            if (_useMacroInEnglishModeItem is not null) _useMacroInEnglishModeItem.IsChecked = state.UseMacroInEnglishMode;
            if (_autoCapsMacroItem is not null) _autoCapsMacroItem.IsChecked = state.AutoCapsMacro;
            if (_useSmartSwitchKeyItem is not null) _useSmartSwitchKeyItem.IsChecked = state.UseSmartSwitchKey;
            if (_rememberCodeItem is not null) _rememberCodeItem.IsChecked = state.RememberCode;
            if (_restoreOnEscapeItem is not null) _restoreOnEscapeItem.IsChecked = state.RestoreOnEscape;
            if (_pauseKeyEnabledItem is not null) _pauseKeyEnabledItem.IsChecked = state.PauseKeyEnabled;

            // Compatibility
            if (_sendKeyStepByStepItem is not null) _sendKeyStepByStepItem.IsChecked = state.SendKeyStepByStep;
            if (_performLayoutCompatItem is not null) _performLayoutCompatItem.IsChecked = state.PerformLayoutCompat;

            // System
            if (_runOnStartupItem is not null) _runOnStartupItem.IsChecked = state.RunOnStartup;
            if (_showIconOnDockItem is not null) _showIconOnDockItem.IsChecked = state.ShowIconOnDock;

            foreach (var (method, item) in _inputMethodItems) {
                item.IsChecked = string.Equals(state.InputMethod, method, StringComparison.Ordinal);
            }

            foreach (var (table, item) in _codeTableItems) {
                item.IsChecked = string.Equals(state.CodeTable, table, StringComparison.Ordinal);
            }
        } finally {
            _isUpdatingTrayMenu = false;
        }
    }

    private void ShowSettingsWindow(SettingsTabId tabId) {
        if (_mainWindowViewModel is null || _mainWindow is null) {
            return;
        }

        _mainWindowViewModel.ShowTab(tabId);
        _mainWindow.ShowFromTray();
    }

    private void ExitApplication(IClassicDesktopStyleApplicationLifetime desktop) {
        _trayIcon?.Dispose();
        TrayIcon.SetIcons(this, null);

        if (_mainWindowViewModel is not null) {
            _mainWindowViewModel.State.PropertyChanged -= OnViewModelStatePropertyChanged;
        }

        _mainWindow?.RequestExitAndClose();
        desktop.Shutdown();
    }

    private static WindowIcon? TryLoadWindowIcon(string uriText) {
        try {
            using var stream = AssetLoader.Open(new Uri(uriText));
            return new WindowIcon(stream);
        } catch {
            return null;
        }
    }

    private void StartSingleInstanceActivationListener() {
        try {
            _activateEvent = new EventWaitHandle(
                initialState: false,
                mode: EventResetMode.AutoReset,
                name: SingleInstanceCoordinator.ActivateEventName);

            _activateEventWaitHandle = ThreadPool.RegisterWaitForSingleObject(
                _activateEvent,
                static (state, timedOut) => {
                    if (timedOut || state is not App app) {
                        return;
                    }
                    app.OnActivateSignalReceived();
                },
                this,
                Timeout.Infinite,
                executeOnlyOnce: false);
        } catch (Exception ex) {
            StartupDiagnostics.WriteException("Failed to initialize single-instance activation listener", ex);
        }
    }

    private void StopSingleInstanceActivationListener() {
        try {
            _activateEventWaitHandle?.Unregister(null);
            _activateEventWaitHandle = null;
            _activateEvent?.Dispose();
            _activateEvent = null;
        } catch (Exception ex) {
            StartupDiagnostics.WriteException("Failed to dispose single-instance activation listener", ex);
        }
    }

    private void OnActivateSignalReceived() {
        Dispatcher.UIThread.Post(() => {
            if (_mainWindow is null) {
                return;
            }

            _mainWindow.ShowFromTray();
        });
    }
}