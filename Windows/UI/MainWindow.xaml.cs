using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Forms; // For NotifyIcon
using System.Windows.Threading;

namespace PHTV.UI
{
    public partial class MainWindow : Window
    {
        // Import C++ DLL
        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_Init();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_InstallHook();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_LoadConfig();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SaveConfig();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_ResetConfig();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetInputMethod(int type);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetLanguage(int lang);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetCodeTable(int table);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSpellCheck(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetModernOrthography(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickTelex(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAutoRestoreEnglishWord(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetMacro(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetMacroInEnglishMode(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAutoCapsMacro(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetFixRecommendBrowser(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSmartSwitchKey(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetUpperCaseFirstChar(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetUpperCaseExcludedForCurrentApp(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetAllowConsonantZFWJ(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickStartConsonant(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetQuickEndConsonant(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetFreeMark(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetRestoreOnEscape(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetCustomEscapeKey(int key);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetPauseKeyEnabled(bool enable);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetPauseKey(int key);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSwitchKeyStatus(int status);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetOtherLanguage(int lang);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetInputMethod();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetLanguage();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetCodeTable();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetSpellCheck();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetModernOrthography();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickTelex();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAutoRestoreEnglishWord();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetMacro();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetMacroInEnglishMode();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAutoCapsMacro();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetFixRecommendBrowser();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetSmartSwitchKey();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetUpperCaseFirstChar();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetUpperCaseExcludedForCurrentApp();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetAllowConsonantZFWJ();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickStartConsonant();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetQuickEndConsonant();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetFreeMark();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetRestoreOnEscape();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetCustomEscapeKey();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool PHTV_GetPauseKeyEnabled();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetPauseKey();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetSwitchKeyStatus();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_GetOtherLanguage();

        // Macro API
        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroLoad(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroSave(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_MacroClear();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_MacroCount();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroGetAt(int index, StringBuilder key, int keyCap, StringBuilder value, int valueCap);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroAdd(string key, string value);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_MacroDelete(string key);

        // App list API
        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListLoad(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListSave(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_AppListClear();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_AppListCount();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListGetAt(int index, StringBuilder name, int nameCap, out int lang);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_AppListSet(string name, int lang);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_AppListRemove(string name);

        public class MacroItem
        {
            public string Key { get; set; } = string.Empty;
            public string Value { get; set; } = string.Empty;
        }

        public class AppItem
        {
            public string Name { get; set; } = string.Empty;
            public int Language { get; set; }
            public string LanguageName => Language == 1 ? "Tiếng Việt" : "English";
        }

        private NotifyIcon _trayIcon;
        private bool _suppressEvents = false;
        private readonly ObservableCollection<MacroItem> _macros = new ObservableCollection<MacroItem>();
        private readonly ObservableCollection<AppItem> _apps = new ObservableCollection<AppItem>();
        private string _macroPath = string.Empty;
        private string _appMapPath = string.Empty;
        private DispatcherTimer _trayTimer;

        public MainWindow()
        {
            InitializeComponent();
            InitializeEngine();
            InitializeTrayIcon();
            SetupDataPaths();
            LoadMacroFile();
            LoadAppMapFile();
            LoadSettingsFromEngine();
            RefreshMacroList();
            RefreshAppList();

            MacroGrid.ItemsSource = _macros;
            AppGrid.ItemsSource = _apps;

            if (ComboAppLanguage.Items.Count > 0)
            {
                ComboAppLanguage.SelectedIndex = 0;
            }

            // Hide window on start
            this.Hide();
        }

        private void InitializeEngine()
        {
            try
            {
                PHTV_Init();
                PHTV_InstallHook();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show("Không thể tải PHTVCore.dll: " + ex.Message);
            }
        }

        private void InitializeTrayIcon()
        {
            _trayIcon = new NotifyIcon();
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            _trayIcon.Icon = new System.Drawing.Icon(Path.Combine(baseDir, "Resources", "Images", "icon.ico"));
            _trayIcon.Visible = true;
            _trayIcon.Text = "PHTV - Bộ gõ Tiếng Việt";

            var menu = new ContextMenuStrip();
            menu.Items.Add("Bảng điều khiển...", null, (s, e) => ShowSettings());
            menu.Items.Add("-");
            menu.Items.Add("Chế độ Tiếng Việt", null, (s, e) => ToggleLanguage());
            menu.Items.Add("Telex", null, (s, e) => SetInputMethod(0));
            menu.Items.Add("VNI", null, (s, e) => SetInputMethod(1));
            menu.Items.Add("-");
            menu.Items.Add("Thoát", null, (s, e) =>
            {
                _trayIcon.Visible = false;
                System.Windows.Application.Current.Shutdown();
            });

            _trayIcon.ContextMenuStrip = menu;

            _trayIcon.MouseClick += (s, e) =>
            {
                if (e.Button == MouseButtons.Left)
                {
                    ToggleLanguage();
                }
            };

            _trayTimer = new DispatcherTimer();
            _trayTimer.Interval = TimeSpan.FromSeconds(1);
            _trayTimer.Tick += (s, e) => UpdateTrayIcon();
            _trayTimer.Start();
        }

        private void SetupDataPaths()
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var phtvDir = Path.Combine(appData, "PHTV");
            Directory.CreateDirectory(phtvDir);
            _macroPath = Path.Combine(phtvDir, "macros.dat");
            _appMapPath = Path.Combine(phtvDir, "apps.dat");
        }

        private void LoadMacroFile()
        {
            if (File.Exists(_macroPath))
            {
                PHTV_MacroLoad(_macroPath);
            }
            else
            {
                PHTV_MacroClear();
            }
        }

        private void LoadAppMapFile()
        {
            if (File.Exists(_appMapPath))
            {
                PHTV_AppListLoad(_appMapPath);
            }
            else
            {
                PHTV_AppListClear();
            }
        }

        private void InputMethod_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            if (RadioTelex.IsChecked == true) PHTV_SetInputMethod(0);
            else if (RadioVNI.IsChecked == true) PHTV_SetInputMethod(1);
            PHTV_SaveConfig();
        }

        private void Language_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            if (RadioLangVi.IsChecked == true) PHTV_SetLanguage(1);
            else if (RadioLangEn.IsChecked == true) PHTV_SetLanguage(0);
            PHTV_SaveConfig();
            UpdateTrayIcon();
        }

        private void CodeTable_Changed(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (_suppressEvents) return;
            if (ComboCodeTable.SelectedItem is System.Windows.Controls.ComboBoxItem item &&
                int.TryParse(item.Tag?.ToString(), out var table))
            {
                PHTV_SetCodeTable(table);
                PHTV_SaveConfig();
            }
        }

        private void Feature_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetSpellCheck(ChkSpell.IsChecked == true);
            PHTV_SetModernOrthography(ChkModern.IsChecked == true);
            PHTV_SetQuickTelex(ChkQuickTelex.IsChecked == true);
            PHTV_SetAutoRestoreEnglishWord(ChkAutoRestoreEnglish.IsChecked == true);
            PHTV_SetUpperCaseFirstChar(ChkUppercaseFirstChar.IsChecked == true);
            PHTV_SetAllowConsonantZFWJ(ChkAllowConsonantZFWJ.IsChecked == true);
            PHTV_SetQuickStartConsonant(ChkQuickStartConsonant.IsChecked == true);
            PHTV_SetQuickEndConsonant(ChkQuickEndConsonant.IsChecked == true);
            PHTV_SetFreeMark(ChkFreeMark.IsChecked == true);
            PHTV_SetMacro(ChkMacro.IsChecked == true);
            PHTV_SetMacroInEnglishMode(ChkMacroInEnglish.IsChecked == true);
            PHTV_SetAutoCapsMacro(ChkAutoCapsMacro.IsChecked == true);
            PHTV_SetSmartSwitchKey(ChkSmartSwitchKey.IsChecked == true);
            PHTV_SetFixRecommendBrowser(ChkFixRecommendBrowser.IsChecked == true);
            PHTV_SaveConfig();
        }

        private void Hotkey_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetRestoreOnEscape(ChkRestoreOnEscape.IsChecked == true);
            PHTV_SetPauseKeyEnabled(ChkPauseKeyEnabled.IsChecked == true);
            ApplyHotkeyTextFields();
            PHTV_SaveConfig();
        }

        private void Hotkey_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            if (_suppressEvents) return;
            ApplyHotkeyTextFields();
            PHTV_SaveConfig();
        }

        private void MacroAdd_Click(object sender, RoutedEventArgs e)
        {
            var key = TxtMacroKey.Text.Trim();
            var value = TxtMacroValue.Text.Trim();
            if (string.IsNullOrEmpty(key) || string.IsNullOrEmpty(value)) return;
            if (PHTV_MacroAdd(key, value))
            {
                PHTV_MacroSave(_macroPath);
                RefreshMacroList();
                TxtMacroKey.Text = string.Empty;
                TxtMacroValue.Text = string.Empty;
            }
        }

        private void MacroRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is string key)
            {
                if (PHTV_MacroDelete(key))
                {
                    PHTV_MacroSave(_macroPath);
                    RefreshMacroList();
                }
            }
        }

        private void AppAdd_Click(object sender, RoutedEventArgs e)
        {
            var name = TxtAppName.Text.Trim();
            if (string.IsNullOrEmpty(name)) return;
            if (ComboAppLanguage.SelectedItem is System.Windows.Controls.ComboBoxItem item &&
                int.TryParse(item.Tag?.ToString(), out var lang))
            {
                PHTV_AppListSet(name, lang);
                PHTV_AppListSave(_appMapPath);
                RefreshAppList();
                TxtAppName.Text = string.Empty;
            }
        }

        private void AppRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is string name)
            {
                if (PHTV_AppListRemove(name))
                {
                    PHTV_AppListSave(_appMapPath);
                    RefreshAppList();
                }
            }
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            this.Hide();
        }

        private void Reset_Click(object sender, RoutedEventArgs e)
        {
            PHTV_ResetConfig();
            LoadSettingsFromEngine();
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            e.Cancel = true;
            this.Hide();
        }

        private void ShowSettings()
        {
            this.Show();
            this.Activate();
        }

        private void ToggleLanguage()
        {
            var lang = PHTV_GetLanguage();
            PHTV_SetLanguage(lang == 1 ? 0 : 1);
            PHTV_SaveConfig();
            LoadSettingsFromEngine();
            UpdateTrayIcon();
        }

        private void SetInputMethod(int method)
        {
            PHTV_SetInputMethod(method);
            PHTV_SaveConfig();
            LoadSettingsFromEngine();
        }

        private void UpdateTrayIcon()
        {
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var iconName = PHTV_GetLanguage() == 1 ? "vie.ico" : "eng.ico";
            var iconPath = Path.Combine(baseDir, "Resources", "Images", iconName);
            if (File.Exists(iconPath))
            {
                _trayIcon.Icon = new System.Drawing.Icon(iconPath);
            }
        }

        private void LoadSettingsFromEngine()
        {
            _suppressEvents = true;
            try
            {
                RadioLangVi.IsChecked = PHTV_GetLanguage() == 1;
                RadioLangEn.IsChecked = PHTV_GetLanguage() == 0;
                RadioTelex.IsChecked = PHTV_GetInputMethod() == 0;
                RadioVNI.IsChecked = PHTV_GetInputMethod() == 1;

                var codeTable = PHTV_GetCodeTable();
                foreach (System.Windows.Controls.ComboBoxItem item in ComboCodeTable.Items)
                {
                    if (int.TryParse(item.Tag?.ToString(), out var tagValue) && tagValue == codeTable)
                    {
                        ComboCodeTable.SelectedItem = item;
                        break;
                    }
                }

                ChkSpell.IsChecked = PHTV_GetSpellCheck();
                ChkModern.IsChecked = PHTV_GetModernOrthography();
                ChkQuickTelex.IsChecked = PHTV_GetQuickTelex();
                ChkAutoRestoreEnglish.IsChecked = PHTV_GetAutoRestoreEnglishWord();
                ChkUppercaseFirstChar.IsChecked = PHTV_GetUpperCaseFirstChar();
                ChkAllowConsonantZFWJ.IsChecked = PHTV_GetAllowConsonantZFWJ();
                ChkQuickStartConsonant.IsChecked = PHTV_GetQuickStartConsonant();
                ChkQuickEndConsonant.IsChecked = PHTV_GetQuickEndConsonant();
                ChkFreeMark.IsChecked = PHTV_GetFreeMark();

                ChkMacro.IsChecked = PHTV_GetMacro();
                ChkMacroInEnglish.IsChecked = PHTV_GetMacroInEnglishMode();
                ChkAutoCapsMacro.IsChecked = PHTV_GetAutoCapsMacro();

                ChkSmartSwitchKey.IsChecked = PHTV_GetSmartSwitchKey();
                ChkFixRecommendBrowser.IsChecked = PHTV_GetFixRecommendBrowser();

                ChkRestoreOnEscape.IsChecked = PHTV_GetRestoreOnEscape();
                TxtCustomEscapeKey.Text = PHTV_GetCustomEscapeKey().ToString();
                ChkPauseKeyEnabled.IsChecked = PHTV_GetPauseKeyEnabled();
                TxtPauseKey.Text = PHTV_GetPauseKey().ToString();
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void ApplyHotkeyTextFields()
        {
            if (int.TryParse(TxtCustomEscapeKey.Text, out var escKey))
            {
                PHTV_SetCustomEscapeKey(escKey);
            }

            if (int.TryParse(TxtPauseKey.Text, out var pauseKey))
            {
                PHTV_SetPauseKey(pauseKey);
            }
        }

        private void RefreshMacroList()
        {
            _macros.Clear();
            int count = PHTV_MacroCount();
            for (int i = 0; i < count; i++)
            {
                var keyBuf = new StringBuilder(256);
                var valBuf = new StringBuilder(1024);
                if (PHTV_MacroGetAt(i, keyBuf, keyBuf.Capacity, valBuf, valBuf.Capacity))
                {
                    _macros.Add(new MacroItem { Key = keyBuf.ToString(), Value = valBuf.ToString() });
                }
            }
        }

        private void RefreshAppList()
        {
            _apps.Clear();
            int count = PHTV_AppListCount();
            for (int i = 0; i < count; i++)
            {
                var nameBuf = new StringBuilder(260);
                if (PHTV_AppListGetAt(i, nameBuf, nameBuf.Capacity, out int lang))
                {
                    _apps.Add(new AppItem { Name = nameBuf.ToString(), Language = lang });
                }
            }
        }
    }
}
