<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

param(
    [ValidateRange(5, 120)]
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'

if (-not ('KeyboardProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class KeyboardProbe
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const uint PM_REMOVE = 0x0001;

    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    private static readonly HookProc Callback = OnKeyboardEvent;
    private static readonly List<string> Events = new List<string>();
    private static IntPtr hook = IntPtr.Zero;

    [StructLayout(LayoutKind.Sequential)]
    private struct KbdLlHookStruct
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public UIntPtr extraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Message
    {
        public IntPtr window;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public Point point;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(
        int idHook, HookProc callback, IntPtr module, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(
        IntPtr hook, int code, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool PeekMessage(
        out Message message, IntPtr window, uint min, uint max, uint remove);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref Message message);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref Message message);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetKeyNameText(
        int lParam, System.Text.StringBuilder name, int size);

    private static IntPtr OnKeyboardEvent(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0 &&
            (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN))
        {
            KbdLlHookStruct data =
                Marshal.PtrToStructure<KbdLlHookStruct>(lParam);

            int keyNameParameter = (int)(data.scanCode << 16);
            if ((data.flags & 0x01) != 0)
            {
                keyNameParameter |= 1 << 24;
            }

            System.Text.StringBuilder keyName =
                new System.Text.StringBuilder(128);
            if (GetKeyNameText(keyNameParameter, keyName, keyName.Capacity) == 0)
            {
                keyName.Append("Unidentified special key");
            }

            Events.Add(String.Format(
                "Key=\"{0}\"  VK=0x{1:X2} ({1})  Scan=0x{2:X3} ({2})  Flags=0x{3:X}",
                keyName, data.vkCode, data.scanCode, data.flags));
        }

        return CallNextHookEx(hook, code, wParam, lParam);
    }

    public static string[] Run(int timeoutMilliseconds)
    {
        Events.Clear();
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, Callback, IntPtr.Zero, 0);

        if (hook == IntPtr.Zero)
        {
            throw new System.ComponentModel.Win32Exception(
                Marshal.GetLastWin32Error());
        }

        try
        {
            Stopwatch timer = Stopwatch.StartNew();
            while (timer.ElapsedMilliseconds < timeoutMilliseconds)
            {
                Message message;
                while (PeekMessage(out message, IntPtr.Zero, 0, 0, PM_REMOVE))
                {
                    TranslateMessage(ref message);
                    DispatchMessage(ref message);
                }
                Thread.Sleep(10);
            }
        }
        finally
        {
            UnhookWindowsHookEx(hook);
            hook = IntPtr.Zero;
        }

        return Events.ToArray();
    }
}
'@
}

Write-Host "Press the key or button to identify. Capturing keyboard events for $TimeoutSeconds seconds..."
$events = @([KeyboardProbe]::Run($TimeoutSeconds * 1000))
$events | ForEach-Object { Write-Host $_ }

if ($events.Count -gt 0) {
    Write-Host "$($events.Count) key-down event(s) detected." -ForegroundColor Green
}
else {
    Write-Host 'No keyboard event was detected.' -ForegroundColor Yellow
}
