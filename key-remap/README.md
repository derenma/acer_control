# Experimental Key Remapping Tools

> [!WARNING]
> These tools are experimental and may not work correctly out of the box. Acer
> key behavior varies by laptop model, firmware, drivers, and installed Acer
> software. Identify the key event on your system before enabling the remapper.

This directory contains Windows-only tools for detecting and remapping the
dedicated Acer NitroSense key. They use a global low-level keyboard hook in the
current interactive desktop session and do not require administrator access.

## Requirements

- A supported Acer laptop running Windows.
- An interactive desktop session.
- Permission to run local PowerShell scripts and compile the embedded C# helper
  with `Add-Type`.
- Windows PowerShell 5.1 or PowerShell 7.x, subject to the command-specific
  compatibility notes below.

## Detect the Key

[`detect-nitrosense-key.ps1`](detect-nitrosense-key.ps1) captures key-down
events for a limited interval and prints each key name, virtual-key code, scan
code, and flags. It does not remap or suppress any key.

From this directory, run:

```powershell
.\detect-nitrosense-key.ps1 -TimeoutSeconds 20
```

Press the NitroSense key during the capture window. The supplied remapper
expects an extended scan code of `0x75`. If detection reports a different scan
code or no event, the remapper will need model-specific changes and should not
be installed as-is.

The detector supports Windows PowerShell 5.1 and PowerShell 7.x on Windows.

## Remap the NitroSense Key

[`nitrosense-key-task-manager.ps1`](nitrosense-key-task-manager.ps1) intercepts
the extended `0x75` scan code, suppresses that key event, and launches Windows
Task Manager. Run it in the foreground first so it can be stopped with
`Ctrl+C`:

```powershell
.\nitrosense-key-task-manager.ps1
```

Available commands:

```powershell
.\nitrosense-key-task-manager.ps1 --install
.\nitrosense-key-task-manager.ps1 --status
pwsh .\nitrosense-key-task-manager.ps1 --uninstall
.\nitrosense-key-task-manager.ps1 --help
```

`--install` creates a hidden current-user Startup shortcut and starts the
remapper. The shortcut runs the inbox Windows PowerShell 5.1 host; it does not
install a Windows service or require elevation. Use PowerShell 7 for
`--uninstall`, because that command uses a .NET string-comparison overload that
is unavailable in Windows PowerShell 5.1.

## Experimental Limitations

- The expected scan code is based on one Acer Nitro configuration and may differ
  on other models or firmware revisions.
- Acer utilities, keyboard drivers, security software, or session boundaries
  may prevent detection or interfere with the hook.
- The remapper handles only the configured NitroSense scan code and always maps
  it to `taskmgr.exe`; it is not a general-purpose remapping utility.
- Startup behavior can differ after Windows, PowerShell, driver, or Acer
  software updates. Test the foreground mode again after relevant updates.

To remove an installed remapper, run the PowerShell 7 `--uninstall` command
shown above. This removes the current-user Startup shortcut and stops the hidden
remapper process.
