using Microsoft.UI.Xaml;

namespace PHTV.Windows.App;

public partial class App : Application
{
    private Window? window;

    public App()
    {
        InitializeComponent();
        UnhandledException += OnUnhandledException;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        window = new MainWindow();
        window.Activate();
    }

    private static void OnUnhandledException(
        object sender,
        Microsoft.UI.Xaml.UnhandledExceptionEventArgs args
    )
    {
        // Do not log typed text, Clipboard contents, paths, or settings payloads.
        System.Diagnostics.Debug.WriteLine(
            $"PHTV Windows UI failure: {args.Exception.GetType().Name}"
        );
    }
}
