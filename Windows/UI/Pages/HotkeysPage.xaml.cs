using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI.Pages
{
    public partial class HotkeysPage : PhtvPageBase
    {
        private const int SwitchKeyMask = 0xFF;
        private const int SwitchKeyNoKey = 0xFE;
        private const int SwitchMaskControl = 0x100;
        private const int SwitchMaskAlt = 0x200;
        private const int SwitchMaskWin = 0x400;
        private const int SwitchMaskShift = 0x800;
        private const int SwitchMaskBeep = 0x8000;

        private bool _suppressEvents;

        public HotkeysPage()
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

        internal void ApplySwitchBeep(bool enable)
        {
            _suppressEvents = true;
            ChkSwitchBeep.IsChecked = enable;
            _suppressEvents = false;
        }

        private void Hotkey_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            PHTV_SetRestoreOnEscape(ChkRestoreOnEscape.IsChecked == true);
            PHTV_SetPauseKeyEnabled(ChkPauseKeyEnabled.IsChecked == true);
            ApplyHotkeyTextFields();
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void SwitchHotkey_Changed(object sender, RoutedEventArgs e)
        {
            if (_suppressEvents) return;
            ApplySwitchHotkeyStatus();
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void SwitchKey_CaptureKey(object sender, KeyEventArgs e)
        {
            if (_suppressEvents) return;
            if (sender is not TextBox textBox) return;
            int vk = GetVirtualKey(e);
            if (vk <= 0) return;
            SetSwitchKeyText(textBox, vk);
            ApplySwitchHotkeyStatus();
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
            e.Handled = true;
        }

        private void SwitchKey_NoKey_Click(object sender, RoutedEventArgs e)
        {
            SetSwitchKeyText(TxtSwitchKey, SwitchKeyNoKey);
            ApplySwitchHotkeyStatus();
            Host?.ScheduleSave();
            Host?.UpdateTrayMenuState();
        }

        private void SwitchKey_Record_Click(object sender, RoutedEventArgs e)
        {
            TxtSwitchKey.Focus();
            TxtSwitchKey.SelectAll();
        }

        private void Hotkey_CaptureKey(object sender, KeyEventArgs e)
        {
            if (_suppressEvents) return;
            if (sender is not TextBox textBox) return;

            int vk = GetVirtualKey(e);
            if (vk <= 0) return;
            SetHotkeyText(textBox, vk);
            ApplyHotkeyTextFields();
            Host?.ScheduleSave();
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

        private static int GetVirtualKey(KeyEventArgs e)
        {
            var key = e.Key == Key.System ? e.SystemKey : e.Key;
            if (key == Key.ImeProcessed)
            {
                key = e.ImeProcessedKey;
            }
            return KeyInterop.VirtualKeyFromKey(key);
        }

        private static void SetHotkeyText(TextBox textBox, int vk)
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

        private static bool TryGetHotkeyValue(TextBox textBox, out int value)
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

        private static void SetSwitchKeyText(TextBox textBox, int vk)
        {
            textBox.Tag = vk;
            textBox.Text = FormatSwitchKeyText(vk);
        }

        private static string FormatSwitchKeyText(int vk)
        {
            if (vk == SwitchKeyNoKey) return "Không (modifier-only)";
            return FormatHotkeyText(vk);
        }

        private static bool TryGetSwitchKeyValue(TextBox textBox, out int value)
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
    }
}
