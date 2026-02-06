using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using PHTV.Windows.ViewModels;
using System.ComponentModel;

namespace PHTV.Windows;

public sealed partial class MainWindow : Window {
    private bool _exitRequested;

    public MainWindow() : this(new MainWindowViewModel()) {
    }

    public MainWindow(MainWindowViewModel viewModel) {
        AvaloniaXamlLoader.Load(this);
        viewModel.AttachWindow(this);
        DataContext = viewModel;
        viewModel.InitializeAfterWindowReady();
        Closing += OnClosing;
    }

    public void ShowFromTray() {
        if (!IsVisible) {
            Show();
        }

        WindowState = WindowState.Normal;
        Activate();
    }

    public void RequestExitAndClose() {
        _exitRequested = true;
        Close();
    }

    private void OnClosing(object? sender, CancelEventArgs e) {
        if (_exitRequested) {
            return;
        }

        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime) {
            return;
        }

        e.Cancel = true;
        Hide();
    }
}
