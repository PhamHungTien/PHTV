using PHTV.Windows.Models;
using System;
using System.IO;
using System.Text.Json;

namespace PHTV.Windows.Services;

public sealed class SettingsPersistenceService {
    private static readonly JsonSerializerOptions JsonOptions = new() {
        WriteIndented = true
    };

    public string AppDataDirectory { get; }
    public string SettingsFilePath { get; }

    public SettingsPersistenceService() {
        var baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        AppDataDirectory = Path.Combine(baseDir, "PHTV");
        Directory.CreateDirectory(AppDataDirectory);

        SettingsFilePath = Path.Combine(AppDataDirectory, "settings.json");
    }

    public SettingsSnapshot? Load() {
        if (!File.Exists(SettingsFilePath)) {
            return null;
        }

        var json = File.ReadAllText(SettingsFilePath);
        if (string.IsNullOrWhiteSpace(json)) {
            return null;
        }

        return JsonSerializer.Deserialize<SettingsSnapshot>(json, JsonOptions);
    }

    public void Save(SettingsSnapshot snapshot) {
        var json = JsonSerializer.Serialize(snapshot, JsonOptions);
        WriteAllTextAtomically(SettingsFilePath, json);
    }

    public void SaveToFile(SettingsSnapshot snapshot, string filePath) {
        var json = JsonSerializer.Serialize(snapshot, JsonOptions);
        WriteAllTextAtomically(filePath, json);
    }

    public SettingsSnapshot? LoadFromFile(string filePath) {
        if (!File.Exists(filePath)) {
            return null;
        }

        var json = File.ReadAllText(filePath);
        if (string.IsNullOrWhiteSpace(json)) {
            return null;
        }

        return JsonSerializer.Deserialize<SettingsSnapshot>(json, JsonOptions);
    }

    public string BuildDefaultExportPath(string prefix) {
        var docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        var exportDir = Path.Combine(docs, "PHTV");
        Directory.CreateDirectory(exportDir);
        var ts = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        return Path.Combine(exportDir, $"{prefix}-{ts}.json");
    }

    private static void WriteAllTextAtomically(string destinationPath, string content) {
        var directory = Path.GetDirectoryName(destinationPath);
        if (!string.IsNullOrWhiteSpace(directory)) {
            Directory.CreateDirectory(directory);
        }

        var tempPath = Path.Combine(
            directory ?? ".",
            $".{Path.GetFileName(destinationPath)}.{Guid.NewGuid():N}.tmp");

        try {
            File.WriteAllText(tempPath, content);
            File.Move(tempPath, destinationPath, overwrite: true);
        } finally {
            try {
                if (File.Exists(tempPath)) {
                    File.Delete(tempPath);
                }
            } catch {
                // Ignore best-effort temp cleanup.
            }
        }
    }
}
