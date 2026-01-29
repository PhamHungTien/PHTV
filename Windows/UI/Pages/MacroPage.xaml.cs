using System;
using System.Collections.ObjectModel;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using PHTV.UI.Utilities;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI.Pages
{
    public partial class MacroPage : PhtvPageBase
    {
        public class MacroItem
        {
            public string Key { get; set; } = string.Empty;
            public string Value { get; set; } = string.Empty;
        }

        private bool _suppressEvents;
        private readonly ObservableCollection<MacroItem> _macros = new();

        public MacroPage()
        {
            InitializeComponent();
            MacroGrid.ItemsSource = _macros;
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            Host?.RegisterPage(this);
            LoadFromEngine();
            RefreshMacroList();
        }

        public void LoadFromEngine()
        {
            _suppressEvents = true;
            try
            {
                ChkMacro.IsChecked = PHTV_GetMacro();
                ChkMacroInEnglish.IsChecked = PHTV_GetMacroInEnglishMode();
                ChkAutoCapsMacro.IsChecked = PHTV_GetAutoCapsMacro();
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void MacroFeature_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetMacro(ChkMacro.IsChecked == true);
            PHTV_SetMacroInEnglishMode(ChkMacroInEnglish.IsChecked == true);
            PHTV_SetAutoCapsMacro(ChkAutoCapsMacro.IsChecked == true);
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
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
                PHTV_MacroSave(PhtvPaths.MacroPath);
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
            PHTV_MacroSave(PhtvPaths.MacroPath);
            RefreshMacroList();
        }

        private void MacroAdd_Click(object sender, RoutedEventArgs e)
        {
            var key = TxtMacroKey.Text.Trim();
            var value = TxtMacroValue.Text.Trim();
            if (string.IsNullOrEmpty(key) || string.IsNullOrEmpty(value)) return;
            if (PHTV_MacroAdd(key, value))
            {
                PHTV_MacroSave(PhtvPaths.MacroPath);
                RefreshMacroList();
                TxtMacroKey.Text = string.Empty;
                TxtMacroValue.Text = string.Empty;
            }
        }

        private void MacroRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string key)
            {
                if (PHTV_MacroDelete(key))
                {
                    PHTV_MacroSave(PhtvPaths.MacroPath);
                    RefreshMacroList();
                }
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
    }
}
