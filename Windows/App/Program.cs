using Avalonia;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace PHTV.Windows;

internal sealed class Program {
    [STAThread]
    public static void Main(string[] args) {
        StartupDiagnostics.WriteInfo("Process started.");
        StartupDiagnostics.WriteInfo($"Args: {string.Join(' ', args)}");
        StartupDiagnostics.InstallExceptionHooks();

        Mutex? singleInstanceMutex = null;
        var hasSingleInstanceLock = false;

        try {
            hasSingleInstanceLock = SingleInstanceCoordinator.TryAcquire(out singleInstanceMutex);
            if (!hasSingleInstanceLock) {
                StartupDiagnostics.WriteInfo("Detected another running instance. Signaling existing instance and exiting.");
                SingleInstanceCoordinator.SignalActivateExistingInstance();
                return;
            }

            StartupDiagnostics.WriteInfo("Starting Avalonia desktop lifetime.");
            BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
            StartupDiagnostics.WriteInfo("Avalonia desktop lifetime ended.");
        } catch (Exception ex) {
            StartupDiagnostics.WriteException("Fatal startup exception", ex);
            StartupDiagnostics.ShowFatalErrorMessage(ex);
        } finally {
            if (hasSingleInstanceLock) {
                SingleInstanceCoordinator.Release(singleInstanceMutex);
            }
        }
    }

    public static AppBuilder BuildAvaloniaApp() {
        return AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont();
    }
}

internal static class SingleInstanceCoordinator {
    private const string MutexName = @"Local\PHTV.Windows.Singleton";
    internal const string ActivateEventName = @"Local\PHTV.Windows.Activate";

    public static bool TryAcquire(out Mutex? mutex) {
        mutex = null;
        try {
            mutex = new Mutex(initiallyOwned: true, name: MutexName, createdNew: out var createdNew);
            return createdNew;
        } catch (Exception ex) {
            StartupDiagnostics.WriteException("Unable to create single-instance mutex.", ex);
            // Fail-open so startup is not permanently blocked by synchronization edge cases.
            return true;
        }
    }

    public static void SignalActivateExistingInstance() {
        try {
            using var activateEvent = new EventWaitHandle(
                initialState: false,
                mode: EventResetMode.AutoReset,
                name: ActivateEventName);
            activateEvent.Set();
        } catch (Exception ex) {
            StartupDiagnostics.WriteException("Unable to signal existing instance.", ex);
        }
    }

    public static void Release(Mutex? mutex) {
        if (mutex is null) {
            return;
        }

        try {
            mutex.ReleaseMutex();
        } catch (ApplicationException) {
            // Ignore: current thread does not own the mutex.
        } finally {
            mutex.Dispose();
        }
    }
}

internal static class StartupDiagnostics {
    private const uint MessageBoxIconError = 0x10;
    private static readonly object SyncObject = new();
    private static readonly string LogFilePath = BuildLogFilePath();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);

    public static void InstallExceptionHooks() {
        AppDomain.CurrentDomain.UnhandledException += (_, eventArgs) => {
            var exception = eventArgs.ExceptionObject as Exception;
            WriteException("Unhandled exception", exception ?? new Exception("Unknown exception object"));
        };

        TaskScheduler.UnobservedTaskException += (_, eventArgs) => {
            WriteException("Unobserved task exception", eventArgs.Exception);
            eventArgs.SetObserved();
        };
    }

    public static void WriteInfo(string message) {
        WriteLine($"[INFO] {message}");
    }

    public static void WriteException(string message, Exception exception) {
        var builder = new StringBuilder();
        builder.AppendLine($"[ERROR] {message}");
        builder.AppendLine(exception.ToString());
        WriteLine(builder.ToString().TrimEnd());
    }

    public static void ShowFatalErrorMessage(Exception exception) {
        var text =
            "PHTV gặp lỗi khi khởi động.\n\n" +
            $"Lỗi: {exception.Message}\n\n" +
            $"Xem log tại:\n{LogFilePath}";
        MessageBoxW(IntPtr.Zero, text, "PHTV Startup Error", MessageBoxIconError);
    }

    private static void WriteLine(string message) {
        try {
            lock (SyncObject) {
                var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {message}{Environment.NewLine}";
                File.AppendAllText(LogFilePath, line, Encoding.UTF8);
            }
        } catch {
            // Avoid throwing from diagnostics paths.
        }
    }

    private static string BuildLogFilePath() {
        try {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var root = string.IsNullOrWhiteSpace(localAppData)
                ? Path.Combine(Environment.CurrentDirectory, "PHTV")
                : Path.Combine(localAppData, "PHTV");
            var logDirectory = Path.Combine(root, "logs");
            Directory.CreateDirectory(logDirectory);
            return Path.Combine(logDirectory, "startup.log");
        } catch {
            return Path.Combine(Environment.CurrentDirectory, "phtv-startup.log");
        }
    }
}
