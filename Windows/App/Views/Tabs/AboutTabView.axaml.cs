using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace PHTV.Windows.Views.Tabs;

public sealed partial class AboutTabView : UserControl {
    public AboutTabView() {
        AvaloniaXamlLoader.Load(this);
    }
}
