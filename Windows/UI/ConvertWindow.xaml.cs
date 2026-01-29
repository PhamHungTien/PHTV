using System.Windows;
using Wpf.Ui.Controls;
using static PHTV.UI.Interop.PhtvNative;

namespace PHTV.UI
{
    public partial class ConvertWindow : FluentWindow
    {
        public ConvertWindow()
        {
            InitializeComponent();
            int current = PHTV_GetCodeTable();
            SelectCode(ComboFromCode, current);
            SelectCode(ComboToCode, 0);
        }

        private void Convert_Click(object sender, RoutedEventArgs e)
        {
            if (!TryGetCode(ComboFromCode, out int fromCode) || !TryGetCode(ComboToCode, out int toCode))
            {
                System.Windows.MessageBox.Show("Vui lòng chọn bảng mã hợp lệ.");
                return;
            }

            bool ok = PHTV_QuickConvertClipboard(fromCode, toCode);
            System.Windows.MessageBox.Show(ok ? "Đã chuyển đổi clipboard." : "Không thể chuyển đổi clipboard.");
        }

        private static bool TryGetCode(System.Windows.Controls.ComboBox comboBox, out int code)
        {
            code = 0;
            if (comboBox.SelectedItem is System.Windows.Controls.ComboBoxItem item &&
                int.TryParse(item.Tag?.ToString(), out int tag))
            {
                code = tag;
                return true;
            }
            return false;
        }

        private static void SelectCode(System.Windows.Controls.ComboBox comboBox, int code)
        {
            foreach (var item in comboBox.Items)
            {
                if (item is System.Windows.Controls.ComboBoxItem cb &&
                    int.TryParse(cb.Tag?.ToString(), out int tag) &&
                    tag == code)
                {
                    comboBox.SelectedItem = cb;
                    return;
                }
            }
            if (comboBox.Items.Count > 0)
            {
                comboBox.SelectedIndex = 0;
            }
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
