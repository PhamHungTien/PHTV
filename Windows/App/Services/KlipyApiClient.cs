using System.ComponentModel;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using PHTV.Windows.Models;

namespace PHTV.Windows.Services;

public sealed class KlipyApiClient : INotifyPropertyChanged {
    public static readonly KlipyApiClient Shared = new();

    private static string AppKey {
        get {
            var parts = new[] {
                "dRJwhLos61B0a1SE72uH",
                "IyLBNKRtPJAalMjeys",
                "Vegy2YDjuTWa29PKT7jQ1M7pt1"
            };
            return string.Concat(parts);
        }
    }

    private const string BaseUrl = "https://api.klipy.com/api/v1";
    private const string Domain = "phamhungtien.github.io";
    private const int MaxRecentItems = 20;

    private readonly HttpClient _httpClient = new();
    private readonly string _customerId;
    private readonly string _dataFilePath;

    private List<KlipyGif> _trendingGifs = new();
    private List<KlipyGif> _searchResults = new();
    private List<KlipyGif> _trendingStickers = new();
    private List<KlipyGif> _stickerSearchResults = new();
    private bool _isLoading;
    private List<long> _recentGifIds = new();
    private List<long> _recentStickerIds = new();

    public List<KlipyGif> TrendingGifs {
        get => _trendingGifs;
        private set => SetField(ref _trendingGifs, value);
    }

    public List<KlipyGif> SearchResults {
        get => _searchResults;
        private set => SetField(ref _searchResults, value);
    }

    public List<KlipyGif> TrendingStickers {
        get => _trendingStickers;
        private set => SetField(ref _trendingStickers, value);
    }

    public List<KlipyGif> StickerSearchResults {
        get => _stickerSearchResults;
        private set => SetField(ref _stickerSearchResults, value);
    }

    public bool IsLoading {
        get => _isLoading;
        private set => SetField(ref _isLoading, value);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private KlipyApiClient() {
        var appData = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PHTV");
        Directory.CreateDirectory(appData);
        _dataFilePath = Path.Combine(appData, "picker-data.json");

        _customerId = LoadOrCreateCustomerId();
        LoadRecentData();

        Task.Run(CleanOldCache);
    }

    public async Task FetchTrendingAsync(int limit = 24) {
        IsLoading = true;
        try {
            var url = $"{BaseUrl}/{AppKey}/gifs/trending?customer_id={_customerId}&per_page={limit}&domain={Domain}";
            var json = await _httpClient.GetStringAsync(url);
            var result = JsonSerializer.Deserialize<KlipyResponse>(json);
            if (result?.Result == true)
                TrendingGifs = result.Data.Data.Where(g => g.HasValidUrl).ToList();
        } catch {
            // Ignore network errors
        } finally {
            IsLoading = false;
        }
    }

    public async Task SearchAsync(string query, int limit = 24) {
        if (string.IsNullOrWhiteSpace(query)) {
            SearchResults = new();
            return;
        }

        IsLoading = true;
        try {
            var encoded = Uri.EscapeDataString(query);
            var url = $"{BaseUrl}/{AppKey}/gifs/search?q={encoded}&customer_id={_customerId}&per_page={limit}&domain={Domain}";
            var json = await _httpClient.GetStringAsync(url);
            var result = JsonSerializer.Deserialize<KlipyResponse>(json);
            if (result?.Result == true)
                SearchResults = result.Data.Data.Where(g => g.HasValidUrl).ToList();
        } catch {
            // Ignore network errors
        } finally {
            IsLoading = false;
        }
    }

    public async Task FetchTrendingStickersAsync(int limit = 24) {
        IsLoading = true;
        try {
            var url = $"{BaseUrl}/{AppKey}/stickers/trending?customer_id={_customerId}&per_page={limit}&domain={Domain}";
            var json = await _httpClient.GetStringAsync(url);
            var result = JsonSerializer.Deserialize<KlipyResponse>(json);
            if (result?.Result == true)
                TrendingStickers = result.Data.Data.Where(g => g.HasValidUrl).ToList();
        } catch {
            // Ignore network errors
        } finally {
            IsLoading = false;
        }
    }

    public async Task SearchStickersAsync(string query, int limit = 24) {
        if (string.IsNullOrWhiteSpace(query)) {
            StickerSearchResults = new();
            return;
        }

        IsLoading = true;
        try {
            var encoded = Uri.EscapeDataString(query);
            var url = $"{BaseUrl}/{AppKey}/stickers/search?q={encoded}&customer_id={_customerId}&per_page={limit}&domain={Domain}";
            var json = await _httpClient.GetStringAsync(url);
            var result = JsonSerializer.Deserialize<KlipyResponse>(json);
            if (result?.Result == true)
                StickerSearchResults = result.Data.Data.Where(g => g.HasValidUrl).ToList();
        } catch {
            // Ignore network errors
        } finally {
            IsLoading = false;
        }
    }

    public void RecordGifUsage(KlipyGif gif) {
        _recentGifIds.Remove(gif.Id);
        _recentGifIds.Insert(0, gif.Id);
        if (_recentGifIds.Count > MaxRecentItems)
            _recentGifIds = _recentGifIds.Take(MaxRecentItems).ToList();
        SaveRecentData();
    }

    public void RecordStickerUsage(KlipyGif sticker) {
        _recentStickerIds.Remove(sticker.Id);
        _recentStickerIds.Insert(0, sticker.Id);
        if (_recentStickerIds.Count > MaxRecentItems)
            _recentStickerIds = _recentStickerIds.Take(MaxRecentItems).ToList();
        SaveRecentData();
    }

    public List<KlipyGif> GetRecentGifs() {
        var all = TrendingGifs.Concat(SearchResults).ToList();
        return _recentGifIds
            .Select(id => all.FirstOrDefault(g => g.Id == id))
            .Where(g => g != null)
            .Cast<KlipyGif>()
            .ToList();
    }

    public List<KlipyGif> GetRecentStickers() {
        var all = TrendingStickers.Concat(StickerSearchResults).ToList();
        return _recentStickerIds
            .Select(id => all.FirstOrDefault(g => g.Id == id))
            .Where(g => g != null)
            .Cast<KlipyGif>()
            .ToList();
    }

    public async Task<string?> DownloadMediaAsync(KlipyGif gif) {
        try {
            var cacheDir = Path.Combine(Path.GetTempPath(), "PHTPMedia");
            Directory.CreateDirectory(cacheDir);

            var ext = gif.FullUrl.Contains(".png", StringComparison.OrdinalIgnoreCase) ? ".png" : ".gif";
            var filePath = Path.Combine(cacheDir, $"{gif.Id}{ext}");

            if (File.Exists(filePath)) return filePath;

            var data = await _httpClient.GetByteArrayAsync(gif.FullUrl);
            await File.WriteAllBytesAsync(filePath, data);
            return filePath;
        } catch {
            return null;
        }
    }

    public void TrackImpression(KlipyGif gif) {
        if (!gif.IsAd || string.IsNullOrEmpty(gif.ImpressionUrl)) return;
        _ = _httpClient.GetAsync(gif.ImpressionUrl);
    }

    public void TrackClick(KlipyGif gif) {
        if (!gif.IsAd || string.IsNullOrEmpty(gif.ClickUrl)) return;
        _ = _httpClient.GetAsync(gif.ClickUrl);
    }

    private void CleanOldCache() {
        try {
            var cacheDir = Path.Combine(Path.GetTempPath(), "PHTPMedia");
            if (!Directory.Exists(cacheDir)) {
                Directory.CreateDirectory(cacheDir);
                return;
            }

            var sevenDaysAgo = DateTime.Now.AddDays(-7);
            var files = new DirectoryInfo(cacheDir).GetFiles("*.gif")
                .Concat(new DirectoryInfo(cacheDir).GetFiles("*.png"))
                .ToList();

            long totalSize = 0;
            var oldFiles = new List<FileInfo>();

            foreach (var file in files) {
                totalSize += file.Length;
                if (file.CreationTime < sevenDaysAgo)
                    oldFiles.Add(file);
            }

            foreach (var file in oldFiles) {
                try { file.Delete(); } catch { }
            }

            const long maxCacheSize = 100 * 1024 * 1024;
            const long targetCacheSize = 50 * 1024 * 1024;

            if (totalSize > maxCacheSize) {
                var sorted = files.OrderBy(f => f.CreationTime).ToList();
                var currentSize = totalSize;
                foreach (var file in sorted) {
                    if (currentSize <= targetCacheSize) break;
                    var size = file.Length;
                    try { file.Delete(); currentSize -= size; } catch { }
                }
            }
        } catch {
            // Ignore cache cleanup errors
        }
    }

    private string LoadOrCreateCustomerId() {
        try {
            if (File.Exists(_dataFilePath)) {
                var json = File.ReadAllText(_dataFilePath);
                var data = JsonSerializer.Deserialize<PickerPersistData>(json);
                if (!string.IsNullOrEmpty(data?.CustomerId))
                    return data.CustomerId;
            }
        } catch { }

        var newId = Guid.NewGuid().ToString();
        SaveCustomerId(newId);
        return newId;
    }

    private void SaveCustomerId(string id) {
        try {
            PickerPersistData data;
            if (File.Exists(_dataFilePath)) {
                var json = File.ReadAllText(_dataFilePath);
                data = JsonSerializer.Deserialize<PickerPersistData>(json) ?? new();
            } else {
                data = new();
            }
            data.CustomerId = id;
            File.WriteAllText(_dataFilePath, JsonSerializer.Serialize(data,
                new JsonSerializerOptions { WriteIndented = true }));
        } catch { }
    }

    private void LoadRecentData() {
        try {
            if (!File.Exists(_dataFilePath)) return;
            var json = File.ReadAllText(_dataFilePath);
            var data = JsonSerializer.Deserialize<PickerPersistData>(json);
            if (data == null) return;
            _recentGifIds = data.RecentGifIds ?? new();
            _recentStickerIds = data.RecentStickerIds ?? new();
        } catch { }
    }

    private void SaveRecentData() {
        try {
            PickerPersistData data;
            if (File.Exists(_dataFilePath)) {
                var json = File.ReadAllText(_dataFilePath);
                data = JsonSerializer.Deserialize<PickerPersistData>(json) ?? new();
            } else {
                data = new();
            }
            data.RecentGifIds = _recentGifIds;
            data.RecentStickerIds = _recentStickerIds;
            File.WriteAllText(_dataFilePath, JsonSerializer.Serialize(data,
                new JsonSerializerOptions { WriteIndented = true }));
        } catch { }
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? name = null) {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    private sealed class PickerPersistData {
        [JsonPropertyName("customer_id")]
        public string CustomerId { get; set; } = string.Empty;

        [JsonPropertyName("recent_gif_ids")]
        public List<long> RecentGifIds { get; set; } = new();

        [JsonPropertyName("recent_sticker_ids")]
        public List<long> RecentStickerIds { get; set; } = new();
    }
}
