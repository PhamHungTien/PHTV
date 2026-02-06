using PHTV.Windows.ViewModels;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

namespace PHTV.Windows.Services;

public sealed class BugReportService {
    public string BuildReport(SettingsState state) {
        var sb = new StringBuilder();
        var now = DateTimeOffset.Now;

        sb.AppendLine("# PHTV Bug Report");
        sb.AppendLine();
        sb.AppendLine($"- Time: {now:yyyy-MM-dd HH:mm:ss zzz}");
        sb.AppendLine($"- Severity: {Safe(state.BugSeverity)}");
        sb.AppendLine($"- Area: {Safe(state.BugArea)}");
        sb.AppendLine();

        sb.AppendLine("## Title");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.BugTitle) ? "(No title)" : state.BugTitle.Trim());
        sb.AppendLine();

        sb.AppendLine("## Description");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.BugDescription) ? "(No description)" : state.BugDescription.Trim());
        sb.AppendLine();

        sb.AppendLine("## Steps To Reproduce");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.StepsToReproduce) ? "(Not provided)" : state.StepsToReproduce.Trim());
        sb.AppendLine();

        sb.AppendLine("## Expected Result");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.ExpectedResult) ? "(Not provided)" : state.ExpectedResult.Trim());
        sb.AppendLine();

        sb.AppendLine("## Actual Result");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.ActualResult) ? "(Not provided)" : state.ActualResult.Trim());
        sb.AppendLine();

        sb.AppendLine("## Contact");
        sb.AppendLine(string.IsNullOrWhiteSpace(state.ContactEmail) ? "(Not provided)" : state.ContactEmail.Trim());
        sb.AppendLine();

        if (state.IncludeSystemInfo) {
            sb.AppendLine("## System Info");
            AppendSystemInfo(sb, state);
            sb.AppendLine();
        }

        if (state.IncludeLogs) {
            sb.AppendLine("## Logs");
            var logs = LoadLogs();
            if (logs.Count == 0) {
                sb.AppendLine("(No logs found)");
            } else {
                sb.AppendLine("```text");
                foreach (var line in logs) {
                    sb.AppendLine(line);
                }
                sb.AppendLine("```");
            }
            sb.AppendLine();
        }

        if (state.IncludeCrashLogs) {
            sb.AppendLine("## Crash Logs");
            sb.AppendLine("Crash logs are not available in this build yet.");
            sb.AppendLine();
        }

        return sb.ToString();
    }

    public string BuildGitHubIssueUrl(SettingsState state, string reportBody) {
        var title = state.BugTitle;
        if (string.IsNullOrWhiteSpace(title)) {
            title = "Bug report from Windows app";
        }

        var encodedTitle = Uri.EscapeDataString(title);
        var encodedBody = Uri.EscapeDataString(reportBody);
        return $"https://github.com/PhamHungTien/PHTV/issues/new?title={encodedTitle}&body={encodedBody}";
    }

    public string BuildMailToUrl(SettingsState state, string reportBody) {
        var subject = string.IsNullOrWhiteSpace(state.BugTitle)
            ? "PHTV Bug Report"
            : $"PHTV Bug Report: {state.BugTitle.Trim()}";

        var encodedSubject = Uri.EscapeDataString(subject);
        var encodedBody = Uri.EscapeDataString(reportBody);
        return $"mailto:phamhungtien.contact@gmail.com?subject={encodedSubject}&body={encodedBody}";
    }

    public string BuildDefaultFileName() {
        return $"phtv-bug-report-{DateTime.Now:yyyyMMdd-HHmmss}.md";
    }

    private static void AppendSystemInfo(StringBuilder sb, SettingsState state) {
        var version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "unknown";
        var culture = CultureInfo.CurrentUICulture.Name;

        sb.AppendLine($"- App version: {version}");
        sb.AppendLine($"- OS: {RuntimeInformation.OSDescription}");
        sb.AppendLine($"- Process architecture: {RuntimeInformation.ProcessArchitecture}");
        sb.AppendLine($"- Framework: {RuntimeInformation.FrameworkDescription}");
        sb.AppendLine($"- Language mode: {(state.IsVietnameseEnabled ? "Vietnamese" : "English")}");
        sb.AppendLine($"- Input method: {Safe(state.InputMethod)}");
        sb.AppendLine($"- Code table: {Safe(state.CodeTable)}");
        sb.AppendLine($"- Locale: {culture}");
    }

    private static List<string> LoadLogs() {
        var candidates = new[] {
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PHTV",
                "phtv.log"),
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PHTV",
                "logs",
                "phtv.log")
        };

        foreach (var path in candidates) {
            try {
                if (!File.Exists(path)) {
                    continue;
                }

                var lines = File.ReadAllLines(path);
                return lines.TakeLast(300).ToList();
            } catch {
                // Ignore malformed log file and try next path.
            }
        }

        return new List<string>();
    }

    private static string Safe(string value) {
        return string.IsNullOrWhiteSpace(value) ? "(empty)" : value.Trim();
    }
}
