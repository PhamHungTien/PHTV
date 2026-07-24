using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using PHTV.Windows.App.Services;
using PHTV.Windows.Contracts.Configuration;

namespace PHTV.Windows.App;

public sealed partial class MainWindow : Window
{
    private readonly SettingsStore settingsStore = new();
    private PHTVSettings currentSettings = new();
    private bool isLoaded;

    public MainWindow()
    {
        InitializeComponent();
        SystemBackdrop = new MicaBackdrop();
        Navigation.SelectedItem = OverviewItem;
    }

    private async void OnRootLoaded(object sender, RoutedEventArgs e)
    {
        if (isLoaded)
        {
            return;
        }

        isLoaded = true;
        SetBusy(true);

        try
        {
            PHTVSettings settings = await settingsStore.LoadAsync();
            currentSettings = settings;
            VietnameseEnabledSwitch.IsOn = settings.VietnameseEnabled;
            TelexOption.IsChecked = settings.InputMethod == InputMethod.Telex;
            VniOption.IsChecked = settings.InputMethod == InputMethod.Vni;
        }
        catch (Exception exception) when (
            exception is IOException
                or InvalidDataException
                or UnauthorizedAccessException
                or System.Text.Json.JsonException
        )
        {
            ShowStatus(
                InfoBarSeverity.Warning,
                "Không thể đọc cài đặt cũ",
                "PHTV đang dùng thiết lập an toàn mặc định. Bạn có thể lưu lại để tạo tệp mới."
            );
            VietnameseEnabledSwitch.IsOn = true;
            TelexOption.IsChecked = true;
            currentSettings = new PHTVSettings();
        }
        finally
        {
            SetBusy(false);
        }
    }

    private async void OnSaveClicked(object sender, RoutedEventArgs e)
    {
        SetBusy(true);
        StatusInfoBar.IsOpen = false;

        PHTVSettings settings = currentSettings with
        {
            VietnameseEnabled = VietnameseEnabledSwitch.IsOn,
            InputMethod = VniOption.IsChecked == true
                ? InputMethod.Vni
                : InputMethod.Telex,
        };

        try
        {
            await settingsStore.SaveAsync(settings);
            currentSettings = settings.Normalize();
            ShowStatus(
                InfoBarSeverity.Success,
                "Đã lưu",
                "Thiết lập sẽ có hiệu lực khi bạn kích hoạt lại bộ gõ PHTV."
            );
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException
        )
        {
            ShowStatus(
                InfoBarSeverity.Error,
                "Không thể lưu cài đặt",
                "Hãy kiểm tra quyền ghi thư mục người dùng rồi thử lại."
            );
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void OnNavigationSelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args
    )
    {
        string tag = (args.SelectedItemContainer?.Tag as string) ?? "overview";
        bool showOverview = tag is "overview" or "typing";

        OverviewCard.Visibility = showOverview ? Visibility.Visible : Visibility.Collapsed;
        TypingCard.Visibility = showOverview ? Visibility.Visible : Visibility.Collapsed;
        SaveBar.Visibility = showOverview ? Visibility.Visible : Visibility.Collapsed;
        ApplicationsCard.Visibility =
            tag == "applications" ? Visibility.Visible : Visibility.Collapsed;
        AboutCard.Visibility = tag == "about" ? Visibility.Visible : Visibility.Collapsed;

        (PageTitle.Text, PageDescription.Text) = tag switch
        {
            "typing" => (
                "Kiểu gõ",
                "Chọn trạng thái tiếng Việt và phương pháp nhập dấu."
            ),
            "applications" => (
                "Ứng dụng",
                "Quản lý cách PHTV hoạt động trong từng ứng dụng."
            ),
            "about" => (
                "Thông tin",
                "Phiên bản, quyền riêng tư và trạng thái nền tảng Windows."
            ),
            _ => (
                "Tổng quan",
                "Thiết lập bộ gõ tiếng Việt trên Windows."
            ),
        };
    }

    private void SetBusy(bool busy)
    {
        SaveButton.IsEnabled = !busy;
        SaveProgress.IsActive = busy;
    }

    private void ShowStatus(
        InfoBarSeverity severity,
        string title,
        string message
    )
    {
        StatusInfoBar.Severity = severity;
        StatusInfoBar.Title = title;
        StatusInfoBar.Message = message;
        StatusInfoBar.IsOpen = true;
    }
}
