using System;
using System.Collections.ObjectModel;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using PHTV.UI.Utilities;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI.Pages
{
    public partial class TypingPage : PhtvPageBase
    {
        public class UpperExcludedItem
        {
            public string Name { get; set; } = string.Empty;
        }

        private bool _suppressEvents;
        private readonly ObservableCollection<UpperExcludedItem> _upperExcludedApps = new();
        private readonly ObservableCollection<string> _runningApps = new();

        public TypingPage()
        {
            InitializeComponent();
            UpperExcludedGrid.ItemsSource = _upperExcludedApps;
            UpperRunningAppList.ItemsSource = _runningApps;
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            Host?.RegisterPage(this);
            LoadFromEngine();
            RefreshUpperExcludedList();
        }

        public void LoadFromEngine()
        {
            _suppressEvents = true;
            try
            {
                RadioLangVi.IsChecked = PHTV_GetLanguage() == 1;
                RadioLangEn.IsChecked = PHTV_GetLanguage() == 0;
                RadioTelex.IsChecked = PHTV_GetInputMethod() == 0;
                RadioVNI.IsChecked = PHTV_GetInputMethod() == 1;
                RadioSimpleTelex1.IsChecked = PHTV_GetInputMethod() == 2;
                RadioSimpleTelex2.IsChecked = PHTV_GetInputMethod() == 3;

                var codeTable = PHTV_GetCodeTable();
                foreach (ComboBoxItem item in ComboCodeTable.Items)
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
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void InputMethod_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            if (RadioTelex.IsChecked == true) PHTV_SetInputMethod(0);
            else if (RadioVNI.IsChecked == true) PHTV_SetInputMethod(1);
            else if (RadioSimpleTelex1.IsChecked == true) PHTV_SetInputMethod(2);
            else if (RadioSimpleTelex2.IsChecked == true) PHTV_SetInputMethod(3);
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void Language_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            if (RadioLangVi.IsChecked == true) PHTV_SetLanguage(1);
            else if (RadioLangEn.IsChecked == true) PHTV_SetLanguage(0);
            Host?.ScheduleSave();
            Host?.UpdateTrayIconState();
            Host?.UpdateTrayMenuState();
        }

        private void CodeTable_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (_suppressEvents) return;
            if (ComboCodeTable.SelectedItem is ComboBoxItem item &&
                int.TryParse(item.Tag?.ToString(), out var table))
            {
                PHTV_SetCodeTable(table);
                Host?.ScheduleSave();
                Host?.UpdateTrayMenuState();
            }
        }

        private void TypingFeature_Changed(object sender, RoutedEventArgs e)
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
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void UpperExcludedAdd_Click(object sender, RoutedEventArgs e)
        {
            var name = TxtUpperExcludedName.Text.Trim();
            if (string.IsNullOrEmpty(name)) return;
            PHTV_UpperExcludedAdd(name);
            PHTV_UpperExcludedSave(PhtvPaths.UpperExcludedPath);
            RefreshUpperExcludedList();
            TxtUpperExcludedName.Text = string.Empty;
        }

        private void UpperExcludedRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string name)
            {
                if (PHTV_UpperExcludedRemove(name))
                {
                    PHTV_UpperExcludedSave(PhtvPaths.UpperExcludedPath);
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
                PHTV_UpperExcludedSave(PhtvPaths.UpperExcludedPath);
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
            PHTV_UpperExcludedSave(PhtvPaths.UpperExcludedPath);
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

        private void UpperRunning_Selected(object sender, SelectionChangedEventArgs e)
        {
            if (UpperRunningAppList.SelectedItem is string name)
            {
                TxtUpperExcludedName.Text = name;
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
            _runningApps.Clear();
            foreach (var name in ProcessUtils.GetRunningAppNames())
            {
                _runningApps.Add(name);
            }
        }
    }
}
