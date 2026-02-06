using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace PHTV.Windows.Views.Tabs;

public sealed partial class BugReportTabView : UserControl {
    public BugReportTabView() {
        AvaloniaXamlLoader.Load(this);
    }
}
