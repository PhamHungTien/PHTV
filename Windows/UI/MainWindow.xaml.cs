using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Microsoft.Win32;
using System.Drawing; // For Icon
using System.Windows.Forms; // For NotifyIcon

namespace PHTV.UI
{
    public partial class MainWindow : Window
    {
        // Import C++ DLL
        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_Init(string resourceDir);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_InstallHook();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_UninstallHook();

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

        // Uppercase excluded apps API
        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedLoad(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedSave(string path);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_UpperExcludedClear();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int PHTV_UpperExcludedCount();

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedGetAt(int index, StringBuilder name, int nameCap);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern void PHTV_UpperExcludedAdd(string name);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern bool PHTV_UpperExcludedRemove(string name);

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

        public class UpperExcludedItem
        {
            public string Name { get; set; } = string.Empty;
        }

        private bool _suppressEvents = false;
        private readonly ObservableCollection<MacroItem> _macros = new ObservableCollection<MacroItem>();
        private readonly ObservableCollection<AppItem> _apps = new ObservableCollection<AppItem>();
        private readonly ObservableCollection<UpperExcludedItem> _upperExcludedApps = new ObservableCollection<UpperExcludedItem>();
        private readonly ObservableCollection<string> _runningApps = new ObservableCollection<string>();
        private string _macroPath = string.Empty;
        private string _appMapPath = string.Empty;
        private string _upperExcludedPath = string.Empty;
        private const int SwitchKeyMask = 0xFF;
        private const int SwitchKeyNoKey = 0xFE;
        private const int SwitchMaskControl = 0x100;
        private const int SwitchMaskAlt = 0x200;
        private const int SwitchMaskWin = 0x400;
        private const int SwitchMaskShift = 0x800;
        private const int SwitchMaskFn = 0x1000;
        private const int SwitchMaskBeep = 0x8000;

        private NotifyIcon _notifyIcon;

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

            InitializeEngine();
            Log("InitializeEngine done");
            
            SetupDataPaths();

            LoadMacroFile();
            LoadAppMapFile();
            LoadUpperExcludedFile();
            LoadSettingsFromEngine();
            RefreshMacroList();
            RefreshAppList();
            RefreshUpperExcludedList();

            MacroGrid.ItemsSource = _macros;
            AppGrid.ItemsSource = _apps;
            RunningAppList.ItemsSource = _runningApps;
            UpperExcludedGrid.ItemsSource = _upperExcludedApps;
            UpperRunningAppList.ItemsSource = _runningApps;

            if (ComboAppLanguage.Items.Count > 0)
            {
                ComboAppLanguage.SelectedIndex = 0;
            }

            InitializeTrayIcon();
        }

                private void InitializeTrayIcon()
                {
                    _notifyIcon = new NotifyIcon
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
        
                    // Set initial icon
                    UpdateTrayIconState();
        
                    // Context Menu
                    ContextMenuStrip contextMenu = new ContextMenuStrip();
                    
                    var showItem = contextMenu.Items.Add("Cài đặt...");
                    showItem.Click += (s, e) => ShowWindow();
                    showItem.Font = new Font(showItem.Font, System.Drawing.FontStyle.Bold);
        
                    contextMenu.Items.Add(new ToolStripSeparator());
        
                    var exitItem = contextMenu.Items.Add("Thoát");
                    exitItem.Click += (s, e) => {
                        _notifyIcon.Visible = false;
                        PHTV_UninstallHook();
                        System.Windows.Application.Current.Shutdown();
                    };
        
                    _notifyIcon.ContextMenuStrip = contextMenu;
                    
                    // Handle Mouse Click
                    _notifyIcon.MouseClick += (s, e) => {
                        if (e.Button == MouseButtons.Left)
                        {
                            // Toggle Language on Left Click
                            int currentLang = PHTV_GetLanguage();
                            int newLang = (currentLang == 1) ? 0 : 1;
                            PHTV_SetLanguage(newLang);
                            PHTV_SaveConfig();
                            
                            // Update UI if visible
                            if (this.IsVisible)
                            {
                                RadioLangVi.IsChecked = newLang == 1;
                                RadioLangEn.IsChecked = newLang == 0;
                            }
                            
                            UpdateTrayIconState();
                        }
                    };
                    
                    _notifyIcon.DoubleClick += (s, e) => ShowWindow();
                }
        
                private void UpdateTrayIconState()
                {
                    if (_notifyIcon == null) return;
        
                    string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                    string imgDir = Path.Combine(appData, "PHTV", "Data", "Images");
                    
                    int lang = PHTV_GetLanguage();
                    string iconName = (lang == 1) ? "vie.ico" : "eng.ico";
                    string iconPath = Path.Combine(imgDir, iconName);
        
                    if (File.Exists(iconPath))
                    {
                        _notifyIcon.Icon = new Icon(iconPath);
                        _notifyIcon.Text = (lang == 1) ? "PHTV - Tiếng Việt" : "PHTV - English";
                    }
                    else
                    {
                        // Fallback
                        _notifyIcon.Icon = SystemIcons.Application;
                    }
                }
        private void ShowWindow()
        {
            this.Show();
            this.WindowState = WindowState.Normal;
            this.Activate();
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

                ExtractResource("PHTV.UI.Resources.Dictionaries.vi_dict.bin", Path.Combine(dictDir, "vi_dict.bin"));
                ExtractResource("PHTV.UI.Resources.Dictionaries.en_dict.bin", Path.Combine(dictDir, "en_dict.bin"));

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

        private void SetupDataPaths()
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var phtvDir = Path.Combine(appData, "PHTV");
            Directory.CreateDirectory(phtvDir);
            _macroPath = Path.Combine(phtvDir, "macros.dat");
            _appMapPath = Path.Combine(phtvDir, "apps.dat");
            _upperExcludedPath = Path.Combine(phtvDir, "upper_excluded.dat");
        }

        private void LoadMacroFile()
        {
            if (File.Exists(_macroPath)) PHTV_MacroLoad(_macroPath);
            else PHTV_MacroClear();
        }

        private void LoadAppMapFile()
        {
            if (File.Exists(_appMapPath)) PHTV_AppListLoad(_appMapPath);
            else PHTV_AppListClear();
        }

        private void LoadUpperExcludedFile()
        {
            if (File.Exists(_upperExcludedPath)) PHTV_UpperExcludedLoad(_upperExcludedPath);
            else PHTV_UpperExcludedClear();
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
            UpdateTrayIconState();
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

        private void System_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetOtherLanguage(ChkOtherLanguage.IsChecked == true ? 1 : 0);
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

        private void SwitchHotkey_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            ApplySwitchHotkeyStatus();
            PHTV_SaveConfig();
        }

        private void SwitchKey_CaptureKey(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (_suppressEvents) return;
            if (sender is not System.Windows.Controls.TextBox textBox) return;
            int vk = GetVirtualKey(e);
            if (vk <= 0) return;
            SetSwitchKeyText(textBox, vk);
            ApplySwitchHotkeyStatus();
            PHTV_SaveConfig();
            e.Handled = true;
        }

        private void SwitchKey_NoKey_Click(object sender, RoutedEventArgs e)
        {
            SetSwitchKeyText(TxtSwitchKey, SwitchKeyNoKey);
            ApplySwitchHotkeyStatus();
            PHTV_SaveConfig();
        }

        private void Hotkey_CaptureKey(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (_suppressEvents) return;
            if (sender is not System.Windows.Controls.TextBox textBox) return;

            int vk = GetVirtualKey(e);
            if (vk <= 0) return;
            SetHotkeyText(textBox, vk);
            ApplyHotkeyTextFields();
            PHTV_SaveConfig();
            e.Handled = true;
        }

        private void Hotkey_RecordEscape_Click(object sender, RoutedEventArgs e)
        {
            TxtCustomEscapeKey.Focus();
            TxtCustomEscapeKey.SelectAll();
        }

        private void Hotkey_RecordPause_Click(object sender, RoutedEventArgs e)
        {
            TxtPauseKey.Focus();
            TxtPauseKey.SelectAll();
        }


        private void MacroImport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "PHTV Macro (*.dat)|*.dat|All files|*.*",
                CheckFileExists = true
            };
            if (dialog.ShowDialog() != true) return;
            if (PHTV_MacroLoad(dialog.FileName))
            {
                PHTV_MacroSave(_macroPath);
                RefreshMacroList();
            }
            else
            {
                System.Windows.MessageBox.Show("Không thể import macro.");
            }
        }

        private void MacroExport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.SaveFileDialog
            {
                Filter = "PHTV Macro (*.dat)|*.dat|All files|*.*",
                FileName = "macros.dat"
            };
            if (dialog.ShowDialog() != true) return;
            if (!PHTV_MacroSave(dialog.FileName))
            {
                System.Windows.MessageBox.Show("Không thể export macro.");
            }
        }

        private void MacroClear_Click(object sender, RoutedEventArgs e)
        {
            PHTV_MacroClear();
            PHTV_MacroSave(_macroPath);
            RefreshMacroList();
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

        private void UpperExcludedAdd_Click(object sender, RoutedEventArgs e)
        {
            var name = TxtUpperExcludedName.Text.Trim();
            if (string.IsNullOrEmpty(name)) return;
            PHTV_UpperExcludedAdd(name);
            PHTV_UpperExcludedSave(_upperExcludedPath);
            RefreshUpperExcludedList();
            TxtUpperExcludedName.Text = string.Empty;
        }

        private void UpperExcludedRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is string name)
            {
                if (PHTV_UpperExcludedRemove(name))
                {
                    PHTV_UpperExcludedSave(_upperExcludedPath);
                    RefreshUpperExcludedList();
                }
            }
        }

        private void UpperExcludedImport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "PHTV Upper Excluded (*.dat)|*.dat|All files|*.*",
                CheckFileExists = true
            };
            if (dialog.ShowDialog() != true) return;
            if (PHTV_UpperExcludedLoad(dialog.FileName))
            {
                PHTV_UpperExcludedSave(_upperExcludedPath);
                RefreshUpperExcludedList();
            }
            else
            {
                System.Windows.MessageBox.Show("Không thể import danh sách.");
            }
        }

        private void UpperExcludedExport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.SaveFileDialog
            {
                Filter = "PHTV Upper Excluded (*.dat)|*.dat|All files|*.*",
                FileName = "upper_excluded.dat"
            };
            if (dialog.ShowDialog() != true) return;
            if (!PHTV_UpperExcludedSave(dialog.FileName))
            {
                System.Windows.MessageBox.Show("Không thể export danh sách.");
            }
        }

        private void UpperExcludedClear_Click(object sender, RoutedEventArgs e)
        {
            PHTV_UpperExcludedClear();
            PHTV_UpperExcludedSave(_upperExcludedPath);
            RefreshUpperExcludedList();
        }

        private void UpperExcludedDetect_Click(object sender, RoutedEventArgs e)
        {
            RefreshRunningApps();
            if (_runningApps.Count == 0)
            {
                System.Windows.MessageBox.Show("Không tìm thấy ứng dụng đang chạy.");
            }
        }

        private void UpperRunning_Selected(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (UpperRunningAppList.SelectedItem is string name)
            {
                TxtUpperExcludedName.Text = name;
            }
        }

        private void AppImport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "PHTV App Map (*.dat)|*.dat|All files|*.*",
                CheckFileExists = true
            };
            if (dialog.ShowDialog() != true) return;
            if (PHTV_AppListLoad(dialog.FileName))
            {
                PHTV_AppListSave(_appMapPath);
                RefreshAppList();
            }
            else
            {
                System.Windows.MessageBox.Show("Không thể import app map.");
            }
        }

        private void AppExport_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.SaveFileDialog
            {
                Filter = "PHTV App Map (*.dat)|*.dat|All files|*.*",
                FileName = "apps.dat"
            };
            if (dialog.ShowDialog() != true) return;
            if (!PHTV_AppListSave(dialog.FileName))
            {
                System.Windows.MessageBox.Show("Không thể export app map.");
            }
        }

        private void AppDetect_Click(object sender, RoutedEventArgs e)
        {
            RefreshRunningApps();
            if (_runningApps.Count == 0)
            {
                System.Windows.MessageBox.Show("Không tìm thấy ứng dụng đang chạy.");
            }
        }

        private void AppRunning_Selected(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (RunningAppList.SelectedItem is string name)
            {
                TxtAppName.Text = name;
            }
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void Reset_Click(object sender, RoutedEventArgs e)
        {
            PHTV_ResetConfig();
            LoadSettingsFromEngine();
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
                ChkOtherLanguage.IsChecked = PHTV_GetOtherLanguage() != 0;

                ChkRestoreOnEscape.IsChecked = PHTV_GetRestoreOnEscape();
                SetHotkeyText(TxtCustomEscapeKey, PHTV_GetCustomEscapeKey());
                ChkPauseKeyEnabled.IsChecked = PHTV_GetPauseKeyEnabled();
                SetHotkeyText(TxtPauseKey, PHTV_GetPauseKey());

                LoadSwitchHotkeyStatus(PHTV_GetSwitchKeyStatus());
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void ApplyHotkeyTextFields()
        {
            if (TryGetHotkeyValue(TxtCustomEscapeKey, out var escKey))
            {
                PHTV_SetCustomEscapeKey(escKey);
            }

            if (TryGetHotkeyValue(TxtPauseKey, out var pauseKey))
            {
                PHTV_SetPauseKey(pauseKey);
            }
        }

        private void LoadSwitchHotkeyStatus(int status)
        {
            int key = status & SwitchKeyMask;
            ChkSwitchCtrl.IsChecked = (status & SwitchMaskControl) != 0;
            ChkSwitchAlt.IsChecked = (status & SwitchMaskAlt) != 0;
            ChkSwitchWin.IsChecked = (status & SwitchMaskWin) != 0;
            ChkSwitchShift.IsChecked = (status & SwitchMaskShift) != 0;
            ChkSwitchBeep.IsChecked = (status & SwitchMaskBeep) != 0;

            if (key == 0)
            {
                TxtSwitchKey.Text = string.Empty;
                TxtSwitchKey.Tag = null;
            }
            else
            {
                SetSwitchKeyText(TxtSwitchKey, key);
            }
        }

        private void ApplySwitchHotkeyStatus()
        {
            int key = 0;
            if (TryGetSwitchKeyValue(TxtSwitchKey, out var value))
            {
                key = value;
            }

            bool ctrl = ChkSwitchCtrl.IsChecked == true;
            bool alt = ChkSwitchAlt.IsChecked == true;
            bool shift = ChkSwitchShift.IsChecked == true;
            bool win = ChkSwitchWin.IsChecked == true;
            bool beep = ChkSwitchBeep.IsChecked == true;

            if (key == 0 && !(ctrl || alt || shift || win))
            {
                PHTV_SetSwitchKeyStatus(0);
                return;
            }

            if (key == 0)
            {
                key = SwitchKeyNoKey;
            }
            else if (key == SwitchKeyNoKey && !(ctrl || alt || shift || win))
            {
                PHTV_SetSwitchKeyStatus(0);
                return;
            }

            int status = key & SwitchKeyMask;
            if (ctrl) status |= SwitchMaskControl;
            if (alt) status |= SwitchMaskAlt;
            if (win) status |= SwitchMaskWin;
            if (shift) status |= SwitchMaskShift;
            if (beep) status |= SwitchMaskBeep;
            PHTV_SetSwitchKeyStatus(status);
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

        private void RefreshUpperExcludedList()
        {
            _upperExcludedApps.Clear();
            int count = PHTV_UpperExcludedCount();
            for (int i = 0; i < count; i++)
            {
                var nameBuf = new StringBuilder(260);
                if (PHTV_UpperExcludedGetAt(i, nameBuf, nameBuf.Capacity))
                {
                    _upperExcludedApps.Add(new UpperExcludedItem { Name = nameBuf.ToString() });
                }
            }
        }

        private void RefreshRunningApps()
        {
            var names = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var proc in Process.GetProcesses())
            {
                try
                {
                    string name = string.Empty;
                    try
                    {
                        if (proc.MainModule != null && !string.IsNullOrEmpty(proc.MainModule.FileName))
                        {
                            name = Path.GetFileName(proc.MainModule.FileName);
                        }
                    }
                    catch
                    {
                        // Access denied for some system processes.
                    }

                    if (string.IsNullOrWhiteSpace(name) && !string.IsNullOrWhiteSpace(proc.ProcessName))
                    {
                        name = proc.ProcessName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
                            ? proc.ProcessName
                            : proc.ProcessName + ".exe";
                    }

                    if (!string.IsNullOrWhiteSpace(name) && seen.Add(name))
                    {
                        names.Add(name);
                    }
                }
                finally
                {
                    proc.Dispose();
                }
            }

            names.Sort(StringComparer.OrdinalIgnoreCase);
            _runningApps.Clear();
            foreach (var name in names)
            {
                _runningApps.Add(name);
            }
        }

        private static int GetVirtualKey(System.Windows.Input.KeyEventArgs e)
        {
            var key = e.Key == Key.System ? e.SystemKey : e.Key;
            if (key == Key.ImeProcessed)
            {
                key = e.ImeProcessedKey;
            }
            return KeyInterop.VirtualKeyFromKey(key);
        }

        private static void SetHotkeyText(System.Windows.Controls.TextBox textBox, int vk)
        {
            textBox.Tag = vk;
            textBox.Text = FormatHotkeyText(vk);
        }

        private static string FormatHotkeyText(int vk)
        {
            if (vk <= 0) return string.Empty;
            var key = KeyInterop.KeyFromVirtualKey(vk);
            if (key == Key.None) return vk.ToString();
            return $"{key} ({vk})";
        }

        private static bool TryGetHotkeyValue(System.Windows.Controls.TextBox textBox, out int value)
        {
            if (textBox.Tag is int tagValue)
            {
                value = tagValue;
                return true;
            }

            if (int.TryParse(textBox.Text, out value))
            {
                return true;
            }

            value = 0;
            return false;
        }

        private static void SetSwitchKeyText(System.Windows.Controls.TextBox textBox, int vk)
        {
            textBox.Tag = vk;
            textBox.Text = FormatSwitchKeyText(vk);
        }

        private static string FormatSwitchKeyText(int vk)
        {
            if (vk == SwitchKeyNoKey) return "Không (modifier-only)";
            return FormatHotkeyText(vk);
        }

        private static bool TryGetSwitchKeyValue(System.Windows.Controls.TextBox textBox, out int value)
        {
            if (textBox.Tag is int tagValue)
            {
                value = tagValue;
                return true;
            }

            if (int.TryParse(textBox.Text, out value))
            {
                return true;
            }

            value = 0;
            return false;
        }

        private void SwitchKey_Record_Click(object sender, RoutedEventArgs e)
        {
            TxtSwitchKey.Focus();
            TxtSwitchKey.SelectAll();
        }

        private void NavList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (NavList.SelectedItem is ListBoxItem item && item.Tag is string viewName)
            {
                // Ensure views are initialized before accessing them
                if (View_Typing == null) return;

                // Hide all views first
                View_Typing.Visibility = Visibility.Collapsed;
                View_Hotkeys.Visibility = Visibility.Collapsed;
                View_Macro.Visibility = Visibility.Collapsed;
                View_Apps.Visibility = Visibility.Collapsed;
                View_System.Visibility = Visibility.Collapsed;
                View_About.Visibility = Visibility.Collapsed;

                // Show selected view
                switch (viewName)
                {
                    case "View_Typing":
                        View_Typing.Visibility = Visibility.Visible;
                        break;
                    case "View_Hotkeys":
                        View_Hotkeys.Visibility = Visibility.Visible;
                        break;
                    case "View_Macro":
                        View_Macro.Visibility = Visibility.Visible;
                        break;
                    case "View_Apps":
                        View_Apps.Visibility = Visibility.Visible;
                        break;
                    case "View_System":
                        View_System.Visibility = Visibility.Visible;
                        break;
                    case "View_About":
                        View_About.Visibility = Visibility.Visible;
                        break;
                }
            }
        }
    }
}
