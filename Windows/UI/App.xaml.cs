using System;
using System.Windows;

namespace PHTV.UI
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            AppDomain.CurrentDomain.UnhandledException += (s, args) =>
            {
                string msg = args.ExceptionObject.ToString();
                System.IO.File.AppendAllText("phtv_crash.txt", msg);
                MessageBox.Show("Crash: " + msg);
            };

            base.OnStartup(e);
        }
    }
}
