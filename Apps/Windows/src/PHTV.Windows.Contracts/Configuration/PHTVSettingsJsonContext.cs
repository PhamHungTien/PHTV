using System.Text.Json.Serialization;

namespace PHTV.Windows.Contracts.Configuration;

[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    WriteIndented = true,
    GenerationMode = JsonSourceGenerationMode.Metadata
)]
[JsonSerializable(typeof(PHTVSettings))]
internal sealed partial class PHTVSettingsJsonContext : JsonSerializerContext;
