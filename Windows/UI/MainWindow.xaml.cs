using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Forms; // For NotifyIcon

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
        public static extern void PHTV_SetInputMethod(int type);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetLanguage(int lang);

        [DllImport("PHTVCore.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void PHTV_SetSpellCheck(bool enable);

        private NotifyIcon _trayIcon;

        public MainWindow()
        {
            InitializeComponent();
            InitializeEngine();
            InitializeTrayIcon();
            
            // Hide window on start
            this.Hide(); 
        }

        private void InitializeEngine()
        {
            try {
                PHTV_Init();
                PHTV_InstallHook();
            } catch (Exception ex) {
                System.Windows.MessageBox.Show("Không thể tải PHTVCore.dll: " + ex.Message);
            }
        }

        private void InitializeTrayIcon()
        {
            _trayIcon = new NotifyIcon();
            _trayIcon.Icon = new System.Drawing.Icon("icon.ico");
            _trayIcon.Visible = true;
            _trayIcon.Text = "PHTV - Bộ gõ Tiếng Việt";
            
            var menu = new ContextMenuStrip();
            menu.Items.Add("Bảng điều khiển...", null, (s, e) => this.Show());
            menu.Items.Add("-");
            menu.Items.Add("Thoát", null, (s, e) => {
                _trayIcon.Visible = false;
                System.Windows.Application.Current.Shutdown();
            });
            
            _trayIcon.ContextMenuStrip = menu;
            
            // Toggle Language on Click
            _trayIcon.MouseClick += (s, e) => {
                if (e.Button == MouseButtons.Left) {
                    // Toggle Logic Here (Store state in C# var and call SetLanguage)
                }
            };
        }

        private void InputMethod_Changed(object sender, RoutedEventArgs e)
        {
            if (RadioTelex.IsChecked == true) PHTV_SetInputMethod(0);
            else PHTV_SetInputMethod(1);
        }

        private void Feature_Changed(object sender, RoutedEventArgs e)
        {
            PHTV_SetSpellCheck(ChkSpell.IsChecked == true);
            // ... Call other setters
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            this.Hide();
        }
        
        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            e.Cancel = true;
            this.Hide();
        }
    }
}
