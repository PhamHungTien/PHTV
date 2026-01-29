using System.Windows;
using PHTV.UI;

namespace PHTV.UI.Pages
{
    public partial class AboutPage : PhtvPageBase
    {
        public AboutPage()
        {
            InitializeComponent();
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            Host?.RegisterPage(this);
        }

        private void Website_Click(object sender, RoutedEventArgs e)
        {
            MainWindow.OpenUrl("https://phamhungtien.com/PHTV/");
        }

        private void GitHub_Click(object sender, RoutedEventArgs e)
        {
            MainWindow.OpenUrl("https://github.com/PhamHungTien/PHTV");
        }

        private void Donate_Click(object sender, RoutedEventArgs e)
        {
            MainWindow.OpenUrl("https://phamhungtien.com/PHTV/");
        }
    }
}
