using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace PHTV.Windows.Views.Tabs;

public sealed partial class SystemTabView : UserControl {
    public SystemTabView() {
        AvaloniaXamlLoader.Load(this);
    }
}
