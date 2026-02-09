using System.Text.Json.Serialization;

namespace PHTV.Windows.Models;

public sealed class KlipyResponse {
    [JsonPropertyName("result")]
    public bool Result { get; set; }

    [JsonPropertyName("data")]
    public KlipyData Data { get; set; } = new();
}

public sealed class KlipyData {
    [JsonPropertyName("data")]
    public List<KlipyGif> Data { get; set; } = new();

    [JsonPropertyName("current_page")]
    public int CurrentPage { get; set; }

    [JsonPropertyName("per_page")]
    public int PerPage { get; set; }

    [JsonPropertyName("has_next")]
    public bool HasNext { get; set; }
}

public sealed class KlipyGif {
    [JsonPropertyName("id")]
    public long Id { get; set; }

    [JsonPropertyName("slug")]
    public string Slug { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("file")]
    public KlipyFile File { get; set; } = new();

    [JsonPropertyName("tags")]
    public List<string>? Tags { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("impression_url")]
    public string? ImpressionUrl { get; set; }

    [JsonPropertyName("click_url")]
    public string? ClickUrl { get; set; }

    [JsonPropertyName("target_url")]
    public string? TargetUrl { get; set; }

    [JsonPropertyName("advertiser")]
    public string? Advertiser { get; set; }

    [JsonIgnore]
    public bool IsAd => string.Equals(Type, "ad", StringComparison.OrdinalIgnoreCase);

    [JsonIgnore]
    public string PreviewUrl =>
        File.Sm?.Gif?.Url ?? File.Xs?.Gif?.Url ?? File.Hd?.Gif?.Url ?? string.Empty;

    [JsonIgnore]
    public string FullUrl =>
        File.Hd?.Gif?.Url ?? File.Sm?.Gif?.Url ?? File.Xs?.Gif?.Url ?? string.Empty;

    [JsonIgnore]
    public bool HasValidUrl => !string.IsNullOrEmpty(PreviewUrl) && !string.IsNullOrEmpty(FullUrl);
}

public sealed class KlipyFile {
    [JsonPropertyName("hd")]
    public KlipyFileSize? Hd { get; set; }

    [JsonPropertyName("sm")]
    public KlipyFileSize? Sm { get; set; }

    [JsonPropertyName("xs")]
    public KlipyFileSize? Xs { get; set; }
}

public sealed class KlipyFileSize {
    [JsonPropertyName("gif")]
    public KlipyMedia? Gif { get; set; }

    [JsonPropertyName("webp")]
    public KlipyMedia? Webp { get; set; }

    [JsonPropertyName("mp4")]
    public KlipyMedia? Mp4 { get; set; }
}

public sealed class KlipyMedia {
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("width")]
    public int? Width { get; set; }

    [JsonPropertyName("height")]
    public int? Height { get; set; }

    [JsonPropertyName("size")]
    public int? Size { get; set; }
}
