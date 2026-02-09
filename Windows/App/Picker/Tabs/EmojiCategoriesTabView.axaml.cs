using System.Collections.Specialized;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using PHTV.Windows.Data;
using PHTV.Windows.Models;

namespace PHTV.Windows.Picker.Tabs;

public partial class EmojiCategoriesTabView : UserControl {
    private bool _initialized;

    public EmojiCategoriesTabView() {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private EmojiPickerViewModel? ViewModel => DataContext as EmojiPickerViewModel;

    private void OnDataContextChanged(object? sender, EventArgs e) {
        if (ViewModel == null || _initialized) return;
        _initialized = true;

        BuildSubCategoryTabs();
        RebuildEmojiGrid();

        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
        ViewModel.EmojiSearchResults.CollectionChanged += (_, _) => {
            if (!string.IsNullOrEmpty(ViewModel.SearchText))
                RebuildSearchResults();
        };
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e) {
        if (e.PropertyName == nameof(EmojiPickerViewModel.SelectedSubCategory))
            RebuildEmojiGrid();
        else if (e.PropertyName == nameof(EmojiPickerViewModel.SearchText) &&
                 string.IsNullOrEmpty(ViewModel?.SearchText))
            RebuildEmojiGrid();
    }

    private void BuildSubCategoryTabs() {
        SubCategoryTabs.Children.Clear();
        var categories = EmojiDatabase.Shared.Categories;
        for (var i = 0; i < categories.Length; i++) {
            var (_, icon, _) = categories[i];
            var btn = new Button {
                Content = new TextBlock { Text = icon, FontSize = 16 },
                Width = 32, Height = 32,
                Padding = new Thickness(0),
                Background = i == ViewModel?.SelectedSubCategory
                    ? new SolidColorBrush(Color.FromArgb(50, 255, 255, 255))
                    : Brushes.Transparent,
                BorderThickness = new Thickness(0),
                Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
                Tag = i,
                CornerRadius = new CornerRadius(6)
            };
            ToolTip.SetTip(btn, categories[i].Name);
            btn.Click += OnSubCategoryClick;
            SubCategoryTabs.Children.Add(btn);
        }
    }

    private void RebuildEmojiGrid() {
        if (ViewModel == null) return;

        EmojiGrid.Children.Clear();
        var categories = EmojiDatabase.Shared.Categories;
        var idx = ViewModel.SelectedSubCategory;
        if (idx < 0 || idx >= categories.Length) return;

        var emojis = categories[idx].Emojis;
        foreach (var item in emojis) {
            var btn = CreateEmojiButton(item);
            EmojiGrid.Children.Add(btn);
        }

        UpdateSubCategoryHighlight();
    }

    private void RebuildSearchResults() {
        if (ViewModel == null) return;

        EmojiGrid.Children.Clear();
        foreach (var item in ViewModel.EmojiSearchResults) {
            var btn = CreateEmojiButton(item);
            EmojiGrid.Children.Add(btn);
        }
    }

    private Button CreateEmojiButton(EmojiItem item) {
        var freq = EmojiDatabase.Shared.GetEmojiItem(item.Emoji) != null
            ? EmojiDatabase.Shared.GetFrequentlyUsedEmojis().IndexOf(item.Emoji)
            : -1;

        var content = new TextBlock {
            Text = item.Emoji,
            FontSize = 24,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        var btn = new Button {
            Content = content,
            Width = 40, Height = 40,
            Padding = new Thickness(0),
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
            Tag = item.Emoji
        };
        ToolTip.SetTip(btn, item.Name);
        btn.Click += OnEmojiClick;
        btn.PointerEntered += (_, _) => btn.Background = new SolidColorBrush(Color.FromArgb(30, 255, 255, 255));
        btn.PointerExited += (_, _) => btn.Background = Brushes.Transparent;
        return btn;
    }

    private void OnSubCategoryClick(object? sender, RoutedEventArgs e) {
        if (sender is Button { Tag: int idx } && ViewModel != null) {
            ViewModel.SelectedSubCategory = idx;
            ViewModel.SearchText = string.Empty;
        }
    }

    private void UpdateSubCategoryHighlight() {
        if (ViewModel == null) return;
        for (var i = 0; i < SubCategoryTabs.Children.Count; i++) {
            if (SubCategoryTabs.Children[i] is Button btn)
                btn.Background = i == ViewModel.SelectedSubCategory
                    ? new SolidColorBrush(Color.FromArgb(50, 255, 255, 255))
                    : Brushes.Transparent;
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
