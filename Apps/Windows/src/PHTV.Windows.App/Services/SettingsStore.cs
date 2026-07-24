using PHTV.Windows.Contracts.Configuration;

namespace PHTV.Windows.App.Services;

internal sealed class SettingsStore
{
    private const string ProductDirectoryName = "PHTV";
    private const string SettingsFileName = "settings.json";

    private readonly string settingsDirectory;
    private readonly string settingsPath;

    internal SettingsStore()
    {
        settingsDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            ProductDirectoryName
        );
        settingsPath = Path.Combine(settingsDirectory, SettingsFileName);
    }

    internal async Task<PHTVSettings> LoadAsync(
        CancellationToken cancellationToken = default
    )
    {
        if (!File.Exists(settingsPath))
        {
            return new PHTVSettings();
        }

        byte[] contents = await File.ReadAllBytesAsync(
            settingsPath,
            cancellationToken
        );
        return PHTVSettingsSerializer.Deserialize(contents);
    }

    internal async Task SaveAsync(
        PHTVSettings settings,
        CancellationToken cancellationToken = default
    )
    {
        Directory.CreateDirectory(settingsDirectory);

        string temporaryPath = Path.Combine(
            settingsDirectory,
            $".{SettingsFileName}.{Guid.NewGuid():N}.tmp"
        );
        byte[] contents = PHTVSettingsSerializer.Serialize(settings);

        try
        {
            await using (
                var stream = new FileStream(
                    temporaryPath,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None,
                    bufferSize: 4096,
                    options: FileOptions.Asynchronous | FileOptions.WriteThrough
                )
            )
            {
                await stream.WriteAsync(contents, cancellationToken);
                await stream.FlushAsync(cancellationToken);
                stream.Flush(flushToDisk: true);
            }

            File.Move(temporaryPath, settingsPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }
}
