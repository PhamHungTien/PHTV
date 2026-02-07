using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace PHTV.Windows.Services;

public record RunningAppInfo(string Name, string ExeName, string Path);

public sealed class AppDiscoveryService {
    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder strText, int maxCount);

    public List<RunningAppInfo> GetRunningApps() {
        var results = new List<RunningAppInfo>();
        var seenExeNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Get all processes with a main window handle
        var processes = Process.GetProcesses()
            .Where(p => p.MainWindowHandle != IntPtr.Zero && IsWindowVisible(p.MainWindowHandle))
            .OrderBy(p => p.ProcessName);

        foreach (var p in processes) {
            try {
                string exePath = p.MainModule?.FileName ?? string.Empty;
                string exeName = Path.GetFileName(exePath);
                
                if (string.IsNullOrEmpty(exeName)) {
                    exeName = p.ProcessName + ".exe";
                }

                if (seenExeNames.Contains(exeName)) continue;

                // Try to get a friendly name from the window title or process name
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(p.MainWindowHandle, sb, 256);
                string title = sb.ToString();
                
                string friendlyName = !string.IsNullOrWhiteSpace(title) 
                    ? ExtractAppNameFromTitle(title, p.ProcessName)
                    : p.ProcessName;

                results.Add(new RunningAppInfo(friendlyName, exeName, exePath));
                seenExeNames.Add(exeName);
            } catch {
                // Some processes (system/protected) won't allow access to MainModule
            }
        }

        return results.OrderBy(a => a.Name).ToList();
    }

    private static string ExtractAppNameFromTitle(string title, string processName) {
        // Simple logic: titles often look like "Document - AppName" or "App Name"
        if (title.Contains(" - ")) {
            var parts = title.Split(" - ");
            return parts.Last().Trim();
        }
        return title.Trim();
    }
}
