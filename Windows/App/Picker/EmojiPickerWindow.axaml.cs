using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Data.Converters;
using Avalonia.Input;
using Avalonia.Interactivity;
using PHTV.Windows.Models;
using PHTV.Windows.Services;

namespace PHTV.Windows.Picker;

public sealed class IntEqualsConverter : IValueConverter {
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) {
        if (value is int intVal && parameter is string str && int.TryParse(str, out var target))
            return intVal == target;
        return false;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public partial class EmojiPickerWindow : Window {
    public static readonly IntEqualsConverter TabEqualsConverter = new();

    private readonly EmojiPickerViewModel _viewModel;
    private readonly IntPtr _previousWindow;

    public EmojiPickerWindow() : this(new EmojiPickerViewModel(), IntPtr.Zero) { }

    public EmojiPickerWindow(EmojiPickerViewModel viewModel, IntPtr previousWindow) {
        _viewModel = viewModel;
        _previousWindow = previousWindow;
        DataContext = viewModel;

        InitializeComponent();

        viewModel.OnEmojiSelected = OnEmojiSelected;
        viewModel.OnGifSelected = OnGifSelected;
        viewModel.OnStickerSelected = OnStickerSelected;
        viewModel.OnClose = () => Close();
    }

    public void ShowAtMousePosition() {
        var (x, y) = EmojiInsertionService.GetMousePosition();

        // Get screen bounds
        var screen = Screens.ScreenFromPoint(new PixelPoint(x, y));
        if (screen != null) {
            var bounds = screen.WorkingArea;
            var scaling = screen.Scaling;
            var w = (int)(380 * scaling);
            var h = (int)(480 * scaling);

            // Adjust to keep window on screen
            if (x + w > bounds.Right) x = bounds.Right - w;
            if (y + h > bounds.Bottom) y = bounds.Bottom - h;
            if (x < bounds.X) x = bounds.X;
            if (y < bounds.Y) y = bounds.Y;
        }

        Position = new PixelPoint(x, y);
        Show();
        Activate();
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.Key == Key.Escape) {
            Close();
            e.Handled = true;
            return;
        }
        base.OnKeyDown(e);
    }

    protected override void OnDeactivated(EventArgs e) {
        base.OnDeactivated(e);
        Close();
    }

    private void OnHeaderPointerPressed(object? sender, PointerPressedEventArgs e) {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
            BeginMoveDrag(e);
    }

    private void OnCloseClick(object? sender, RoutedEventArgs e) => Close();

    private void OnTabClick(object? sender, RoutedEventArgs e) {
        if (sender is Button btn && btn.Tag is string tagStr && int.TryParse(tagStr, out var tab))
            _viewModel.SelectedTab = tab;
    }

    private async void OnEmojiSelected(string emoji) {
        Close();
        await EmojiInsertionService.PasteEmojiAsync(emoji, _previousWindow, this);
    }

    private async void OnGifSelected(KlipyGif gif) {
        Close();
        var filePath = await KlipyApiClient.Shared.DownloadMediaAsync(gif);
        if (filePath != null)
            await EmojiInsertionService.PasteMediaFileAsync(filePath, _previousWindow, this);
    }

    private async void OnStickerSelected(KlipyGif sticker) {
        Close();
        var filePath = await KlipyApiClient.Shared.DownloadMediaAsync(sticker);
        if (filePath != null)
            await EmojiInsertionService.PasteMediaFileAsync(filePath, _previousWindow, this);
    }
}
