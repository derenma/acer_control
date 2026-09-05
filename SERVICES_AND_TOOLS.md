# Services and Tools Quick Reference

This table covers every PowerShell script in the project.

| Script | Purpose | WMI only | OpenRGB | Required Acer Service | Other |
|---|---|---|---|---|---|
| `acer-control.ps1` | Direct fan, keyboard, profile, and status control | **Yes**: `root\wmi:AcerGamingFunction` | No | None | Administrator access; self-elevates through UAC; requires Windows PowerShell 5.1 for `Get-WmiObject` |
| `acer-enumerate-services.ps1` | Identify running services likely distributed by Acer using names, paths, binary metadata, and signatures | No | No | None | Read-only CIM and file metadata queries; can optionally include stopped or lower-confidence candidates and emit JSON |
| `acer-fan-control.ps1` | Set custom CPU/GPU fan percentages through Acer's local API | No | No | **AcerAgentService** (`AASSvc`) | Connects to `127.0.0.1:46933`; normal user is normally sufficient |
| `acer-keyboard-led.ps1` | Read or set static keyboard color and brightness | No | **Yes**: protocol v3+ | **AcerLightingService** | Connects to bundled OpenRGB at `127.0.0.1:6742`; requires a compatible Acer keyboard controller |
| `acer-performance-profile.ps1` | Read, select, or cycle performance profiles | No | No | **AcerAgentService** (`AASSvc`) | Connects to `127.0.0.1:46933`; Eco/Turbo availability depends on power source and firmware |
| `detect-nitrosense-key.ps1` | Identify keyboard scan codes, including the NitroSense key | No | No | None | Interactive desktop; `user32.dll`; dynamically compiles a keyboard hook with `Add-Type` |
| `nitrosense-key-task-manager.ps1` | Remap the NitroSense key to Task Manager | No | No | None | Interactive desktop; `user32.dll`, `taskmgr.exe`, `WScript.Shell`, CIM, current-user Startup-folder access, and Windows PowerShell 5.1 |
| `installable_service\acer-service-control.ps1` | Control the installed Acer Control Service API | No | No | **AcerControlService** | HTTP on `127.0.0.1:46934`; read access to `%ProgramData%\AcerControl\api-token`; no elevation under default ACLs |
| `installable_service\scripts\Publish-AcerControlService.ps1` | Test and publish the service executable | No | No | None | .NET 10 SDK, NuGet restore access or cached packages, and PowerShell; outputs self-contained `win-x64` executable |
| `installable_service\scripts\Install-AcerControlService.ps1` | Install/configure/start AcerControlService | No | No | Installs **AcerControlService** | Elevated PowerShell; `sc.exe`, `icacls.exe`; write access to Program Files, ProgramData, HKLM, and Service Control Manager; port 46934 free |
| `installable_service\scripts\Uninstall-AcerControlService.ps1` | Stop and remove AcerControlService | No | No | Removes **AcerControlService** | Elevated PowerShell; `sc.exe`; `-Purge` also removes persisted HKLM settings |

## Acer Services Identified on This Laptop

The following Acer user-mode services were detected on this Nitro AN17-42. A service listed here is not necessarily a hardware controller; several provide inventory, telemetry, or application support only.

| Service | Hardware component or role |
|---|---|
| `AASSvc` | CPU/GPU temperatures, utilization, clocks, fan RPM and performance profiles; NVIDIA GPU modes and overclock levels; keyboard function controls; DTS audio modes; USB-C/DisplayPort monitoring |
| `AcerARTAIMMXDriverService` | Webcam processing package helper for Acer HD camera effects |
| `AcerARTAIMMXService` | Webcam detection and Media Foundation processing, including background blur and eye-contact effects |
| `AcerCCAgentSvis` | Battery health, calibration, charging limits and adaptive charging; also supports Care Center storage-health tooling |
| `AcerDeviceEnablingServiceV2` | No direct hardware control confirmed; monitors power/display transitions and brokers Acer enrollment, consent, and telemetry state |
| `AcerDeviceInfoAgentService` | No direct hardware control identified; collects device and system inventory |
| `AcerDIAgentSvis` | No direct hardware control identified; provides Acer Device Info inventory services |
| `AcerEZSvc` | No direct hardware control identified; local backend for Acer Experience Zone |
| `AcerLightingService` | Keyboard RGB zones, brightness, static colors, and lighting effects through bundled OpenRGB |
| `AcerPixyService` | Webcam multimedia and image-processing features in the Acer Pixy/ART-AIMMX package |
| `AcerQAAgentSvis` | Powered USB charging while off and battery restrictions; display BlueLight Shield settings |
| `AcerServiceSvc` | No direct hardware control identified; inventories drivers and applications and provides Acer update/warranty support |

`AcerAirplaneModeController` is a separate kernel driver rather than a user-mode service. It handles the airplane-mode key and wireless-radio state events.

## Service Startup and Restoration Behavior

The following is a read-only snapshot from September 5, 2026. All 12 stock Acer user-mode services listed above were stopped and configured as disabled. Four enabled scheduled tasks still attempted to start disabled Acer services at boot or logon:

| Scheduled task | Trigger and account | Action | Observed behavior |
|---|---|---|---|
| `AcerDeviceInfoAgentServiceDelayStart` | Boot plus 15 seconds, `SYSTEM` | `sc start AcerDeviceInfoAgentService` | Last run returned `0x422` (`ERROR_SERVICE_DISABLED`) |
| `DelayStartCareCenter2` | Any-user logon plus 1 minute | `C:\Program Files\AcerCCAgent\Launcher.exe AcerCCAgentSvis` | Last run returned `0x422` |
| `DelayStartDeviceInfo2` | Any-user logon plus 1 minute | `C:\Program Files\AcerDIAgent\Launcher.exe AcerDIAgentSvis` | Last run returned `0x422` |
| `DelayStartQuickAccess2` | Any-user logon plus 1 minute | `C:\Program Files\AcerQAAgent\Launcher.exe AcerQAAgentSvis` | Last run returned `0x422` |

These tasks do not re-enable or reinstall a disabled service; they only request that an existing service start. Their failure is therefore expected while the target service remains disabled. `NitroSenseLauncher` was present but disabled. The enabled `StorPSCTL` logon task starts Acer's SSD/storage utility and was not observed creating or starting an Acer service.

Disabling or deleting only the service registry keys is not durable removal. Signed Acer/ULIC PnP software-component packages remain installed in the Windows Driver Store and are bound to devices on this laptop. Their INF files contain `AddService` directives that can recreate the following registrations during a driver reinstall, device re-enumeration, OEM repair, or Windows Update:

- `AASSvc`, `AcerLightingService`, `AcerARTAIMMXDriverService`, `AcerARTAIMMXService`, `AcerPixyService`, `AcerDeviceEnablingServiceV2`, `AcerEZSvc`, and `AcerServiceSvc` are declared as automatic services by their installed INF packages.
- `AcerCCAgentSvis`, `AcerDIAgentSvis`, and `AcerQAAgentSvis` are also declared as automatic services and have the logon tasks shown above.
- `AcerDeviceInfoAgentService` is declared as demand-start and has the boot task shown above.

No Acer-related entries were found in the inspected `Run`, `RunOnce`, Explorer policy-run, Active Setup, Winlogon, Session Manager, shell delayed-load, or WMI permanent-event-consumer locations. The current-user Startup shortcut installed by `nitrosense-key-task-manager.ps1` starts only the key-remapping script and contains no service creation, configuration, or start command.

The repository's `AcerControlService` is separate from these stock components. Its installer deliberately registers it as a delayed automatic `LocalSystem` service so it can restore managed fan, keyboard, and performance-profile settings at startup. It does not depend on the stock Acer scheduled tasks or software-component packages.

## Dependency Legend

- **WMI only** means the tool talks directly to Acer firmware through `root\wmi:AcerGamingFunction` and does not require an Acer user-mode control service or OpenRGB.
- **AcerAgentService (`AASSvc`)** provides Acer's loopback `ACER`-framed JSON API on port 46933.
- **AcerLightingService** starts Acer's bundled OpenRGB server on port 6742.
- **AcerControlService** is the custom service built from `installable_service/`; its authenticated HTTP API listens on port 46934 by default.

The service executable itself uses `root\wmi:AcerGamingFunction` directly. It does not require AcerAgentService, AcerLightingService, or OpenRGB.

See `REQUIREMENTS.md` for detailed build, installation, privilege, firmware, and runtime requirements.