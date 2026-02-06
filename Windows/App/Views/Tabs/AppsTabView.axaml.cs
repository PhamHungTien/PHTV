using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace PHTV.Windows.Views.Tabs;

public sealed partial class AppsTabView : UserControl {
    public AppsTabView() {
        AvaloniaXamlLoader.Load(this);
    }
}
