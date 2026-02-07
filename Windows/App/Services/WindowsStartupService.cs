using Microsoft.Win32;
using System;
using System.Diagnostics;
using System.Runtime.Versioning;

namespace PHTV.Windows.Services;

public sealed class WindowsStartupService {
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string StartupEntryName = "PHTV";
    internal const string StartupLaunchArgument = "--startup";

    [SupportedOSPlatformGuard("windows")]
    public bool IsSupported => OperatingSystem.IsWindows();

    public bool IsEnabled() {
        if (!IsSupported) {
            return false;
        }

        return IsEnabledWindows();
    }

    public bool TrySetEnabled(bool enabled, out string errorMessage) {
        errorMessage = string.Empty;

        if (!IsSupported) {
            errorMessage = "Startup registry chỉ hỗ trợ trên Windows.";
            return false;
        }

        return TrySetEnabledWindows(enabled, out errorMessage);
    }

    [SupportedOSPlatform("windows")]
    private static bool IsEnabledWindows() {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
        var value = key?.GetValue(StartupEntryName) as string;
        return !string.IsNullOrWhiteSpace(value);
    }

    [SupportedOSPlatform("windows")]
    private static bool TrySetEnabledWindows(bool enabled, out string errorMessage) {
        errorMessage = string.Empty;

        try {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
            if (key is null) {
                errorMessage = "Không mở được registry startup key.";
                return false;
            }

            if (enabled) {
                var executablePath = ResolveExecutablePath();
                if (string.IsNullOrWhiteSpace(executablePath)) {
                    errorMessage = "Không xác định được đường dẫn ứng dụng.";
                    return false;
                }

                key.SetValue(StartupEntryName, BuildStartupCommand(executablePath));
            } else {
                key.DeleteValue(StartupEntryName, false);
            }

            return true;
        } catch (Exception ex) {
            errorMessage = ex.Message;
            return false;
        }
    }

    private static string ResolveExecutablePath() {
        if (!string.IsNullOrWhiteSpace(Environment.ProcessPath)) {
            return Environment.ProcessPath!;
        }

        try {
            return Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;
        } catch {
            return string.Empty;
        }
    }

    private static string BuildStartupCommand(string executablePath) {
        return $"\"{executablePath}\" {StartupLaunchArgument}";
    }
}
