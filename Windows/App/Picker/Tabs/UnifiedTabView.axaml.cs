using System.Collections.Specialized;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using PHTV.Windows.Models;
using PHTV.Windows.Services;

namespace PHTV.Windows.Picker.Tabs;

public partial class UnifiedTabView : UserControl {
    public UnifiedTabView() {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private EmojiPickerViewModel? ViewModel => DataContext as EmojiPickerViewModel;

    private void OnDataContextChanged(object? sender, EventArgs e) {
        if (ViewModel == null) return;

        ViewModel.RecentEmojis.CollectionChanged += (_, _) => RebuildEmojiPanel(RecentEmojisPanel, ViewModel.RecentEmojis);
        ViewModel.FrequentlyUsedEmojis.CollectionChanged += (_, _) => RebuildEmojiPanel(FrequentEmojisPanel, ViewModel.FrequentlyUsedEmojis);
        ViewModel.EmojiSearchResults.CollectionChanged += (_, _) => RebuildEmojiItemPanel(EmojiResultsPanel, ViewModel.EmojiSearchResults, 14);
        ViewModel.GifResults.CollectionChanged += (_, _) => RebuildMediaPanel(GifResultsPanel, ViewModel.GifResults, true, 8);
        ViewModel.StickerResults.CollectionChanged += (_, _) => RebuildMediaPanel(StickerResultsPanel, ViewModel.StickerResults, false, 8);

        RebuildEmojiPanel(RecentEmojisPanel, ViewModel.RecentEmojis);
        RebuildEmojiPanel(FrequentEmojisPanel, ViewModel.FrequentlyUsedEmojis);
    }

    private void RebuildEmojiPanel(WrapPanel panel, IEnumerable<string> emojis) {
        panel.Children.Clear();
        foreach (var emoji in emojis) {
            var btn = CreateEmojiButton(emoji);
            panel.Children.Add(btn);
        }
    }

    private void RebuildEmojiItemPanel(WrapPanel panel, IEnumerable<EmojiItem> items, int maxCount) {
        panel.Children.Clear();
        var count = 0;
        foreach (var item in items) {
            if (count >= maxCount) break;
            var btn = CreateEmojiButton(item.Emoji);
            ToolTip.SetTip(btn, item.Name);
            panel.Children.Add(btn);
            count++;
        }
    }

    private void RebuildMediaPanel(WrapPanel panel, IEnumerable<KlipyGif> items, bool isGif, int maxCount) {
        panel.Children.Clear();
        var count = 0;
        foreach (var item in items) {
            if (count >= maxCount) break;
            var btn = CreateMediaButton(item, isGif);
            panel.Children.Add(btn);
            count++;
        }
    }

    private Button CreateEmojiButton(string emoji) {
        var btn = new Button {
            Content = new TextBlock {
                Text = emoji,
                FontSize = 24,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            },
            Width = 40, Height = 40,
            Padding = new Avalonia.Thickness(0),
            Background = Brushes.Transparent,
            BorderThickness = new Avalonia.Thickness(0),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
            Tag = emoji
        };
        btn.Click += OnEmojiClick;
        btn.PointerEntered += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(30, 255, 255, 255));
        btn.PointerExited += (_, _) => btn.Background = Brushes.Transparent;
        return btn;
    }

    private Button CreateMediaButton(KlipyGif gif, bool isGif) {
        var image = new Image {
            Width = 70, Height = 70,
            Stretch = Stretch.UniformToFill
        };

        // Load image async
        LoadImageAsync(image, gif.PreviewUrl);

        var btn = new Button {
            Content = image,
            Width = 76, Height = 76,
            Padding = new Avalonia.Thickness(2),
            Background = new SolidColorBrush(Color.FromArgb(15, 255, 255, 255)),
            BorderThickness = new Avalonia.Thickness(0),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
            Tag = gif,
            CornerRadius = new Avalonia.CornerRadius(8)
        };
        btn.Click += (_, _) => {
            if (isGif) ViewModel?.SelectGif(gif);
            else ViewModel?.SelectSticker(gif);
        };
        btn.PointerEntered += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255));
        btn.PointerExited += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(15, 255, 255, 255));

        // Track impression for ads
        if (gif.IsAd) KlipyApiClient.Shared.TrackImpression(gif);

        return btn;
    }

    private static async void LoadImageAsync(Image image, string url) {
        try {
            using var httpClient = new System.Net.Http.HttpClient();
            var data = await httpClient.GetByteArrayAsync(url);
            using var stream = new MemoryStream(data);
            image.Source = new Bitmap(stream);
        } catch {
            // Ignore load errors
        }
    }

    private void OnEmojiClick(object? sender, RoutedEventArgs e) {
        if (sender is Button { Tag: string emoji })
            ViewModel?.SelectEmoji(emoji);
    }

    private void OnClearSearch(object? sender, RoutedEventArgs e) {
        if (ViewModel != null) ViewModel.SearchText = string.Empty;
        SearchBox.Focus();
    }
}
