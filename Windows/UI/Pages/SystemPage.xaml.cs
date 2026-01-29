using System;
using System.Windows;
using PHTV.UI;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI.Pages
{
    public partial class SystemPage : PhtvPageBase
    {
        private bool _suppressEvents;

        public SystemPage()
        {
            InitializeComponent();
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            Host?.RegisterPage(this);
            LoadFromEngine();
        }

        public void LoadFromEngine()
        {
            _suppressEvents = true;
            try
            {
                ChkFixRecommendBrowser.IsChecked = PHTV_GetFixRecommendBrowser();
                ChkOtherLanguage.IsChecked = PHTV_GetOtherLanguage() != 0;
                ChkSendKeyStepByStep.IsChecked = PHTV_GetSendKeyStepByStep();
                ChkPerformLayoutCompat.IsChecked = PHTV_GetPerformLayoutCompat();
                ChkRunOnStartup.IsChecked = MainWindow.IsRunOnStartupEnabled();
            }
            finally
            {
                _suppressEvents = false;
            }
        }

        private void SystemFeature_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetFixRecommendBrowser(ChkFixRecommendBrowser.IsChecked == true);
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void System_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetOtherLanguage(ChkOtherLanguage.IsChecked == true ? 1 : 0);
            Host?.ScheduleSave();
        }

        private void Compatibility_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetSendKeyStepByStep(ChkSendKeyStepByStep.IsChecked == true);
            PHTV_SetPerformLayoutCompat(ChkPerformLayoutCompat.IsChecked == true);
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void RunOnStartup_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            MainWindow.SetRunOnStartup(ChkRunOnStartup.IsChecked == true);
            Host?.UpdateTrayMenuState();
        }

        private void Reset_Click(object sender, RoutedEventArgs e)
        {
            PHTV_ResetConfig();
            Host?.ReloadSettings();
            Host?.UpdateTrayMenuState();
        }
    }
}
