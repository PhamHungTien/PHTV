using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;

namespace PHTV.Windows.Services;

public static class EmojiInsertionService {
    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_V = 0x56;

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT {
        public uint type;
        public INPUTUNION u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetCursorPos(out POINT lpPoint);

    public static IntPtr SaveForegroundWindow() => GetForegroundWindow();

    public static (int X, int Y) GetMousePosition() {
        GetCursorPos(out var point);
        return (point.X, point.Y);
    }

    public static async Task PasteEmojiAsync(string emoji, IntPtr previousWindow, TopLevel? topLevel) {
        if (topLevel != null) {
            var clipboard = topLevel.Clipboard;
            if (clipboard != null)
                await clipboard.SetTextAsync(emoji);
        }

        SetForegroundWindow(previousWindow);
        await Task.Delay(100);
        SendCtrlV();
    }

    public static async Task PasteMediaFileAsync(string filePath, IntPtr previousWindow, TopLevel? topLevel) {
        if (topLevel != null) {
            var clipboard = topLevel.Clipboard;
            if (clipboard != null) {
                var dataObject = new DataObject();
                dataObject.Set(DataFormats.Files, new[] { filePath });
                await clipboard.SetDataObjectAsync(dataObject);
            }
        }

        SetForegroundWindow(previousWindow);
        await Task.Delay(100);
        SendCtrlV();

        // Schedule file cleanup after 10 seconds
        _ = Task.Run(async () => {
            await Task.Delay(10000);
            try { File.Delete(filePath); } catch { }
        });
    }

    private static void SendCtrlV() {
        var inputs = new INPUT[4];
        var size = Marshal.SizeOf<INPUT>();

        // Ctrl down
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wVk = VK_CONTROL;

        // V down
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].u.ki.wVk = VK_V;

        // V up
        inputs[2].type = INPUT_KEYBOARD;
        inputs[2].u.ki.wVk = VK_V;
        inputs[2].u.ki.dwFlags = KEYEVENTF_KEYUP;

        // Ctrl up
        inputs[3].type = INPUT_KEYBOARD;
        inputs[3].u.ki.wVk = VK_CONTROL;
        inputs[3].u.ki.dwFlags = KEYEVENTF_KEYUP;

        SendInput(4, inputs, size);
    }
}
