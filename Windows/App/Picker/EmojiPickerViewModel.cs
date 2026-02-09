using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using Avalonia.Controls;
using PHTV.Windows.Data;
using PHTV.Windows.Models;
using PHTV.Windows.Services;

namespace PHTV.Windows.Picker;

public sealed class EmojiPickerViewModel : INotifyPropertyChanged {
    private int _selectedTab;
    private string _searchText = string.Empty;
    private int _selectedSubCategory;
    private bool _isLoading;
    private readonly System.Timers.Timer _searchDebounceTimer;
    private readonly string _dataFilePath;

    public Action<string>? OnEmojiSelected { get; set; }
    public Action<KlipyGif>? OnGifSelected { get; set; }
    public Action<KlipyGif>? OnStickerSelected { get; set; }
    public Action? OnClose { get; set; }

    public ObservableCollection<EmojiItem> EmojiSearchResults { get; } = new();
    public ObservableCollection<string> FrequentlyUsedEmojis { get; } = new();
    public ObservableCollection<string> RecentEmojis { get; } = new();
    public ObservableCollection<KlipyGif> GifResults { get; } = new();
    public ObservableCollection<KlipyGif> StickerResults { get; } = new();
    public ObservableCollection<KlipyGif> RecentGifs { get; } = new();
    public ObservableCollection<KlipyGif> RecentStickers { get; } = new();

    public (string Name, string Icon, EmojiItem[] Emojis)[] Categories =>
        EmojiDatabase.Shared.Categories;

    public int SelectedTab {
        get => _selectedTab;
        set {
            if (SetField(ref _selectedTab, value)) {
                SearchText = string.Empty;
                OnTabChanged();
                SaveTabPreference();
            }
        }
    }

    public string SearchText {
        get => _searchText;
        set {
            if (SetField(ref _searchText, value)) {
                _searchDebounceTimer.Stop();
                _searchDebounceTimer.Start();
            }
        }
    }

    public int SelectedSubCategory {
        get => _selectedSubCategory;
        set => SetField(ref _selectedSubCategory, value);
    }

    public bool IsLoading {
        get => _isLoading;
        set => SetField(ref _isLoading, value);
    }

    public EmojiPickerViewModel() {
        var appData = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PHTV");
        _dataFilePath = Path.Combine(appData, "picker-prefs.json");

        _searchDebounceTimer = new Timer(350) { AutoReset = false };
        _searchDebounceTimer.Elapsed += (_, _) => {
            Avalonia.Threading.Dispatcher.UIThread.Post(ExecuteSearch);
        };

        LoadTabPreference();
        LoadRecentAndFrequent();
        OnTabChanged();
    }

    public void SelectEmoji(string emoji) {
        EmojiDatabase.Shared.RecordUsage(emoji);
        OnEmojiSelected?.Invoke(emoji);
    }

    public void SelectGif(KlipyGif gif) {
        KlipyApiClient.Shared.RecordGifUsage(gif);
        KlipyApiClient.Shared.TrackClick(gif);
        OnGifSelected?.Invoke(gif);
    }

    public void SelectSticker(KlipyGif sticker) {
        KlipyApiClient.Shared.RecordStickerUsage(sticker);
        KlipyApiClient.Shared.TrackClick(sticker);
        OnStickerSelected?.Invoke(sticker);
    }

    public void Close() => OnClose?.Invoke();

    private async void OnTabChanged() {
        switch (_selectedTab) {
            case 0: // Tất cả
                LoadRecentAndFrequent();
                await LoadTrendingIfNeeded();
                break;
            case 1: // Emoji
                LoadRecentAndFrequent();
                break;
            case 2: // GIF
                await LoadTrendingGifsIfNeeded();
                break;
            case 3: // Sticker
                await LoadTrendingStickersIfNeeded();
                break;
        }
    }

    private async void ExecuteSearch() {
        var query = _searchText.Trim();
        if (string.IsNullOrEmpty(query)) {
            EmojiSearchResults.Clear();
            GifResults.Clear();
            StickerResults.Clear();
            LoadRecentAndFrequent();
            return;
        }

        IsLoading = true;

        // Search emojis
        var emojiResults = EmojiDatabase.Shared.Search(query);
        EmojiSearchResults.Clear();
        foreach (var e in emojiResults) EmojiSearchResults.Add(e);

        // Search GIFs and stickers based on current tab
        if (_selectedTab == 0 || _selectedTab == 2) {
            await KlipyApiClient.Shared.SearchAsync(query);
            GifResults.Clear();
            foreach (var g in KlipyApiClient.Shared.SearchResults) GifResults.Add(g);
        }

        if (_selectedTab == 0 || _selectedTab == 3) {
            await KlipyApiClient.Shared.SearchStickersAsync(query);
            StickerResults.Clear();
            foreach (var s in KlipyApiClient.Shared.StickerSearchResults) StickerResults.Add(s);
        }

        IsLoading = false;
    }

    private void LoadRecentAndFrequent() {
        RecentEmojis.Clear();
        foreach (var e in EmojiDatabase.Shared.GetRecentEmojis()) RecentEmojis.Add(e);

        FrequentlyUsedEmojis.Clear();
        foreach (var e in EmojiDatabase.Shared.GetFrequentlyUsedEmojis()) FrequentlyUsedEmojis.Add(e);

        RecentGifs.Clear();
        foreach (var g in KlipyApiClient.Shared.GetRecentGifs()) RecentGifs.Add(g);

        RecentStickers.Clear();
        foreach (var s in KlipyApiClient.Shared.GetRecentStickers()) RecentStickers.Add(s);
    }

    private async Task LoadTrendingIfNeeded() {
        if (KlipyApiClient.Shared.TrendingGifs.Count == 0)
            await KlipyApiClient.Shared.FetchTrendingAsync();
        if (KlipyApiClient.Shared.TrendingStickers.Count == 0)
            await KlipyApiClient.Shared.FetchTrendingStickersAsync();

        GifResults.Clear();
        foreach (var g in KlipyApiClient.Shared.TrendingGifs) GifResults.Add(g);
        StickerResults.Clear();
        foreach (var s in KlipyApiClient.Shared.TrendingStickers) StickerResults.Add(s);
    }

    private async Task LoadTrendingGifsIfNeeded() {
        if (KlipyApiClient.Shared.TrendingGifs.Count == 0)
            await KlipyApiClient.Shared.FetchTrendingAsync();

        GifResults.Clear();
        foreach (var g in KlipyApiClient.Shared.TrendingGifs) GifResults.Add(g);
    }

    private async Task LoadTrendingStickersIfNeeded() {
        if (KlipyApiClient.Shared.TrendingStickers.Count == 0)
            await KlipyApiClient.Shared.FetchTrendingStickersAsync();

        StickerResults.Clear();
        foreach (var s in KlipyApiClient.Shared.TrendingStickers) StickerResults.Add(s);
    }

    private void LoadTabPreference() {
        try {
            if (!File.Exists(_dataFilePath)) return;
            var json = File.ReadAllText(_dataFilePath);
            var prefs = System.Text.Json.JsonSerializer.Deserialize<TabPrefs>(json);
            if (prefs != null) {
                _selectedTab = prefs.LastTab is >= 0 and <= 3 ? prefs.LastTab : 0;
                _selectedSubCategory = prefs.LastSubCategory >= 0 ? prefs.LastSubCategory : 0;
            }
        } catch { }
    }

    private void SaveTabPreference() {
        try {
            var prefs = new TabPrefs { LastTab = _selectedTab, LastSubCategory = _selectedSubCategory };
            var json = System.Text.Json.JsonSerializer.Serialize(prefs);
            File.WriteAllText(_dataFilePath, json);
        } catch { }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null) {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        return true;
    }

    private sealed class TabPrefs {
        public int LastTab { get; set; }
        public int LastSubCategory { get; set; }
    }
}
