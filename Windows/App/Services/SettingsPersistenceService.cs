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
        File.WriteAllText(SettingsFilePath, json);
    }

    public void SaveToFile(SettingsSnapshot snapshot, string filePath) {
        var json = JsonSerializer.Serialize(snapshot, JsonOptions);
        File.WriteAllText(filePath, json);
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
}
