using Microsoft.Win32;
using PHTV.Windows.ViewModels;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text;

namespace PHTV.Windows.Services;

public sealed class RuntimeBridgeService {
    private const string RuntimeConfigFileName = "runtime-config.ini";
    private const string RuntimeMacrosFileName = "runtime-macros.tsv";
    private const string EnglishDictionaryFileName = "en_dict.bin";
    private const string VietnameseDictionaryFileName = "vi_dict.bin";
    private const string DaemonProcessName = "phtv_windows_hook_daemon";
    private const string DaemonExecutableName = "phtv_windows_hook_daemon.exe";
    private const string TsfDllName = "phtv_windows_tsf.dll";
    private const string TsfRegisterToolName = "phtv_windows_tsf_register.exe";
    private const string TsfServiceClsid = "{44F4C999-7F50-4F7E-A69E-7A8DEB035246}";
    private const int TsfToolTimeoutMs = 15000;
    private const string BundledNativeRootResourceName = "PHTV.Native";

    private const int SwitchKeyDefault = 0x9FE; // Ctrl + Shift + no primary key
    private const int SwitchKeyNoPrimary = 0xFE;
    private const int ModifierControlBit = 1 << 8;
    private const int ModifierOptionBit = 1 << 9;
    private const int ModifierCommandBit = 1 << 10;
    private const int ModifierShiftBit = 1 << 11;
    private const int ModifierFnBit = 1 << 12;

    // Internal engine keycode constants (must match Shared/Platforms/phtv_*_keys.h).
    private const int KeyEsc = 53;
    private const int KeyDelete = 51;
    private const int KeyTab = 48;
    private const int KeyEnter = 76;
    private const int KeyReturn = 36;
    private const int KeySpace = 49;

    private const int KeyA = 0;
    private const int KeyB = 11;
    private const int KeyC = 8;
    private const int KeyD = 2;
    private const int KeyE = 14;
    private const int KeyF = 3;
    private const int KeyG = 5;
    private const int KeyH = 4;
    private const int KeyI = 34;
    private const int KeyJ = 38;
    private const int KeyK = 40;
    private const int KeyL = 37;
    private const int KeyM = 46;
    private const int KeyN = 45;
    private const int KeyO = 31;
    private const int KeyP = 35;
    private const int KeyQ = 12;
    private const int KeyR = 15;
    private const int KeyS = 1;
    private const int KeyT = 17;
    private const int KeyU = 32;
    private const int KeyV = 9;
    private const int KeyW = 13;
    private const int KeyX = 7;
    private const int KeyY = 16;
    private const int KeyZ = 6;

    private const int Key1 = 18;
    private const int Key2 = 19;
    private const int Key3 = 20;
    private const int Key4 = 21;
    private const int Key5 = 23;
    private const int Key6 = 22;
    private const int Key7 = 26;
    private const int Key8 = 28;
    private const int Key9 = 25;
    private const int Key0 = 29;

    private const int KeyBackquote = 50;
    private const int KeyMinus = 27;
    private const int KeyEquals = 24;
    private const int KeyLeftBracket = 33;
    private const int KeyRightBracket = 30;
    private const int KeyBackSlash = 42;
    private const int KeySemicolon = 41;
    private const int KeyQuote = 39;
    private const int KeyComma = 43;
    private const int KeyDot = 47;
    private const int KeySlash = 44;

    private const int KeyLeftShift = 57;
    private const int KeyLeftControl = 59;
    private const int KeyLeftOption = 58;
    private const int KeyLeftCommand = 55;
    private const int KeyFunction = 63;

    private static readonly UTF8Encoding Utf8WithoutBom = new(false);
    private string _cachedDaemonPath = string.Empty;
    private string _cachedTsfDllPath = string.Empty;
    private string _cachedTsfRegisterToolPath = string.Empty;

    private static readonly Dictionary<string, int> PrimaryHotkeyMap = new(StringComparer.OrdinalIgnoreCase) {
        ["a"] = KeyA,
        ["b"] = KeyB,
        ["c"] = KeyC,
        ["d"] = KeyD,
        ["e"] = KeyE,
        ["f"] = KeyF,
        ["g"] = KeyG,
        ["h"] = KeyH,
        ["i"] = KeyI,
        ["j"] = KeyJ,
        ["k"] = KeyK,
        ["l"] = KeyL,
        ["m"] = KeyM,
        ["n"] = KeyN,
        ["o"] = KeyO,
        ["p"] = KeyP,
        ["q"] = KeyQ,
        ["r"] = KeyR,
        ["s"] = KeyS,
        ["t"] = KeyT,
        ["u"] = KeyU,
        ["v"] = KeyV,
        ["w"] = KeyW,
        ["x"] = KeyX,
        ["y"] = KeyY,
        ["z"] = KeyZ,
        ["1"] = Key1,
        ["2"] = Key2,
        ["3"] = Key3,
        ["4"] = Key4,
        ["5"] = Key5,
        ["6"] = Key6,
        ["7"] = Key7,
        ["8"] = Key8,
        ["9"] = Key9,
        ["0"] = Key0,
        ["esc"] = KeyEsc,
        ["escape"] = KeyEsc,
        ["delete"] = KeyDelete,
        ["backspace"] = KeyDelete,
        ["tab"] = KeyTab,
        ["enter"] = KeyEnter,
        ["return"] = KeyReturn,
        ["space"] = KeySpace,
        ["spacebar"] = KeySpace,
        ["`"] = KeyBackquote,
        ["-"] = KeyMinus,
        ["="] = KeyEquals,
        ["["] = KeyLeftBracket,
        ["]"] = KeyRightBracket,
        ["\\"] = KeyBackSlash,
        [";"] = KeySemicolon,
        ["'"] = KeyQuote,
        [","] = KeyComma,
        ["."] = KeyDot,
        ["/"] = KeySlash
    };

    public RuntimeBridgeService() {
        RuntimeDirectory = ResolveRuntimeDirectory();
        Directory.CreateDirectory(RuntimeDirectory);
        RuntimeConfigPath = Path.Combine(RuntimeDirectory, RuntimeConfigFileName);
        RuntimeMacrosPath = Path.Combine(RuntimeDirectory, RuntimeMacrosFileName);
        EnsureBundledNativeArtifacts();
    }

    public string RuntimeDirectory { get; }
    public string RuntimeConfigPath { get; }
    public string RuntimeMacrosPath { get; }

    public bool IsSupported => OperatingSystem.IsWindows();

    public void WriteRuntimeArtifacts(SettingsState state) {
        Directory.CreateDirectory(RuntimeDirectory);

        var runtimeConfig = BuildRuntimeConfigContent(state);
        File.WriteAllText(RuntimeConfigPath, runtimeConfig, Utf8WithoutBom);

        var runtimeMacros = BuildRuntimeMacrosContent(state);
        File.WriteAllText(RuntimeMacrosPath, runtimeMacros, Utf8WithoutBom);
    }

    public bool IsDaemonRunning() {
        if (!IsSupported) {
            return false;
        }

        try {
            var processes = Process.GetProcessesByName(DaemonProcessName);
            return processes.Any(process => !process.HasExited);
        } catch {
            return false;
        }
    }

    public bool TryStartDaemon(out string message) {
        message = string.Empty;

        if (!IsSupported) {
            message = "Hook daemon chỉ hỗ trợ trên Windows.";
            return false;
        }

        if (IsDaemonRunning()) {
            message = "Hook daemon đã chạy.";
            return true;
        }

        var daemonPath = ResolveDaemonPath();
        if (string.IsNullOrWhiteSpace(daemonPath)) {
            message = "Không tìm thấy phtv_windows_hook_daemon.exe.";
            return false;
        }

        try {
            var processStartInfo = new ProcessStartInfo {
                FileName = daemonPath,
                WorkingDirectory = Path.GetDirectoryName(daemonPath) ?? RuntimeDirectory,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            ApplyDaemonEnvironment(processStartInfo, daemonPath);
            var hasEnglishDictionary = processStartInfo.Environment.ContainsKey("PHTV_EN_DICT_PATH");
            var hasVietnameseDictionary = processStartInfo.Environment.ContainsKey("PHTV_VI_DICT_PATH");
            var process = Process.Start(processStartInfo);

            if (process is null) {
                message = "Không thể khởi chạy hook daemon.";
                return false;
            }

            message = hasEnglishDictionary && hasVietnameseDictionary
                ? "Đã khởi chạy hook daemon."
                : "Đã khởi chạy hook daemon (thiếu file từ điển, Auto English có thể không hoạt động).";
            return true;
        } catch (Exception ex) {
            message = ex.Message;
            return false;
        }
    }

    public bool TryStopDaemon(out string message) {
        message = string.Empty;

        if (!IsSupported) {
            message = "Hook daemon chỉ hỗ trợ trên Windows.";
            return false;
        }

        try {
            var processes = Process.GetProcessesByName(DaemonProcessName);
            if (processes.Length == 0) {
                message = "Hook daemon chưa chạy.";
                return true;
            }

            foreach (var process in processes) {
                try {
                    if (!process.HasExited) {
                        process.Kill(true);
                        process.WaitForExit(1200);
                    }
                } catch {
                    // Continue stopping other processes.
                } finally {
                    process.Dispose();
                }
            }

            message = "Đã dừng hook daemon.";
            return true;
        } catch (Exception ex) {
            message = ex.Message;
            return false;
        }
    }

    public bool TryRestartDaemon(out string message) {
        message = string.Empty;

        if (!TryStopDaemon(out var stopMessage)) {
            message = stopMessage;
            return false;
        }

        if (!TryStartDaemon(out var startMessage)) {
            message = startMessage;
            return false;
        }

        message = $"{stopMessage} {startMessage}".Trim();
        return true;
    }

    [SupportedOSPlatform("windows")]
    public bool IsTsfRegistered() {
        if (!OperatingSystem.IsWindows()) {
            return false;
        }

        try {
            using var key = Registry.CurrentUser.OpenSubKey($@"Software\Classes\CLSID\{TsfServiceClsid}\InprocServer32");
            if (key is null) {
                return false;
            }

            var value = key.GetValue(null) as string;
            if (string.IsNullOrWhiteSpace(value)) {
                return false;
            }

            var normalized = value.Trim();
            return File.Exists(normalized);
        } catch {
            return false;
        }
    }

    public bool TryRegisterTsf(out string message) {
        message = string.Empty;

        if (!OperatingSystem.IsWindows()) {
            message = "TSF chỉ hỗ trợ trên Windows.";
            return false;
        }

        var registerToolPath = ResolveTsfRegisterToolPath();
        if (string.IsNullOrWhiteSpace(registerToolPath)) {
            message = "Không tìm thấy phtv_windows_tsf_register.exe.";
            return false;
        }

        var dllPath = ResolveTsfDllPath();
        if (string.IsNullOrWhiteSpace(dllPath)) {
            message = "Không tìm thấy phtv_windows_tsf.dll.";
            return false;
        }

        return TryRunRegisterTool(registerToolPath, $"\"{dllPath}\"", out message);
    }

    public bool TryUnregisterTsf(out string message) {
        message = string.Empty;

        if (!OperatingSystem.IsWindows()) {
            message = "TSF chỉ hỗ trợ trên Windows.";
            return false;
        }

        var registerToolPath = ResolveTsfRegisterToolPath();
        if (string.IsNullOrWhiteSpace(registerToolPath)) {
            message = "Không tìm thấy phtv_windows_tsf_register.exe.";
            return false;
        }

        var dllPath = ResolveTsfDllPath();
        if (string.IsNullOrWhiteSpace(dllPath)) {
            dllPath = ResolveRegisteredTsfDllPath();
        }

        if (string.IsNullOrWhiteSpace(dllPath)) {
            message = "Không tìm thấy phtv_windows_tsf.dll để thực hiện hủy đăng ký.";
            return false;
        }

        return TryRunRegisterTool(registerToolPath, $"/u \"{dllPath}\"", out message);
    }

    public bool TryOpenWindowsLanguageSettings(out string message) {
        message = string.Empty;

        if (!OperatingSystem.IsWindows()) {
            message = "Tính năng này chỉ hỗ trợ trên Windows.";
            return false;
        }

        try {
            Process.Start(new ProcessStartInfo {
                FileName = "ms-settings:regionlanguage",
                UseShellExecute = true
            });
            message = "Đã mở Windows Language settings.";
            return true;
        } catch (Exception ex) {
            message = ex.Message;
            return false;
        }
    }

    public string ResolveDaemonPath() {
        return ResolveNativeArtifactPath("PHTV_HOOK_DAEMON_PATH", DaemonExecutableName, ref _cachedDaemonPath);
    }

    public string ResolveTsfDllPath() {
        return ResolveNativeArtifactPath("PHTV_TSF_DLL_PATH", TsfDllName, ref _cachedTsfDllPath);
    }

    public string ResolveTsfRegisterToolPath() {
        return ResolveNativeArtifactPath("PHTV_TSF_REGISTER_TOOL_PATH",
                                         TsfRegisterToolName,
                                         ref _cachedTsfRegisterToolPath);
    }

    [SupportedOSPlatform("windows")]
    public string ResolveRegisteredTsfDllPath() {
        if (!OperatingSystem.IsWindows()) {
            return string.Empty;
        }

        try {
            using var key = Registry.CurrentUser.OpenSubKey($@"Software\Classes\CLSID\{TsfServiceClsid}\InprocServer32");
            var value = key?.GetValue(null) as string;
            if (string.IsNullOrWhiteSpace(value)) {
                return string.Empty;
            }

            return value.Trim();
        } catch {
            return string.Empty;
        }
    }

    private bool TryRunRegisterTool(string registerToolPath, string arguments, out string message) {
        message = string.Empty;

        try {
            using var process = new Process {
                StartInfo = new ProcessStartInfo {
                    FileName = registerToolPath,
                    Arguments = arguments,
                    WorkingDirectory = Path.GetDirectoryName(registerToolPath) ?? RuntimeDirectory,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                }
            };

            if (!process.Start()) {
                message = "Không thể khởi chạy TSF register tool.";
                return false;
            }

            if (!process.WaitForExit(TsfToolTimeoutMs)) {
                try {
                    process.Kill(true);
                } catch {
                    // Ignore kill failures if the process already exits.
                }

                message = "TSF register tool quá thời gian chờ.";
                return false;
            }

            var standardOutput = process.StandardOutput.ReadToEnd().Trim();
            var standardError = process.StandardError.ReadToEnd().Trim();

            if (process.ExitCode == 0) {
                message = string.IsNullOrWhiteSpace(standardOutput)
                    ? "Thao tác TSF hoàn tất."
                    : standardOutput;
                return true;
            }

            message = string.IsNullOrWhiteSpace(standardError)
                ? (string.IsNullOrWhiteSpace(standardOutput)
                    ? $"TSF register tool trả về mã lỗi {process.ExitCode}."
                    : standardOutput)
                : standardError;
            return false;
        } catch (Exception ex) {
            message = ex.Message;
            return false;
        }
    }

    private string ResolveNativeArtifactPath(string environmentVariableName,
                                             string fileName,
                                             ref string cachedPath) {
        var fromEnvironment = Environment.GetEnvironmentVariable(environmentVariableName);
        if (!string.IsNullOrWhiteSpace(fromEnvironment) && File.Exists(fromEnvironment)) {
            cachedPath = Path.GetFullPath(fromEnvironment);
            return cachedPath;
        }

        if (!string.IsNullOrWhiteSpace(cachedPath) && File.Exists(cachedPath)) {
            return cachedPath;
        }

        var knownCandidates = new List<string> {
            Path.Combine(AppContext.BaseDirectory, fileName),
            Path.Combine(AppContext.BaseDirectory, "native", fileName),
            Path.Combine(RuntimeDirectory, "bin", fileName),
            Path.Combine(RuntimeDirectory, "bin", GetCurrentWindowsRuntimeMoniker(), fileName)
        };

        knownCandidates.AddRange(BuildPathCandidates(AppContext.BaseDirectory, fileName));
        knownCandidates.AddRange(BuildPathCandidates(Environment.CurrentDirectory, fileName));

        var visitedPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var candidate in knownCandidates) {
            if (string.IsNullOrWhiteSpace(candidate)) {
                continue;
            }

            var normalized = Path.GetFullPath(candidate);
            if (!visitedPaths.Add(normalized)) {
                continue;
            }

            if (!File.Exists(normalized)) {
                continue;
            }

            cachedPath = normalized;
            return normalized;
        }

        cachedPath = string.Empty;
        return string.Empty;
    }

    private string ResolveRuntimeDictionaryPath(string fileName, string daemonPath) {
        var runtimeMoniker = GetCurrentWindowsRuntimeMoniker();
        var candidates = new[] {
            Path.Combine(Path.GetDirectoryName(daemonPath) ?? string.Empty, fileName),
            Path.Combine(RuntimeDirectory, "bin", runtimeMoniker, fileName),
            Path.Combine(RuntimeDirectory, "bin", fileName),
            Path.Combine(RuntimeDirectory, fileName)
        };

        foreach (var candidate in candidates) {
            if (string.IsNullOrWhiteSpace(candidate)) {
                continue;
            }

            var normalized = Path.GetFullPath(candidate);
            if (File.Exists(normalized)) {
                return normalized;
            }
        }

        return string.Empty;
    }

    private void ApplyDaemonEnvironment(ProcessStartInfo processStartInfo, string daemonPath) {
        processStartInfo.Environment["PHTV_RUNTIME_DIR"] = RuntimeDirectory;

        var englishDictionaryPath = ResolveRuntimeDictionaryPath(EnglishDictionaryFileName, daemonPath);
        if (!string.IsNullOrWhiteSpace(englishDictionaryPath)) {
            processStartInfo.Environment["PHTV_EN_DICT_PATH"] = englishDictionaryPath;
        }

        var vietnameseDictionaryPath = ResolveRuntimeDictionaryPath(VietnameseDictionaryFileName, daemonPath);
        if (!string.IsNullOrWhiteSpace(vietnameseDictionaryPath)) {
            processStartInfo.Environment["PHTV_VI_DICT_PATH"] = vietnameseDictionaryPath;
        }
    }

    private void EnsureBundledNativeArtifacts() {
        if (!OperatingSystem.IsWindows()) {
            return;
        }

        var assembly = typeof(RuntimeBridgeService).Assembly;
        var runtimeMoniker = GetCurrentWindowsRuntimeMoniker();
        var resourcePrefix = $"{BundledNativeRootResourceName}.{runtimeMoniker}.";
        var targetDirectory = Path.Combine(RuntimeDirectory, "bin", runtimeMoniker);
        Directory.CreateDirectory(targetDirectory);

        foreach (var resourceName in assembly.GetManifestResourceNames()) {
            if (!resourceName.StartsWith(resourcePrefix, StringComparison.OrdinalIgnoreCase)) {
                continue;
            }

            var fileName = resourceName.Substring(resourcePrefix.Length);
            if (string.IsNullOrWhiteSpace(fileName)) {
                continue;
            }

            var destinationPath = Path.Combine(targetDirectory, fileName);
            if (!TryExtractBundledResource(assembly, resourceName, destinationPath)) {
                continue;
            }

            if (string.Equals(fileName, DaemonExecutableName, StringComparison.OrdinalIgnoreCase)) {
                _cachedDaemonPath = destinationPath;
            } else if (string.Equals(fileName, TsfDllName, StringComparison.OrdinalIgnoreCase)) {
                _cachedTsfDllPath = destinationPath;
            } else if (string.Equals(fileName, TsfRegisterToolName, StringComparison.OrdinalIgnoreCase)) {
                _cachedTsfRegisterToolPath = destinationPath;
            }
        }
    }

    private static bool TryExtractBundledResource(System.Reflection.Assembly assembly,
                                                  string resourceName,
                                                  string destinationPath) {
        try {
            using var stream = assembly.GetManifestResourceStream(resourceName);
            if (stream is null) {
                return false;
            }

            var destinationInfo = new FileInfo(destinationPath);
            if (destinationInfo.Exists && stream.CanSeek && destinationInfo.Length == stream.Length) {
                return true;
            }

            Directory.CreateDirectory(destinationInfo.DirectoryName ?? ".");
            using var output = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None);
            stream.CopyTo(output);
            return true;
        } catch {
            return false;
        }
    }

    private static string GetCurrentWindowsRuntimeMoniker() {
        return RuntimeInformation.ProcessArchitecture switch {
            Architecture.Arm64 => "win-arm64",
            Architecture.X64 => "win-x64",
            _ => "win-x64"
        };
    }

    private static IEnumerable<string> BuildPathCandidates(string baseDirectory, string fileName) {
        if (string.IsNullOrWhiteSpace(baseDirectory)) {
            yield break;
        }

        var current = Path.GetFullPath(baseDirectory);
        for (var depth = 0; depth < 7; depth++) {
            yield return Path.Combine(current, "build", "windows", "Windows", fileName);
            yield return Path.Combine(current, "build", "windows-Ninja", "Windows", fileName);
            yield return Path.Combine(current, "build", "windows-Unix-Makefiles", "Windows", fileName);
            yield return Path.Combine(current, "build", "mingw-win-Ninja", "Windows", fileName);
            yield return Path.Combine(current, "build", "mingw-win-Unix-Makefiles", "Windows", fileName);

            var parent = Directory.GetParent(current);
            if (parent is null) {
                break;
            }

            current = parent.FullName;
        }
    }

    private static string ResolveRuntimeDirectory() {
        var overrideDir = Environment.GetEnvironmentVariable("PHTV_RUNTIME_DIR");
        if (!string.IsNullOrWhiteSpace(overrideDir)) {
            return overrideDir;
        }

        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (!string.IsNullOrWhiteSpace(localAppData)) {
            return Path.Combine(localAppData, "PHTV");
        }

        return Path.Combine(Environment.CurrentDirectory, "PHTV");
    }

    private static string BuildRuntimeConfigContent(SettingsState state) {
        var lines = new List<string> {
            "# PHTV runtime config for native hook daemon",
            "version=1",
            $"language={ToInt(state.IsVietnameseEnabled)}",
            $"input_type={MapInputType(state.InputMethod)}",
            $"code_table={MapCodeTable(state.CodeTable)}",
            $"switch_key_status={ParseSwitchKeyStatus(state.SwitchHotkey)}",
            $"check_spelling={ToInt(state.CheckSpelling)}",
            $"use_modern_orthography={ToInt(state.UseModernOrthography)}",
            $"quick_telex={ToInt(state.QuickTelex)}",
            $"use_macro={ToInt(state.UseMacro)}",
            $"use_macro_in_english_mode={ToInt(state.UseMacroInEnglishMode)}",
            $"auto_caps_macro={ToInt(state.AutoCapsMacro)}",
            $"use_smart_switch_key={ToInt(state.UseSmartSwitchKey)}",
            $"upper_case_first_char={ToInt(state.UpperCaseFirstChar)}",
            $"allow_consonant_zfwj={ToInt(state.AllowConsonantZFWJ)}",
            $"quick_start_consonant={ToInt(state.QuickStartConsonant)}",
            $"quick_end_consonant={ToInt(state.QuickEndConsonant)}",
            $"remember_code={ToInt(state.RememberCode)}",
            $"restore_on_escape={ToInt(state.RestoreOnEscape)}",
            $"custom_escape_key={MapRestoreKey(state.RestoreKey)}",
            $"pause_key_enabled={ToInt(state.PauseKeyEnabled)}",
            $"pause_key={MapPauseKey(state.PauseKey)}",
            $"auto_restore_english_word={ToInt(state.AutoRestoreEnglishWord)}",
            $"send_key_step_by_step={ToInt(state.SendKeyStepByStep)}",
            $"perform_layout_compat={ToInt(state.PerformLayoutCompat)}",
            "fix_recommend_browser=1",
            $"excluded_apps={BuildEscapedList(state.ExcludedApps)}",
            $"step_by_step_apps={BuildEscapedList(state.StepByStepApps)}"
        };

        return string.Join(Environment.NewLine, lines) + Environment.NewLine;
    }

    private static string BuildRuntimeMacrosContent(SettingsState state) {
        var lines = new List<string> {
            "# shortcut\\tcontent"
        };

        foreach (var macro in state.Macros) {
            if (macro is null) {
                continue;
            }

            if (string.IsNullOrWhiteSpace(macro.Shortcut) || string.IsNullOrWhiteSpace(macro.Content)) {
                continue;
            }

            lines.Add($"{EscapeField(macro.Shortcut.Trim())}\t{EscapeField(macro.Content)}");
        }

        return string.Join(Environment.NewLine, lines) + Environment.NewLine;
    }

    private static string BuildEscapedList(IEnumerable<string> values) {
        if (values is null) {
            return string.Empty;
        }

        var normalizedValues = values
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => EscapeListField(value.Trim()))
            .Where(value => value.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return normalizedValues.Length == 0
            ? string.Empty
            : string.Join('|', normalizedValues);
    }

    private static string EscapeListField(string input) {
        return input
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("|", "\\|", StringComparison.Ordinal);
    }

    private static int ParseSwitchKeyStatus(string hotkeyText) {
        if (string.IsNullOrWhiteSpace(hotkeyText)) {
            return SwitchKeyDefault;
        }

        var status = 0;
        var hasPrimaryKey = false;
        var tokens = hotkeyText.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        foreach (var token in tokens) {
            if (IsControlToken(token)) {
                status |= ModifierControlBit;
                continue;
            }

            if (IsOptionToken(token)) {
                status |= ModifierOptionBit;
                continue;
            }

            if (IsCommandToken(token)) {
                status |= ModifierCommandBit;
                continue;
            }

            if (IsShiftToken(token)) {
                status |= ModifierShiftBit;
                continue;
            }

            if (IsFnToken(token)) {
                status |= ModifierFnBit;
                continue;
            }

            if (TryMapPrimaryKey(token, out var keyCode)) {
                status = (status & ~0xFF) | (keyCode & 0xFF);
                hasPrimaryKey = true;
            }
        }

        if (!hasPrimaryKey) {
            status = (status & ~0xFF) | SwitchKeyNoPrimary;
        }

        if ((status & (ModifierControlBit | ModifierOptionBit | ModifierCommandBit | ModifierShiftBit | ModifierFnBit)) == 0) {
            status |= ModifierControlBit | ModifierShiftBit;
        }

        return status;
    }

    private static int MapInputType(string value) {
        var normalized = value.Trim().ToLowerInvariant();
        if (normalized == "vni") {
            return 1;
        }
        if (normalized.Contains("simple telex 1", StringComparison.Ordinal)) {
            return 2;
        }
        if (normalized.Contains("simple telex 2", StringComparison.Ordinal)) {
            return 3;
        }
        return 0;
    }

    private static int MapCodeTable(string value) {
        var normalized = value.Trim().ToLowerInvariant();
        if (normalized.Contains("unicode compound", StringComparison.Ordinal)) {
            return 3;
        }
        if (normalized.Contains("vni", StringComparison.Ordinal)) {
            return 2;
        }
        if (normalized.Contains("tcvn3", StringComparison.Ordinal) || normalized.Contains("abc", StringComparison.Ordinal)) {
            return 1;
        }
        if (normalized.Contains("1258", StringComparison.Ordinal)) {
            return 4;
        }
        return 0;
    }

    private static int MapRestoreKey(string value) {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized switch {
            "esc" => KeyEsc,
            "escape" => KeyEsc,
            "option" => KeyLeftOption,
            "alt" => KeyLeftOption,
            "control" => KeyLeftControl,
            "ctrl" => KeyLeftControl,
            _ => KeyEsc
        };
    }

    private static int MapPauseKey(string value) {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized switch {
            "alt" => KeyLeftOption,
            "option" => KeyLeftOption,
            "control" => KeyLeftControl,
            "ctrl" => KeyLeftControl,
            "shift" => KeyLeftShift,
            "command" => KeyLeftCommand,
            "cmd" => KeyLeftCommand,
            "win" => KeyLeftCommand,
            "windows" => KeyLeftCommand,
            "fn" => KeyFunction,
            _ => KeyLeftOption
        };
    }

    private static bool TryMapPrimaryKey(string token, out int keyCode) {
        var normalized = token.Trim();
        return PrimaryHotkeyMap.TryGetValue(normalized, out keyCode);
    }

    private static bool IsControlToken(string token) {
        return token.Equals("ctrl", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("control", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsOptionToken(string token) {
        return token.Equals("alt", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("option", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsCommandToken(string token) {
        return token.Equals("cmd", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("command", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("win", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("windows", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsShiftToken(string token) {
        return token.Equals("shift", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsFnToken(string token) {
        return token.Equals("fn", StringComparison.OrdinalIgnoreCase) ||
               token.Equals("function", StringComparison.OrdinalIgnoreCase);
    }

    private static int ToInt(bool value) {
        return value ? 1 : 0;
    }

    private static string EscapeField(string value) {
        return value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\t", "\\t", StringComparison.Ordinal)
            .Replace("\r", "\\r", StringComparison.Ordinal)
            .Replace("\n", "\\n", StringComparison.Ordinal);
    }
}
