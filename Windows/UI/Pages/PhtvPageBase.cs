using System.Windows;
using System.Windows.Controls;
using PHTV.UI;

namespace PHTV.UI.Pages
{
    public class PhtvPageBase : Page
    {
        protected MainWindow Host => Application.Current?.MainWindow as MainWindow;
    }
}
