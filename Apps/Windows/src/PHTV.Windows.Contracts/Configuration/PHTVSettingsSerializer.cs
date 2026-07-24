using System.Text.Json;

namespace PHTV.Windows.Contracts.Configuration;

public static class PHTVSettingsSerializer
{
    public static PHTVSettings Deserialize(ReadOnlySpan<byte> utf8Json)
    {
        PHTVSettings? settings = JsonSerializer.Deserialize(
            utf8Json,
            PHTVSettingsJsonContext.Default.PHTVSettings
        );

        if (settings is null)
        {
            throw new JsonException("The PHTV settings document is empty.");
        }

        if (settings.SchemaVersion is < 1 or > PHTVSettings.CurrentSchemaVersion)
        {
            throw new JsonException(
                $"Unsupported PHTV settings schema {settings.SchemaVersion}."
            );
        }

        return settings.Normalize();
    }

    public static byte[] Serialize(PHTVSettings settings) =>
        JsonSerializer.SerializeToUtf8Bytes(
            settings.Normalize(),
            PHTVSettingsJsonContext.Default.PHTVSettings
        );
}
