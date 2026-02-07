using Avalonia.Controls;
using Avalonia.Interactivity;
using PHTV.Windows.Models;
using PHTV.Windows.Services;
using PHTV.Windows.ViewModels;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;

namespace PHTV.Windows.Dialogs;

public sealed partial class AppPickerWindow : Window {
    private readonly AppPickerViewModel _viewModel;

    public AppPickerWindow() {
        InitializeComponent();
        _viewModel = new AppPickerViewModel();
        DataContext = _viewModel;
    }

    public static async Task<string?> ShowAsync(Window owner) {
        var dialog = new AppPickerWindow();
        var result = await dialog.ShowDialog<RunningAppInfo?>(owner);
        return result?.ExeName;
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) {
        Close(null);
    }

    private void OnSelectClick(object? sender, RoutedEventArgs e) {
        Close(_viewModel.SelectedApp);
    }
}

public sealed class AppPickerViewModel : ObservableObject {
    private readonly List<RunningAppInfo> _allApps;
    private string _searchText = string.Empty;
    private RunningAppInfo? _selectedApp;

    public AppPickerViewModel() {
        var service = new AppDiscoveryService();
        _allApps = service.GetRunningApps();
        FilteredApps = new ObservableCollection<RunningAppInfo>(_allApps);
    }

    public ObservableCollection<RunningAppInfo> FilteredApps { get; }

    public string SearchText {
        get => _searchText;
        set {
            if (SetProperty(ref _searchText, value)) {
                ApplyFilter();
            }
        }
    }

    public RunningAppInfo? SelectedApp {
        get => _selectedApp;
        set => SetProperty(ref _selectedApp, value);
    }

    private void ApplyFilter() {
        FilteredApps.Clear();
        var filtered = _allApps.Where(a => 
            string.IsNullOrWhiteSpace(SearchText) || 
            a.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
            a.ExeName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));

        foreach (var app in filtered) {
            FilteredApps.Add(app);
        }
    }
}
