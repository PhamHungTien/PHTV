using System;
using System.Collections.ObjectModel;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using PHTV.UI.Utilities;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI.Pages
{
    public partial class AppsPage : PhtvPageBase
    {
        public class AppItem
        {
            public string Name { get; set; } = string.Empty;
            public int Language { get; set; }
            public string LanguageName => Language == 1 ? "Tiếng Việt" : "English";
        }

        private bool _suppressEvents;
        private readonly ObservableCollection<AppItem> _apps = new();
        private readonly ObservableCollection<string> _runningApps = new();

        public AppsPage()
        {
            InitializeComponent();
            AppGrid.ItemsSource = _apps;
            RunningAppList.ItemsSource = _runningApps;
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            Host?.RegisterPage(this);
            LoadFromEngine();
            RefreshAppList();
            if (ComboAppLanguage.Items.Count > 0)
            {
                ComboAppLanguage.SelectedIndex = 0;
            }
        }

        public void LoadFromEngine()
        {
            _suppressEvents = true;
            try
            {
                ChkSmartSwitchKey.IsChecked = PHTV_GetSmartSwitchKey();
                ChkRememberCode.IsChecked = PHTV_GetRememberCode();
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void AppsFeature_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetSmartSwitchKey(ChkSmartSwitchKey.IsChecked == true);
            PHTV_SetRememberCode(ChkRememberCode.IsChecked == true);
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void AppAdd_Click(object sender, RoutedEventArgs e)
        {
            var name = TxtAppName.Text.Trim();
            if (string.IsNullOrEmpty(name)) return;
            if (ComboAppLanguage.SelectedItem is ComboBoxItem item &&
                int.TryParse(item.Tag?.ToString(), out var lang))
            {
                PHTV_AppListSet(name, lang);
                PHTV_AppListSave(PhtvPaths.AppMapPath);
                RefreshAppList();
                TxtAppName.Text = string.Empty;
            }
        }

        private void AppRemove_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string name)
            {
                if (PHTV_AppListRemove(name))
                {
                    PHTV_AppListSave(PhtvPaths.AppMapPath);
                    RefreshAppList();
                }
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
                PHTV_AppListSave(PhtvPaths.AppMapPath);
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

        private void AppRunning_Selected(object sender, SelectionChangedEventArgs e)
        {
            if (RunningAppList.SelectedItem is string name)
            {
                TxtAppName.Text = name;
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
