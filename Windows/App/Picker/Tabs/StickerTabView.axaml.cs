using System.Collections.Specialized;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using PHTV.Windows.Models;
using PHTV.Windows.Services;

namespace PHTV.Windows.Picker.Tabs;

public partial class StickerTabView : UserControl {
    public StickerTabView() {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private EmojiPickerViewModel? ViewModel => DataContext as EmojiPickerViewModel;

    private void OnDataContextChanged(object? sender, EventArgs e) {
        if (ViewModel == null) return;

        ViewModel.StickerResults.CollectionChanged += (_, _) => RebuildStickerGrid();
        ViewModel.RecentStickers.CollectionChanged += (_, _) => RebuildRecentStickers();

        RebuildStickerGrid();
        RebuildRecentStickers();
    }

    private void RebuildStickerGrid() {
        StickerGridPanel.Children.Clear();
        foreach (var sticker in ViewModel?.StickerResults ?? Enumerable.Empty<KlipyGif>()) {
            var btn = CreateMediaButton(sticker);
            StickerGridPanel.Children.Add(btn);
        }
        EmptyText.IsVisible = ViewModel?.StickerResults.Count == 0 &&
                              !string.IsNullOrEmpty(ViewModel?.SearchText) &&
                              ViewModel?.IsLoading == false;
    }

    private void RebuildRecentStickers() {
        RecentStickersPanel.Children.Clear();
        foreach (var sticker in ViewModel?.RecentStickers ?? Enumerable.Empty<KlipyGif>()) {
            var btn = CreateMediaButton(sticker);
            RecentStickersPanel.Children.Add(btn);
        }
    }

    private Button CreateMediaButton(KlipyGif sticker) {
        var image = new Image {
            Width = 76, Height = 76,
            Stretch = Stretch.UniformToFill
        };

        LoadImageAsync(image, sticker.PreviewUrl);

        var container = new Grid();
        container.Children.Add(image);

        if (sticker.IsAd) {
            var adBadge = new Border {
                Background = new SolidColorBrush(Color.FromArgb(180, 0, 0, 0)),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(4, 1),
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top,
                Margin = new Thickness(2),
                Child = new TextBlock {
                    Text = "Ad",
                    FontSize = 9,
                    Foreground = Brushes.White
                }
            };
            container.Children.Add(adBadge);
            KlipyApiClient.Shared.TrackImpression(sticker);
        }

        var btn = new Button {
            Content = container,
            Width = 82, Height = 82,
            Padding = new Thickness(2),
            Background = new SolidColorBrush(Color.FromArgb(15, 255, 255, 255)),
            BorderThickness = new Thickness(0),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
            CornerRadius = new CornerRadius(8)
        };
        btn.Click += (_, _) => ViewModel?.SelectSticker(sticker);
        btn.PointerEntered += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255));
        btn.PointerExited += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(15, 255, 255, 255));
        return btn;
    }

    private static async void LoadImageAsync(Image image, string url) {
        try {
            using var httpClient = new System.Net.Http.HttpClient();
            var data = await httpClient.GetByteArrayAsync(url);
            using var stream = new MemoryStream(data);
            image.Source = new Bitmap(stream);
        } catch { }
    }

    private void OnClearSearch(object? sender, RoutedEventArgs e) {
        if (ViewModel != null) ViewModel.SearchText = string.Empty;
        SearchBox.Focus();
    }
}
