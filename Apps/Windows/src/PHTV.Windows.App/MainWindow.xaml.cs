using System.Collections.ObjectModel;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.Windows.Storage.Pickers;
using PHTV.Windows.App.Services;
using PHTV.Windows.Contracts.Configuration;

namespace PHTV.Windows.App;

public sealed partial class MainWindow : Window
{
    private readonly SettingsStore settingsStore = new();
    private readonly ObservableCollection<ApplicationRuleItem>
        applicationRuleItems = [];
    private PHTVSettings currentSettings = new();
    private bool isLoaded;
    private bool settingsReady;

    public MainWindow()
    {
        InitializeComponent();
        SystemBackdrop = new MicaBackdrop();
        ApplicationRulesList.ItemsSource = applicationRuleItems;
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
            applicationRuleItems.Clear();
            foreach (ApplicationRule rule in settings.ApplicationRules)
            {
                if (rule.Rule != ApplicationLanguageRule.Inherit)
                {
                    applicationRuleItems.Add(
                        ApplicationRuleItem.FromContract(rule)
                    );
                }
            }
            UpdateApplicationsEmptyState();
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
            applicationRuleItems.Clear();
            UpdateApplicationsEmptyState();
        }
        finally
        {
            settingsReady = true;
            SetBusy(false);
        }
    }

    private async void OnSaveClicked(object sender, RoutedEventArgs e)
    {
        // The Loaded handler is asynchronous.  Ignore an early click until
        // the existing settings have been read so a fast launch cannot save
        // defaults over the user's configuration.
        if (!settingsReady)
        {
            return;
        }

        SetBusy(true);
        StatusInfoBar.IsOpen = false;

        PHTVSettings settings = currentSettings with
        {
            VietnameseEnabled = VietnameseEnabledSwitch.IsOn,
            InputMethod = VniOption.IsChecked == true
                ? InputMethod.Vni
                : InputMethod.Telex,
            ApplicationRules = applicationRuleItems
                .Select(item => item.ToContract())
                .ToArray(),
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

    private async void OnAddApplicationClicked(
        object sender,
        RoutedEventArgs e
    )
    {
        StatusInfoBar.IsOpen = false;
        try
        {
            IntPtr windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(
                this
            );
            WindowId windowId = Win32Interop.GetWindowIdFromWindow(
                windowHandle
            );
            var picker = new FileOpenPicker(windowId)
            {
                CommitButtonText = "Chọn ứng dụng",
                SettingsIdentifier = "PHTVApplicationRulePicker",
                Title = "Chọn ứng dụng cần đặt chế độ gõ",
            };
            picker.FileTypeFilter.Add(".exe");

            PickFileResult? selected = await picker.PickSingleFileAsync();
            if (selected is null)
            {
                return;
            }

            string executableIdentity = Path
                .GetFileName(selected.Path)
                .Trim()
                .ToLowerInvariant();
            if (string.IsNullOrEmpty(executableIdentity)
                || !executableIdentity.EndsWith(
                    ".exe",
                    StringComparison.OrdinalIgnoreCase
                ))
            {
                ShowStatus(
                    InfoBarSeverity.Warning,
                    "Không thể thêm ứng dụng",
                    "Tệp đã chọn không phải ứng dụng Windows hợp lệ."
                );
                return;
            }

            ApplicationRuleItem? existing = applicationRuleItems.FirstOrDefault(
                item => item.ExecutableIdentity == executableIdentity
                    && item.PackageFamilyName is null
            );
            if (existing is not null)
            {
                ApplicationRulesList.ScrollIntoView(existing);
                ShowStatus(
                    InfoBarSeverity.Informational,
                    "Ứng dụng đã có trong danh sách",
                    "Bạn có thể đổi hành vi ngay tại quy tắc hiện có."
                );
                return;
            }

            var item = new ApplicationRuleItem(
                executableIdentity,
                packageFamilyName: null,
                ApplicationLanguageRule.PreferEnglish
            );
            applicationRuleItems.Add(item);
            UpdateApplicationsEmptyState();
            ApplicationRulesList.ScrollIntoView(item);
        }
        catch (Exception)
        {
            ShowStatus(
                InfoBarSeverity.Error,
                "Không thể mở trình chọn ứng dụng",
                "Windows không thể truy cập tệp đã chọn. Hãy thử lại với một ứng dụng khác."
            );
        }
    }

    private void OnRemoveApplicationClicked(
        object sender,
        RoutedEventArgs e
    )
    {
        if (sender is FrameworkElement
        {
                Tag: string identityKey,
            })
        {
            ApplicationRuleItem? item = applicationRuleItems.FirstOrDefault(
                candidate => candidate.IdentityKey == identityKey
            );
            if (item is not null)
            {
                applicationRuleItems.Remove(item);
                UpdateApplicationsEmptyState();
            }
        }
    }

    private void OnNavigationSelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args
    )
    {
        string tag = (args.SelectedItemContainer?.Tag as string) ?? "overview";
        OverviewCard.Visibility =
            tag == "overview" ? Visibility.Visible : Visibility.Collapsed;
        TypingCard.Visibility =
            tag == "typing" ? Visibility.Visible : Visibility.Collapsed;
        SaveBar.Visibility =
            tag is "overview" or "typing" or "applications"
            ? Visibility.Visible
            : Visibility.Collapsed;
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
        SaveButton.IsEnabled = !busy && settingsReady;
        AddApplicationButton.IsEnabled = !busy && settingsReady;
        SaveProgress.IsActive = busy;
    }

    private void UpdateApplicationsEmptyState()
    {
        ApplicationsEmptyState.Visibility = applicationRuleItems.Count == 0
            ? Visibility.Visible
            : Visibility.Collapsed;
        ApplicationRulesList.Visibility = applicationRuleItems.Count == 0
            ? Visibility.Collapsed
            : Visibility.Visible;
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

public sealed class ApplicationRuleItem
{
    public ApplicationRuleItem(
        string executableIdentity,
        string? packageFamilyName,
        ApplicationLanguageRule rule
    )
    {
        ExecutableIdentity = executableIdentity;
        PackageFamilyName = packageFamilyName;
        SelectedRuleIndex =
            rule == ApplicationLanguageRule.LockEnglish ? 1 : 0;
    }

    public string ExecutableIdentity { get; }

    public string? PackageFamilyName { get; }

    public string IdentityKey =>
        $"{ExecutableIdentity}\0{PackageFamilyName ?? string.Empty}";

    public string DisplayName =>
        Path.GetFileNameWithoutExtension(ExecutableIdentity);

    public string IdentityDescription => PackageFamilyName is null
        ? ExecutableIdentity
        : $"{ExecutableIdentity} · {PackageFamilyName}";

    public int SelectedRuleIndex { get; set; }

    public ApplicationRule ToContract() =>
        new(
            ExecutableIdentity,
            PackageFamilyName,
            SelectedRuleIndex == 1
                ? ApplicationLanguageRule.LockEnglish
                : ApplicationLanguageRule.PreferEnglish
        );

    public static ApplicationRuleItem FromContract(ApplicationRule rule) =>
        new(
            rule.ExecutableIdentity,
            rule.PackageFamilyName,
            rule.Rule
        );
}
