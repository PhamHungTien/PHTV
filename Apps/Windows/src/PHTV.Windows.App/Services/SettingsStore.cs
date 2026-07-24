using PHTV.Windows.Contracts.Configuration;

namespace PHTV.Windows.App.Services;

internal sealed class SettingsStore
{
    private const string ProductDirectoryName = "PHTV";
    private const string SettingsFileName = "settings.json";
    private const string RuntimeSnapshotFileName = "settings.snapshot";
    private const int MaximumSettingsFileBytes = 1024 * 1024;

    private readonly string settingsDirectory;
    private readonly string settingsPath;
    private readonly string runtimeSnapshotPath;
    private static long nextRevision = DateTime.UtcNow.Ticks;

    internal SettingsStore()
    {
        settingsDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            ProductDirectoryName
        );
        settingsPath = Path.Combine(settingsDirectory, SettingsFileName);
        runtimeSnapshotPath = Path.Combine(
            settingsDirectory,
            RuntimeSnapshotFileName
        );
    }

    internal async Task<PHTVSettings> LoadAsync(
        CancellationToken cancellationToken = default
    )
    {
        if (!File.Exists(settingsPath))
        {
            var settings = new PHTVSettings();
            await EnsureRuntimeSnapshotAsync(settings, cancellationToken);
            return settings;
        }

        byte[] contents = await ReadBoundedFileAsync(
            settingsPath,
            MaximumSettingsFileBytes,
            cancellationToken
        );
        PHTVSettings settings = PHTVSettingsSerializer.Deserialize(contents);
        await EnsureRuntimeSnapshotAsync(settings, cancellationToken);
        return settings;
    }

    internal async Task SaveAsync(
        PHTVSettings settings,
        CancellationToken cancellationToken = default
    )
    {
        Directory.CreateDirectory(settingsDirectory);

        byte[] contents = PHTVSettingsSerializer.Serialize(settings);
        await WriteAtomicallyAsync(
            settingsPath,
            contents,
            cancellationToken
        );

        await WriteRuntimeSnapshotAsync(settings, cancellationToken);
    }

    private async Task EnsureRuntimeSnapshotAsync(
        PHTVSettings settings,
        CancellationToken cancellationToken
    )
    {
        if (File.Exists(runtimeSnapshotPath))
        {
            try
            {
                byte[] existing = await ReadBoundedFileAsync(
                    runtimeSnapshotPath,
                    PHTVRuntimeSettingsSnapshot.ByteLength,
                    cancellationToken
                );
                if (existing.Length == PHTVRuntimeSettingsSnapshot.ByteLength
                    && PHTVRuntimeSettingsSnapshot.TryDecode(
                        existing,
                        out RuntimeSettingsSnapshot snapshot
                    )
                    && snapshot.VietnameseEnabled
                        == settings.VietnameseEnabled
                    && snapshot.InputMethod == settings.InputMethod)
                {
                    return;
                }
            }
            catch (Exception exception) when (
                exception is IOException or InvalidDataException
            )
            {
                // A malformed or concurrently replaced snapshot is repaired
                // from the validated JSON source below.
            }
        }

        await WriteRuntimeSnapshotAsync(settings, cancellationToken);
    }

    private Task WriteRuntimeSnapshotAsync(
        PHTVSettings settings,
        CancellationToken cancellationToken
    )
    {
        ulong revision = unchecked(
            (ulong)Interlocked.Increment(ref nextRevision)
        );
        byte[] snapshot = PHTVRuntimeSettingsSnapshot.Encode(
            settings,
            revision
        );
        return WriteAtomicallyAsync(
            runtimeSnapshotPath,
            snapshot,
            cancellationToken
        );
    }

    private static async Task WriteAtomicallyAsync(
        string destinationPath,
        ReadOnlyMemory<byte> contents,
        CancellationToken cancellationToken
    )
    {
        string destinationDirectory =
            Path.GetDirectoryName(destinationPath)
            ?? throw new InvalidOperationException(
                "The settings path does not have a parent directory."
            );
        Directory.CreateDirectory(destinationDirectory);

        string destinationName = Path.GetFileName(destinationPath);
        string temporaryPath = Path.Combine(
            destinationDirectory,
            $".{destinationName}.{Guid.NewGuid():N}.tmp"
        );

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

            File.Move(temporaryPath, destinationPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static async Task<byte[]> ReadBoundedFileAsync(
        string path,
        int maximumBytes,
        CancellationToken cancellationToken
    )
    {
        await using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete,
            bufferSize: 4096,
            options: FileOptions.Asynchronous | FileOptions.SequentialScan
        );
        if (stream.Length < 0 || stream.Length > maximumBytes)
        {
            throw new InvalidDataException(
                "The PHTV settings file exceeds its size limit."
            );
        }

        var contents = new byte[checked((int)stream.Length)];
        await stream.ReadExactlyAsync(contents, cancellationToken);
        return contents;
    }
}
