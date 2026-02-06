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
    private WindowIcon? _englishTrayIcon;

    private NativeMenuItem? _languageStatusItem;
    private NativeMenuItem? _toggleLanguageItem;
    private NativeMenuItem? _checkSpellingItem;
    private NativeMenuItem? _useMacroItem;
    private NativeMenuItem? _quickTelexItem;
    private NativeMenuItem? _runOnStartupItem;

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
        _englishTrayIcon = TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_en.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/tray_en.png");
        var fallbackIcon = TryLoadWindowIcon("avares://PHTV.Windows/Assets/PHTV.ico")
            ?? TryLoadWindowIcon("avares://PHTV.Windows/Assets/icon.png");

        _trayIcon = new TrayIcon {
            Icon = _vietnameseTrayIcon ?? _englishTrayIcon ?? fallbackIcon,
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

        _languageStatusItem = new NativeMenuItem("Đang dùng: Tiếng Việt") {
            IsEnabled = false
        };
        menu.Add(_languageStatusItem);

        _toggleLanguageItem = new NativeMenuItem("Chuyển sang Tiếng Anh");
        _toggleLanguageItem.Click += (_, _) => {
            if (_isUpdatingTrayMenu) {
                return;
            }

            _mainWindowViewModel?.ToggleVietnameseEnabled();
        };
        menu.Add(_toggleLanguageItem);

        menu.Add(new NativeMenuItemSeparator());

        var inputMethodMenu = new NativeMenu();
        if (_mainWindowViewModel is not null) {
            foreach (var method in _mainWindowViewModel.State.InputMethodOptions) {
                var item = new NativeMenuItem(method) {
                    ToggleType = NativeMenuItemToggleType.Radio
                };
                item.Click += (_, _) => {
                    if (_isUpdatingTrayMenu) {
                        return;
                    }

                    _mainWindowViewModel.SetInputMethodOption(method);
                };
                _inputMethodItems[method] = item;
                inputMethodMenu.Add(item);
            }
        }

        menu.Add(new NativeMenuItem("Phương pháp gõ") {
            Menu = inputMethodMenu
        });

        var codeTableMenu = new NativeMenu();
        if (_mainWindowViewModel is not null) {
            foreach (var table in _mainWindowViewModel.State.CodeTableOptions) {
                var item = new NativeMenuItem(table) {
                    ToggleType = NativeMenuItemToggleType.Radio
                };
                item.Click += (_, _) => {
                    if (_isUpdatingTrayMenu) {
                        return;
                    }

                    _mainWindowViewModel.SetCodeTableOption(table);
                };
                _codeTableItems[table] = item;
                codeTableMenu.Add(item);
            }
        }

        menu.Add(new NativeMenuItem("Bảng mã") {
            Menu = codeTableMenu
        });

        _checkSpellingItem = new NativeMenuItem("Kiểm tra chính tả") {
            ToggleType = NativeMenuItemToggleType.CheckBox
        };
        _checkSpellingItem.Click += (_, _) => {
            if (_isUpdatingTrayMenu) {
                return;
            }

            if (_mainWindowViewModel is null) {
                return;
            }

            _mainWindowViewModel.SetCheckSpellingEnabled(!_mainWindowViewModel.State.CheckSpelling);
        };
        menu.Add(_checkSpellingItem);

        _useMacroItem = new NativeMenuItem("Bật gõ tắt") {
            ToggleType = NativeMenuItemToggleType.CheckBox
        };
        _useMacroItem.Click += (_, _) => {
            if (_isUpdatingTrayMenu) {
                return;
            }

            if (_mainWindowViewModel is null) {
                return;
            }

            _mainWindowViewModel.SetUseMacroEnabled(!_mainWindowViewModel.State.UseMacro);
        };
        menu.Add(_useMacroItem);

        _quickTelexItem = new NativeMenuItem("Gõ nhanh (Quick Telex)") {
            ToggleType = NativeMenuItemToggleType.CheckBox
        };
        _quickTelexItem.Click += (_, _) => {
            if (_isUpdatingTrayMenu) {
                return;
            }

            if (_mainWindowViewModel is null) {
                return;
            }

            _mainWindowViewModel.SetQuickTelexEnabled(!_mainWindowViewModel.State.QuickTelex);
        };
        menu.Add(_quickTelexItem);

        menu.Add(new NativeMenuItemSeparator());

        var openSettingsItem = new NativeMenuItem("Mở Cài đặt...");
        openSettingsItem.Click += (_, _) => ShowSettingsWindow(SettingsTabId.System);
        menu.Add(openSettingsItem);

        var openAboutItem = new NativeMenuItem("Về PHTV");
        openAboutItem.Click += (_, _) => ShowSettingsWindow(SettingsTabId.About);
        menu.Add(openAboutItem);

        var checkUpdatesItem = new NativeMenuItem("Kiểm tra cập nhật");
        checkUpdatesItem.Click += (_, _) => _mainWindowViewModel?.OpenLatestReleasePage();
        menu.Add(checkUpdatesItem);

        _runOnStartupItem = new NativeMenuItem("Khởi động cùng Windows") {
            ToggleType = NativeMenuItemToggleType.CheckBox
        };
        _runOnStartupItem.Click += (_, _) => {
            if (_isUpdatingTrayMenu) {
                return;
            }

            if (_mainWindowViewModel is null) {
                return;
            }

            _mainWindowViewModel.SetRunOnStartupEnabled(!_mainWindowViewModel.State.RunOnStartup);
        };
        menu.Add(_runOnStartupItem);

        menu.Add(new NativeMenuItemSeparator());

        var exitItem = new NativeMenuItem("Thoát PHTV");
        exitItem.Click += (_, _) => ExitApplication(desktop);
        menu.Add(exitItem);

        return menu;
    }

    private void OnTrayIconClicked(object? sender, EventArgs e) {
        Dispatcher.UIThread.Post(() => {
            _mainWindowViewModel?.ToggleVietnameseEnabled();
            UpdateTrayPresentation();
        });
    }

    private void OnViewModelStatePropertyChanged(object? sender, PropertyChangedEventArgs e) {
        var propertyName = e.PropertyName ?? string.Empty;
        if (propertyName is nameof(SettingsState.IsVietnameseEnabled)
            or nameof(SettingsState.InputMethod)
            or nameof(SettingsState.CodeTable)
            or nameof(SettingsState.CheckSpelling)
            or nameof(SettingsState.UseMacro)
            or nameof(SettingsState.QuickTelex)
            or nameof(SettingsState.RunOnStartup)) {
            UpdateTrayPresentation();
        }
    }

    private void UpdateTrayPresentation() {
        if (_mainWindowViewModel is null || _trayIcon is null) {
            return;
        }

        var state = _mainWindowViewModel.State;
        var isVietnamese = state.IsVietnameseEnabled;

        _trayIcon.Icon = isVietnamese
            ? (_vietnameseTrayIcon ?? _englishTrayIcon ?? _trayIcon.Icon)
            : (_englishTrayIcon ?? _vietnameseTrayIcon ?? _trayIcon.Icon);
        _trayIcon.ToolTipText = isVietnamese ? "PHTV - Tiếng Việt" : "PHTV - Tiếng Anh";

        _isUpdatingTrayMenu = true;
        try {
            if (_languageStatusItem is not null) {
                _languageStatusItem.Header = isVietnamese
                    ? "Đang dùng: Tiếng Việt"
                    : "Đang dùng: Tiếng Anh";
            }

            if (_toggleLanguageItem is not null) {
                _toggleLanguageItem.Header = isVietnamese
                    ? "Chuyển sang Tiếng Anh"
                    : "Chuyển sang Tiếng Việt";
            }

            if (_checkSpellingItem is not null) {
                _checkSpellingItem.IsChecked = state.CheckSpelling;
            }

            if (_useMacroItem is not null) {
                _useMacroItem.IsChecked = state.UseMacro;
            }

            if (_quickTelexItem is not null) {
                _quickTelexItem.IsChecked = state.QuickTelex;
            }

            if (_runOnStartupItem is not null) {
                _runOnStartupItem.IsChecked = state.RunOnStartup;
            }

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
