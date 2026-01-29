using System;
using System.Diagnostics;
using System.Drawing; // For Icon
using System.IO;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using PHTV.UI.Pages;
using PHTV.UI.Utilities;
using Wpf.Ui.Controls;
using static PHTV.UI.Interop.PhtvNative;
using Forms = System.Windows.Forms;
using UiMenuItem = Wpf.Ui.Controls.MenuItem;

namespace PHTV.UI
{
    public partial class MainWindow : FluentWindow
    {
        // Native interop declarations moved to PhtvNative

        private const int SwitchMaskBeep = 0x8000;
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string RunValueName = "PHTV";

        private readonly DispatcherTimer _saveConfigTimer = new DispatcherTimer();

        internal TypingPage TypingPage { get; private set; }
        internal HotkeysPage HotkeysPage { get; private set; }
        internal MacroPage MacroPage { get; private set; }
        internal AppsPage AppsPage { get; private set; }
        internal SystemPage SystemPage { get; private set; }
        internal AboutPage AboutPage { get; private set; }

        private Forms.NotifyIcon _notifyIcon;
        private ContextMenu _trayMenu;
        private Icon _iconVie;
        private Icon _iconEng;
        private Icon _iconApp;

        private UiMenuItem _menuLangVi;
        private UiMenuItem _menuLangEn;
        private UiMenuItem _menuInputTelex;
        private UiMenuItem _menuInputVni;
        private UiMenuItem _menuInputSimple1;
        private UiMenuItem _menuInputSimple2;
        private UiMenuItem _menuCodeUnicode;
        private UiMenuItem _menuCodeTcvn3;
        private UiMenuItem _menuCodeVni;
        private UiMenuItem _menuCodeUnicodeComposite;
        private UiMenuItem _menuCodeCp1258;
        private UiMenuItem _menuQuickTelex;
        private UiMenuItem _menuUpperFirst;
        private UiMenuItem _menuAllowZfwj;
        private UiMenuItem _menuQuickStart;
        private UiMenuItem _menuQuickEnd;
        private UiMenuItem _menuSpellCheck;
        private UiMenuItem _menuModernOrtho;
        private UiMenuItem _menuAutoRestoreEnglish;
        private UiMenuItem _menuUseMacro;
        private UiMenuItem _menuMacroInEnglish;
        private UiMenuItem _menuAutoCapsMacro;
        private UiMenuItem _menuSmartSwitch;
        private UiMenuItem _menuRememberCode;
        private UiMenuItem _menuRestoreOnEscape;
        private UiMenuItem _menuPauseKey;
        private UiMenuItem _menuSendKeyStepByStep;
        private UiMenuItem _menuPerformLayoutCompat;
        private UiMenuItem _menuRunOnStartup;
        private UiMenuItem _menuBeepOnSwitch;
        private UiMenuItem _menuQuickConvertTcvn3ToUnicode;
        private UiMenuItem _menuQuickConvertVniToUnicode;
        private UiMenuItem _menuQuickConvertUnicodeToTcvn3;
        private UiMenuItem _menuQuickConvertCompositeToUnicode;
        private UiMenuItem _menuOpenConvertTool;
        private UiMenuItem _menuOpenSettings;
        private UiMenuItem _menuOpenAbout;
        private UiMenuItem _menuCheckUpdates;
        private UiMenuItem _menuExit;

        [Conditional("DEBUG")]
        private void Log(string message)
        {
            try { File.AppendAllText("phtv_debug.txt", DateTime.Now + ": " + message + Environment.NewLine); } catch {}
        }

        public MainWindow()
        {
            Log("App Started");
            try {
                var resources = System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceNames();
                Log("Resources: " + string.Join(", ", resources));
            } catch (Exception ex) { Log("Error listing resources: " + ex.ToString()); }

            InitializeComponent();
            Log("InitializeComponent done");

            PreviewMouseWheel += MainWindow_PreviewMouseWheel;

            InitializeSaveTimer();
            InitializeEngine();
            Log("InitializeEngine done");
            PhtvPaths.Initialize();
            LoadMacroFile();
            LoadAppMapFile();
            LoadUpperExcludedFile();
            InitializeTrayIcon();
            Loaded += MainWindow_OnLoaded;
        }

        private void MainWindow_OnLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                NavView.Navigate(typeof(TypingPage));
            }
            catch (Exception ex)
            {
                Log("Navigate failed: " + ex);
            }
        }

        private void MainWindow_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
        {
            if (e.Handled) return;

            var scrollViewer = FindTaggedScrollViewer(e.OriginalSource as DependencyObject);
            if (scrollViewer == null || scrollViewer.ScrollableHeight <= 0)
            {
                return;
            }

            double lines = SystemParameters.WheelScrollLines;
            if (lines <= 0) lines = 1;
            double delta = -e.Delta / Mouse.MouseWheelDeltaForOneLine;
            double offset = scrollViewer.VerticalOffset + (delta * lines * 16);
            scrollViewer.ScrollToVerticalOffset(offset);
            e.Handled = true;
        }

        private static ScrollViewer FindTaggedScrollViewer(DependencyObject source)
        {
            while (source != null)
            {
                if (source is ScrollViewer scrollViewer)
                {
                    return Equals(scrollViewer.Tag, "PageScroll") ? scrollViewer : null;
                }
                source = VisualTreeHelper.GetParent(source);
            }
            return null;
        }

        internal void RegisterPage(object page)
        {
            switch (page)
            {
                case TypingPage typing:
                    TypingPage = typing;
                    break;
                case HotkeysPage hotkeys:
                    HotkeysPage = hotkeys;
                    break;
                case MacroPage macro:
                    MacroPage = macro;
                    break;
                case AppsPage apps:
                    AppsPage = apps;
                    break;
                case SystemPage system:
                    SystemPage = system;
                    break;
                case AboutPage about:
                    AboutPage = about;
                    break;
            }
        }

        internal void ReloadSettings()
        {
            TypingPage?.LoadFromEngine();
            HotkeysPage?.LoadFromEngine();
            MacroPage?.LoadFromEngine();
            AppsPage?.LoadFromEngine();
            SystemPage?.LoadFromEngine();
        }

        private void NavigateToTag(string tag)
        {
            try
            {
                NavView.Navigate(tag);
            }
            catch (Exception ex)
            {
                Log("Navigate tag failed: " + ex);
            }
        }

        private void InitializeSaveTimer()
        {
            _saveConfigTimer.Interval = TimeSpan.FromMilliseconds(400);
            _saveConfigTimer.Tick += (s, e) =>
            {
                _saveConfigTimer.Stop();
                PHTV_SaveConfig();
            };
        }

        internal void ScheduleSave()
        {
            _saveConfigTimer.Stop();
            _saveConfigTimer.Start();
        }

        private void SaveConfigNow()
        {
            _saveConfigTimer.Stop();
            PHTV_SaveConfig();
        }

        private void InitializeTrayIcon()
        {
            _notifyIcon = new Forms.NotifyIcon
            {
                Text = "PHTV - Bộ gõ tiếng Việt",
                Visible = true
            };

            // Extract all icons
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string imgDir = Path.Combine(appData, "PHTV", "Data", "Images");
            Directory.CreateDirectory(imgDir);

            string[] icons = { "app.ico", "eng.ico", "vie.ico" };
            foreach (var iconName in icons)
            {
                string iconPath = Path.Combine(imgDir, iconName);
                if (!File.Exists(iconPath))
                {
                    ExtractResource("PHTV.UI.Resources.Images." + iconName, iconPath);
                }
            }

            _iconApp = File.Exists(Path.Combine(imgDir, "app.ico")) ? new Icon(Path.Combine(imgDir, "app.ico")) : SystemIcons.Application;
            _iconEng = File.Exists(Path.Combine(imgDir, "eng.ico")) ? new Icon(Path.Combine(imgDir, "eng.ico")) : SystemIcons.Application;
            _iconVie = File.Exists(Path.Combine(imgDir, "vie.ico")) ? new Icon(Path.Combine(imgDir, "vie.ico")) : SystemIcons.Application;

            BuildTrayMenu();
            UpdateTrayIconState();

            _notifyIcon.MouseClick += (s, e) =>
            {
                if (e.Button == Forms.MouseButtons.Left)
                {
                    int currentLang = PHTV_GetLanguage();
                    int newLang = (currentLang == 1) ? 0 : 1;
                    SetLanguage(newLang);
                }
                else if (e.Button == Forms.MouseButtons.Right)
                {
                    ShowTrayMenuAtCursor();
                }
            };

            _notifyIcon.DoubleClick += (s, e) => ShowWindow();
        }

        private void BuildTrayMenu()
        {
            _trayMenu = new ContextMenu
            {
                StaysOpen = false
            };
            _trayMenu.Opened += (s, e) => UpdateTrayMenuState();

            // Language picker
            var langMenu = new UiMenuItem { Header = "Ngôn ngữ" };
            _menuLangVi = new UiMenuItem { Header = "Tiếng Việt", IsCheckable = true };
            _menuLangEn = new UiMenuItem { Header = "Tiếng Anh", IsCheckable = true };
            _menuLangVi.Click += (s, e) => SetLanguage(1);
            _menuLangEn.Click += (s, e) => SetLanguage(0);
            AddItems(langMenu, _menuLangVi, _menuLangEn);
            AddItems(_trayMenu, langMenu, new Separator());

            // Typing menu
            var typingMenu = new UiMenuItem { Header = "Bộ gõ" };

            var inputMenu = new UiMenuItem { Header = "Phương pháp gõ" };
            _menuInputTelex = new UiMenuItem { Header = "Telex", IsCheckable = true };
            _menuInputVni = new UiMenuItem { Header = "VNI", IsCheckable = true };
            _menuInputSimple1 = new UiMenuItem { Header = "Simple Telex 1", IsCheckable = true };
            _menuInputSimple2 = new UiMenuItem { Header = "Simple Telex 2", IsCheckable = true };
            _menuInputTelex.Click += (s, e) => SetInputMethod(0);
            _menuInputVni.Click += (s, e) => SetInputMethod(1);
            _menuInputSimple1.Click += (s, e) => SetInputMethod(2);
            _menuInputSimple2.Click += (s, e) => SetInputMethod(3);
            AddItems(inputMenu, _menuInputTelex, _menuInputVni, _menuInputSimple1, _menuInputSimple2);

            var codeMenu = new UiMenuItem { Header = "Bảng mã" };
            _menuCodeUnicode = new UiMenuItem { Header = "Unicode", IsCheckable = true };
            _menuCodeTcvn3 = new UiMenuItem { Header = "TCVN3 (ABC)", IsCheckable = true };
            _menuCodeVni = new UiMenuItem { Header = "VNI Windows", IsCheckable = true };
            _menuCodeUnicodeComposite = new UiMenuItem { Header = "Unicode tổ hợp", IsCheckable = true };
            _menuCodeCp1258 = new UiMenuItem { Header = "Vietnamese Locale (CP1258)", IsCheckable = true };
            _menuCodeUnicode.Click += (s, e) => SetCodeTable(0);
            _menuCodeTcvn3.Click += (s, e) => SetCodeTable(1);
            _menuCodeVni.Click += (s, e) => SetCodeTable(2);
            _menuCodeUnicodeComposite.Click += (s, e) => SetCodeTable(3);
            _menuCodeCp1258.Click += (s, e) => SetCodeTable(4);
            AddItems(codeMenu, _menuCodeUnicode, _menuCodeTcvn3, _menuCodeVni, _menuCodeUnicodeComposite, _menuCodeCp1258);

            _menuQuickTelex = new UiMenuItem { Header = "Gõ nhanh (Quick Telex)", IsCheckable = true };
            _menuUpperFirst = new UiMenuItem { Header = "Viết hoa đầu câu", IsCheckable = true };
            _menuAllowZfwj = new UiMenuItem { Header = "Phụ âm Z, F, W, J", IsCheckable = true };
            _menuQuickStart = new UiMenuItem { Header = "Phụ âm đầu nhanh", IsCheckable = true };
            _menuQuickEnd = new UiMenuItem { Header = "Phụ âm cuối nhanh", IsCheckable = true };
            _menuSpellCheck = new UiMenuItem { Header = "Kiểm tra chính tả", IsCheckable = true };
            _menuModernOrtho = new UiMenuItem { Header = "Chính tả mới (oà, uý)", IsCheckable = true };

            _menuQuickTelex.Click += (s, e) => { PHTV_SetQuickTelex(_menuQuickTelex.IsChecked == true); ScheduleSave(); };
            _menuUpperFirst.Click += (s, e) => { PHTV_SetUpperCaseFirstChar(_menuUpperFirst.IsChecked == true); ScheduleSave(); };
            _menuAllowZfwj.Click += (s, e) => { PHTV_SetAllowConsonantZFWJ(_menuAllowZfwj.IsChecked == true); ScheduleSave(); };
            _menuQuickStart.Click += (s, e) => { PHTV_SetQuickStartConsonant(_menuQuickStart.IsChecked == true); ScheduleSave(); };
            _menuQuickEnd.Click += (s, e) => { PHTV_SetQuickEndConsonant(_menuQuickEnd.IsChecked == true); ScheduleSave(); };
            _menuSpellCheck.Click += (s, e) => { PHTV_SetSpellCheck(_menuSpellCheck.IsChecked == true); ScheduleSave(); };
            _menuModernOrtho.Click += (s, e) => { PHTV_SetModernOrthography(_menuModernOrtho.IsChecked == true); ScheduleSave(); };

            AddItems(typingMenu,
                inputMenu,
                codeMenu,
                new Separator(),
                _menuQuickTelex,
                _menuUpperFirst,
                _menuAllowZfwj,
                _menuQuickStart,
                _menuQuickEnd,
                new Separator(),
                _menuSpellCheck,
                _menuModernOrtho);
            _trayMenu.Items.Add(typingMenu);

            // Features menu
            var featuresMenu = new UiMenuItem { Header = "Tính năng" };
            _menuAutoRestoreEnglish = new UiMenuItem { Header = "Tự động khôi phục tiếng Anh", IsCheckable = true };
            _menuUseMacro = new UiMenuItem { Header = "Bật gõ tắt", IsCheckable = true };
            _menuMacroInEnglish = new UiMenuItem { Header = "Gõ tắt khi ở chế độ Anh", IsCheckable = true };
            _menuAutoCapsMacro = new UiMenuItem { Header = "Tự động viết hoa macro", IsCheckable = true };
            _menuSmartSwitch = new UiMenuItem { Header = "Chuyển thông minh theo ứng dụng", IsCheckable = true };
            _menuRememberCode = new UiMenuItem { Header = "Nhớ bảng mã theo ứng dụng", IsCheckable = true };
            _menuRestoreOnEscape = new UiMenuItem { Header = "Khôi phục khi nhấn Esc", IsCheckable = true };
            _menuPauseKey = new UiMenuItem { Header = "Tạm dừng khi giữ phím", IsCheckable = true };

            _menuAutoRestoreEnglish.Click += (s, e) => { PHTV_SetAutoRestoreEnglishWord(_menuAutoRestoreEnglish.IsChecked == true); ScheduleSave(); };
            _menuUseMacro.Click += (s, e) => { PHTV_SetMacro(_menuUseMacro.IsChecked == true); ScheduleSave(); };
            _menuMacroInEnglish.Click += (s, e) => { PHTV_SetMacroInEnglishMode(_menuMacroInEnglish.IsChecked == true); ScheduleSave(); };
            _menuAutoCapsMacro.Click += (s, e) => { PHTV_SetAutoCapsMacro(_menuAutoCapsMacro.IsChecked == true); ScheduleSave(); };
            _menuSmartSwitch.Click += (s, e) => { PHTV_SetSmartSwitchKey(_menuSmartSwitch.IsChecked == true); ScheduleSave(); };
            _menuRememberCode.Click += (s, e) => { PHTV_SetRememberCode(_menuRememberCode.IsChecked == true); ScheduleSave(); };
            _menuRestoreOnEscape.Click += (s, e) => { PHTV_SetRestoreOnEscape(_menuRestoreOnEscape.IsChecked == true); ScheduleSave(); };
            _menuPauseKey.Click += (s, e) => { PHTV_SetPauseKeyEnabled(_menuPauseKey.IsChecked == true); ScheduleSave(); };

            AddItems(featuresMenu,
                _menuAutoRestoreEnglish,
                new Separator(),
                _menuUseMacro,
                _menuMacroInEnglish,
                _menuAutoCapsMacro,
                new Separator(),
                _menuSmartSwitch,
                _menuRememberCode,
                new Separator(),
                _menuRestoreOnEscape,
                _menuPauseKey);
            _trayMenu.Items.Add(featuresMenu);

            // Compatibility menu
            var compatMenu = new UiMenuItem { Header = "Tương thích" };
            _menuSendKeyStepByStep = new UiMenuItem { Header = "Gửi phím từng bước", IsCheckable = true };
            _menuPerformLayoutCompat = new UiMenuItem { Header = "Tương thích layout bàn phím", IsCheckable = true };
            _menuSendKeyStepByStep.Click += (s, e) => { PHTV_SetSendKeyStepByStep(_menuSendKeyStepByStep.IsChecked == true); ScheduleSave(); };
            _menuPerformLayoutCompat.Click += (s, e) => { PHTV_SetPerformLayoutCompat(_menuPerformLayoutCompat.IsChecked == true); ScheduleSave(); };
            AddItems(compatMenu, _menuSendKeyStepByStep, _menuPerformLayoutCompat);
            _trayMenu.Items.Add(compatMenu);

            // System menu
            var systemMenu = new UiMenuItem { Header = "Hệ thống" };
            _menuRunOnStartup = new UiMenuItem { Header = "Khởi động cùng Windows", IsCheckable = true };
            _menuBeepOnSwitch = new UiMenuItem { Header = "Âm thanh khi chuyển chế độ", IsCheckable = true };
            _menuRunOnStartup.Click += (s, e) => SetRunOnStartup(_menuRunOnStartup.IsChecked == true);
            _menuBeepOnSwitch.Click += (s, e) => SetSwitchBeep(_menuBeepOnSwitch.IsChecked == true);
            AddItems(systemMenu, _menuRunOnStartup, _menuBeepOnSwitch);
            _trayMenu.Items.Add(systemMenu);

            _trayMenu.Items.Add(new Separator());

            // Tools menu
            var toolsMenu = new UiMenuItem { Header = "Công cụ" };
            _menuQuickConvertTcvn3ToUnicode = new UiMenuItem { Header = "TCVN3 → Unicode" };
            _menuQuickConvertVniToUnicode = new UiMenuItem { Header = "VNI → Unicode" };
            _menuQuickConvertUnicodeToTcvn3 = new UiMenuItem { Header = "Unicode → TCVN3" };
            _menuQuickConvertCompositeToUnicode = new UiMenuItem { Header = "Tổ hợp → Unicode" };
            _menuOpenConvertTool = new UiMenuItem { Header = "Chuyển đổi bảng mã..." };

            _menuQuickConvertTcvn3ToUnicode.Click += (s, e) => QuickConvertClipboard(1, 0);
            _menuQuickConvertVniToUnicode.Click += (s, e) => QuickConvertClipboard(2, 0);
            _menuQuickConvertUnicodeToTcvn3.Click += (s, e) => QuickConvertClipboard(0, 1);
            _menuQuickConvertCompositeToUnicode.Click += (s, e) => QuickConvertClipboard(3, 0);
            _menuOpenConvertTool.Click += (s, e) => ShowConvertTool();

            AddItems(toolsMenu,
                _menuQuickConvertTcvn3ToUnicode,
                _menuQuickConvertVniToUnicode,
                _menuQuickConvertUnicodeToTcvn3,
                _menuQuickConvertCompositeToUnicode,
                new Separator(),
                _menuOpenConvertTool);
            _trayMenu.Items.Add(toolsMenu);

            _trayMenu.Items.Add(new Separator());

            _menuOpenSettings = new UiMenuItem { Header = "Mở Cài đặt..." };
            _menuOpenSettings.Click += (s, e) => ShowWindow();
            string version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "1.0";
            _menuOpenAbout = new UiMenuItem { Header = $"Về PHTV v{version}" };
            _menuOpenAbout.Click += (s, e) => ShowAboutView();
            _menuCheckUpdates = new UiMenuItem { Header = "Kiểm tra cập nhật" };
            _menuCheckUpdates.Click += (s, e) => OpenUrl("https://github.com/PhamHungTien/PHTV/releases/latest");
            _menuExit = new UiMenuItem { Header = "Thoát PHTV" };
            _menuExit.Click += (s, e) =>
            {
                SaveConfigNow();
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
                _iconApp?.Dispose();
                _iconEng?.Dispose();
                _iconVie?.Dispose();
                PHTV_UninstallHook();
                System.Windows.Application.Current.Shutdown();
            };

            AddItems(_trayMenu,
                _menuOpenSettings,
                _menuOpenAbout,
                _menuCheckUpdates,
                new Separator(),
                _menuExit);
        }

        private static void AddItems(ItemsControl parent, params object[] items)
        {
            foreach (var item in items)
            {
                parent.Items.Add(item);
            }
        }

        private void ShowTrayMenuAtCursor()
        {
            if (_trayMenu == null) return;

            Dispatcher.Invoke(() =>
            {
                UpdateTrayMenuState();
                var cursor = Forms.Cursor.Position;
                var dpi = VisualTreeHelper.GetDpi(this);
                double x = cursor.X / dpi.DpiScaleX;
                double y = cursor.Y / dpi.DpiScaleY;

                _trayMenu.IsOpen = false;
                _trayMenu.PlacementTarget = this;
                _trayMenu.Placement = PlacementMode.AbsolutePoint;
                _trayMenu.HorizontalOffset = x;
                _trayMenu.VerticalOffset = y;
                _trayMenu.IsOpen = true;
            });
        }

        internal void UpdateTrayIconState()
        {
            if (_notifyIcon == null) return;

            int lang = PHTV_GetLanguage();
            Icon fallback = _iconApp ?? SystemIcons.Application;
            _notifyIcon.Icon = (lang == 1) ? (_iconVie ?? fallback) : (_iconEng ?? fallback);
            _notifyIcon.Text = (lang == 1) ? "PHTV - Tiếng Việt" : "PHTV - English";
        }

        internal void UpdateTrayMenuState()
        {
            _menuLangVi.IsChecked = PHTV_GetLanguage() == 1;
            _menuLangEn.IsChecked = PHTV_GetLanguage() == 0;

            int inputType = PHTV_GetInputMethod();
            _menuInputTelex.IsChecked = inputType == 0;
            _menuInputVni.IsChecked = inputType == 1;
            _menuInputSimple1.IsChecked = inputType == 2;
            _menuInputSimple2.IsChecked = inputType == 3;

            int codeTable = PHTV_GetCodeTable();
            _menuCodeUnicode.IsChecked = codeTable == 0;
            _menuCodeTcvn3.IsChecked = codeTable == 1;
            _menuCodeVni.IsChecked = codeTable == 2;
            _menuCodeUnicodeComposite.IsChecked = codeTable == 3;
            _menuCodeCp1258.IsChecked = codeTable == 4;

            _menuQuickTelex.IsChecked = PHTV_GetQuickTelex();
            _menuUpperFirst.IsChecked = PHTV_GetUpperCaseFirstChar();
            _menuAllowZfwj.IsChecked = PHTV_GetAllowConsonantZFWJ();
            _menuQuickStart.IsChecked = PHTV_GetQuickStartConsonant();
            _menuQuickEnd.IsChecked = PHTV_GetQuickEndConsonant();
            _menuSpellCheck.IsChecked = PHTV_GetSpellCheck();
            _menuModernOrtho.IsChecked = PHTV_GetModernOrthography();

            _menuAutoRestoreEnglish.IsChecked = PHTV_GetAutoRestoreEnglishWord();
            _menuUseMacro.IsChecked = PHTV_GetMacro();
            _menuMacroInEnglish.IsChecked = PHTV_GetMacroInEnglishMode();
            _menuAutoCapsMacro.IsChecked = PHTV_GetAutoCapsMacro();
            _menuSmartSwitch.IsChecked = PHTV_GetSmartSwitchKey();
            _menuRememberCode.IsChecked = PHTV_GetRememberCode();
            _menuRestoreOnEscape.IsChecked = PHTV_GetRestoreOnEscape();
            _menuPauseKey.IsChecked = PHTV_GetPauseKeyEnabled();

            _menuSendKeyStepByStep.IsChecked = PHTV_GetSendKeyStepByStep();
            _menuPerformLayoutCompat.IsChecked = PHTV_GetPerformLayoutCompat();

            _menuRunOnStartup.IsChecked = IsRunOnStartupEnabled();
            _menuBeepOnSwitch.IsChecked = IsBeepOnModeSwitch();

            if (IsVisible)
            {
                ReloadSettings();
            }
        }

        private bool IsBeepOnModeSwitch()
        {
            return (PHTV_GetSwitchKeyStatus() & SwitchMaskBeep) != 0;
        }

        private void SetSwitchBeep(bool enable)
        {
            int status = PHTV_GetSwitchKeyStatus();
            if (enable)
            {
                status |= SwitchMaskBeep;
            }
            else
            {
                status &= ~SwitchMaskBeep;
            }
            PHTV_SetSwitchKeyStatus(status);
            ScheduleSave();

            if (IsVisible)
            {
                HotkeysPage?.ApplySwitchBeep(enable);
            }
        }

        private void SetLanguage(int lang)
        {
            PHTV_SetLanguage(lang);
            ScheduleSave();
            UpdateTrayIconState();
            UpdateTrayMenuState();

            if (IsBeepOnModeSwitch())
            {
                System.Media.SystemSounds.Beep.Play();
            }

            if (IsVisible)
            {
                ReloadSettings();
            }
        }

        private void SetInputMethod(int method)
        {
            PHTV_SetInputMethod(method);
            ScheduleSave();
            UpdateTrayMenuState();
            if (IsVisible)
            {
                ReloadSettings();
            }
        }

        private void SetCodeTable(int table)
        {
            PHTV_SetCodeTable(table);
            ScheduleSave();
            UpdateTrayMenuState();
            if (IsVisible)
            {
                ReloadSettings();
            }
        }

        private void QuickConvertClipboard(int fromCode, int toCode)
        {
            bool ok = PHTV_QuickConvertClipboard(fromCode, toCode);
            if (!ok)
            {
                System.Windows.MessageBox.Show("Không thể chuyển đổi clipboard.");
            }
        }

        private void ShowConvertTool()
        {
            var window = new ConvertWindow();
            window.Owner = this;
            window.ShowDialog();
        }

        private void ShowAboutView()
        {
            ShowWindow();
            NavigateToTag("View_About");
        }
        private void ShowWindow()
        {
            this.Show();
            this.WindowState = WindowState.Normal;
            this.Activate();
            ReloadSettings();
        }

        protected override void OnStateChanged(EventArgs e)
        {
            if (this.WindowState == WindowState.Minimized)
            {
                this.Hide();
            }
            base.OnStateChanged(e);
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            e.Cancel = true;
            this.Hide();
        }

        private void InitializeEngine()
        {
            try
            {
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string phtvDataDir = Path.Combine(appData, "PHTV", "Data");
                string dictDir = Path.Combine(phtvDataDir, "Dictionaries");
                Directory.CreateDirectory(dictDir);

                EnsureDictionaryFiles(dictDir);

                PHTV_Init(phtvDataDir);
                PHTV_InstallHook();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show("Khởi tạo PHTV thất bại: " + ex.Message + "\n" + ex.StackTrace);
            }
        }

        private void ExtractResource(string resourceName, string outputPath)
        {
            try 
            {
                var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                using (var stream = assembly.GetManifestResourceStream(resourceName))
                {
                    if (stream == null) return;
                    using (var fileStream = File.Create(outputPath))
                    {
                        stream.CopyTo(fileStream);
                    }
                }
            }
            catch { }
        }

        private void EnsureDictionaryFiles(string dictDir)
        {
            string baseDir = AppContext.BaseDirectory;
            string sourceDir = Path.Combine(baseDir, "Resources", "Dictionaries");
            EnsureFile(Path.Combine(sourceDir, "vi_dict.bin"),
                "PHTV.UI.Resources.Dictionaries.vi_dict.bin",
                Path.Combine(dictDir, "vi_dict.bin"));
            EnsureFile(Path.Combine(sourceDir, "en_dict.bin"),
                "PHTV.UI.Resources.Dictionaries.en_dict.bin",
                Path.Combine(dictDir, "en_dict.bin"));
        }

        private void EnsureFile(string sourcePath, string resourceName, string destPath)
        {
            try
            {
                if (File.Exists(sourcePath))
                {
                    var srcInfo = new FileInfo(sourcePath);
                    var dstInfo = new FileInfo(destPath);
                    if (dstInfo.Exists &&
                        dstInfo.Length == srcInfo.Length &&
                        dstInfo.LastWriteTimeUtc >= srcInfo.LastWriteTimeUtc)
                    {
                        return;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(destPath) ?? string.Empty);
                    File.Copy(sourcePath, destPath, true);
                    return;
                }

                if (File.Exists(destPath) && new FileInfo(destPath).Length > 0)
                {
                    return;
                }

                ExtractResource(resourceName, destPath);
            }
            catch
            {
                // Best-effort; initialization will fail later if dicts are missing.
            }
        }

        private void LoadMacroFile()
        {
            if (File.Exists(PhtvPaths.MacroPath)) PHTV_MacroLoad(PhtvPaths.MacroPath);
            else PHTV_MacroClear();
        }

        private void LoadAppMapFile()
        {
            if (File.Exists(PhtvPaths.AppMapPath)) PHTV_AppListLoad(PhtvPaths.AppMapPath);
            else PHTV_AppListClear();
        }

        private void LoadUpperExcludedFile()
        {
            if (File.Exists(PhtvPaths.UpperExcludedPath)) PHTV_UpperExcludedLoad(PhtvPaths.UpperExcludedPath);
            else PHTV_UpperExcludedClear();
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private static string GetExecutablePath()
        {
            string path = Assembly.GetEntryAssembly()?.Location;
            if (string.IsNullOrWhiteSpace(path))
            {
                path = Process.GetCurrentProcess().MainModule?.FileName;
            }
            return path ?? string.Empty;
        }

        internal static bool IsRunOnStartupEnabled()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
                string value = key?.GetValue(RunValueName) as string;
                if (string.IsNullOrWhiteSpace(value)) return false;
                string exePath = GetExecutablePath();
                if (string.IsNullOrWhiteSpace(exePath)) return false;
                return value.Trim('"').Equals(exePath, StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        internal static void SetRunOnStartup(bool enable)
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true) ??
                                Registry.CurrentUser.CreateSubKey(RunKeyPath);
                if (key == null) return;
                if (enable)
                {
                    string exePath = GetExecutablePath();
                    if (!string.IsNullOrWhiteSpace(exePath))
                    {
                        key.SetValue(RunValueName, $"\"{exePath}\"");
                    }
                }
                else
                {
                    key.DeleteValue(RunValueName, false);
                }
            }
            catch
            {
                // Best-effort
            }
        }

        internal static void OpenUrl(string url)
        {
            try
            {
                Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            }
            catch
            {
                // ignore
            }
        }
    }
}
