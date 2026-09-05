<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supports remapping, --install, and --status;
    --uninstall is not compatible.
- PowerShell 7.x: Supports all commands; --install creates a Windows
    PowerShell 5.1 startup shortcut.
#>

$ErrorActionPreference = 'Stop'

function Show-Help {
    @'
Remap the dedicated Acer NitroSense key to launch Task Manager.

Usage:
  .\nitrosense-key-task-manager.ps1
  .\nitrosense-key-task-manager.ps1 --install
  .\nitrosense-key-task-manager.ps1 --uninstall
  .\nitrosense-key-task-manager.ps1 --status
  .\nitrosense-key-task-manager.ps1 --help

Running without arguments keeps the remap active until the script exits.
--install adds a hidden current-user startup shortcut and starts the remap now.
--uninstall removes the startup shortcut and stops a running remapper.
'@
}

$startupShortcut = Join-Path (
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
) 'Acer NitroSense Key - Task Manager.lnk'
$mutexName = 'Local\AcerNitroSenseKeyTaskManager'

function Stop-InstalledRemapper {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine.Contains($PSCommandPath, [StringComparison]::OrdinalIgnoreCase) -and
            -not $_.CommandLine.Contains('--install') -and
            -not $_.CommandLine.Contains('--uninstall') -and
            -not $_.CommandLine.Contains('--status')
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -ErrorAction Stop
        }
}

$arguments = @($args)
if ($arguments.Count -gt 1) {
    Show-Help
    exit 2
}

$action = if ($arguments.Count -eq 0) {
    'Run'
}
else {
    switch ($arguments[0].ToLowerInvariant()) {
        '--install' { 'Install' }
        '--uninstall' { 'Uninstall' }
        '--status' { 'Status' }
        '--help' { 'Help' }
        '-help' { 'Help' }
        '-h' { 'Help' }
        '/?' { 'Help' }
        default { 'Invalid' }
    }
}

if ($action -in @('Help', 'Invalid')) {
    Show-Help
    exit $(if ($action -eq 'Invalid') { 2 } else { 0 })
}

if ($action -eq 'Status') {
    $mutex = [Threading.Mutex]::new($false, $mutexName, [ref]$null)
    try {
        if ($mutex.WaitOne(0)) {
            $mutex.ReleaseMutex()
            Write-Host 'NitroSense key remapper is not running.'
        }
        else {
            Write-Host 'NitroSense key remapper is running.'
        }
    }
    finally {
        $mutex.Dispose()
    }

    Write-Host "Startup installation: $(if (Test-Path -LiteralPath $startupShortcut) { 'installed' } else { 'not installed' })"
    exit
}

if ($action -eq 'Uninstall') {
    if (Test-Path -LiteralPath $startupShortcut) {
        Remove-Item -LiteralPath $startupShortcut -Force
    }
    Stop-InstalledRemapper
    Write-Host 'NitroSense key remap removed.'
    exit
}

if ($action -eq 'Install') {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupShortcut)
    $shortcut.TargetPath = $windowsPowerShell
    $shortcut.Arguments = "-NoProfile -WindowStyle Hidden -File `"$PSCommandPath`""
    $shortcut.WorkingDirectory = Split-Path -Parent $PSCommandPath
    $shortcut.Description = 'Remap the Acer NitroSense key to Task Manager'
    $shortcut.WindowStyle = 7
    $shortcut.Save()

    Start-Process -FilePath $windowsPowerShell -WindowStyle Hidden -ArgumentList @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-File', "`"$PSCommandPath`""
    )
    Write-Host 'NitroSense key remap installed and started.'
    exit
}

$createdNew = $false
$instanceMutex = [Threading.Mutex]::new($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    $instanceMutex.Dispose()
    throw 'The NitroSense key remapper is already running.'
}

try {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class NitroSenseKeyRemapper
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;
    private const uint PM_REMOVE = 0x0001;
    private const uint NitroSenseScanCode = 0x75;
    private const uint LlkhfExtended = 0x01;

    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    private static readonly HookProc Callback = OnKeyboardEvent;
    private static IntPtr hook = IntPtr.Zero;
    private static bool keyHeld;

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

    private static IntPtr OnKeyboardEvent(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code < 0)
        {
            return CallNextHookEx(hook, code, wParam, lParam);
        }

        KbdLlHookStruct data =
            Marshal.PtrToStructure<KbdLlHookStruct>(lParam);
        bool isNitroSenseKey =
            data.scanCode == NitroSenseScanCode &&
            (data.flags & LlkhfExtended) != 0;

        if (!isNitroSenseKey)
        {
            return CallNextHookEx(hook, code, wParam, lParam);
        }

        bool isKeyDown =
            wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN;
        bool isKeyUp =
            wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP;

        if (isKeyDown && !keyHeld)
        {
            keyHeld = true;
            Process.Start(new ProcessStartInfo
            {
                FileName = "taskmgr.exe",
                UseShellExecute = true
            });
        }
        else if (isKeyUp)
        {
            keyHeld = false;
        }

        return (IntPtr)1;
    }

    public static void Run()
    {
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, Callback, IntPtr.Zero, 0);
        if (hook == IntPtr.Zero)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        try
        {
            while (true)
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
    }
}
'@

    Write-Host 'NitroSense key now launches Task Manager. Press Ctrl+C to stop.'
    [NitroSenseKeyRemapper]::Run()
}
finally {
    $instanceMutex.ReleaseMutex()
    $instanceMutex.Dispose()
}
