# Requirements

This document covers the installable service under `installable_service/` and the PowerShell scripts in the repository root.

## Common Platform Requirements

- A modern 64-bit Windows installation supported by .NET 10. The service publishes for `win-x64` and uses Windows-only WMI, registry, service-control, and power-event APIs.
- A supported Acer laptop. Hardware-control features depend on Acer firmware, drivers, and model capabilities; they are not portable to non-Acer systems.
- Windows PowerShell 5.1 for the root scripts. `acer-control.ps1` explicitly relaunches itself through the inbox `powershell.exe` when started from PowerShell 7.
- An execution policy that permits local scripts. If scripts are blocked, use a suitable persistent policy such as `RemoteSigned`, or launch a trusted script explicitly with `powershell.exe -ExecutionPolicy Bypass -File <script>`.
- Local TCP ports used below must not be occupied by unrelated applications.

## Installable Service

Location: `installable_service/`

### Build Requirements

| Requirement | Version/details | Purpose |
|---|---|---|
| .NET SDK | 10.x, x64 | Restore, compile, test, and publish `AcerControl.sln` |
| PowerShell | Windows PowerShell 5.1 or PowerShell 7 | Run publish/install/uninstall scripts |
| NuGet access | Internet access on first restore, unless packages are already cached | Restore service and test packages |
| Architecture | `win-x64` | Matches the configured runtime identifier and published service |

Build and test from the service directory:

```powershell
Set-Location .\installable_service
dotnet restore .\AcerControl.sln
dotnet test .\AcerControl.sln
.\scripts\Publish-AcerControlService.ps1
```

The publish script produces `artifacts\publish\AcerControlService\AcerControlService.exe`.

### Build Dependencies

Service dependencies:

| Dependency | Version | Purpose |
|---|---:|---|
| `Microsoft.AspNetCore.App` | .NET 10 shared framework reference | Kestrel HTTP API and hosting APIs |
| `Microsoft.Extensions.Hosting.WindowsServices` | 10.0.4 | Windows Service Control Manager integration |
| `System.Management` | 10.0.4 | Acer WMI firmware access and power-resume events |

Test-only dependencies:

| Dependency | Version |
|---|---:|
| `Microsoft.NET.Test.Sdk` | 17.14.1 |
| `Microsoft.AspNetCore.Mvc.Testing` | 10.0.4 |
| `xunit` | 2.9.3 |
| `xunit.runner.visualstudio` | 3.1.4 |
| `coverlet.collector` | 6.0.4 |

### Installation Requirements

- Run `installable_service\scripts\Install-AcerControlService.ps1` from an elevated PowerShell session. The script has `#Requires -RunAsAdministrator`.
- The standard Windows utilities `sc.exe` and `icacls.exe` must be available. They are included with supported Windows installations.
- The installer requires write access to:
  - `%ProgramFiles%\AcerControl`
  - `%ProgramData%\AcerControl`
  - `HKLM\SOFTWARE\AcerControl\Service`
  - Windows Service Control Manager configuration
- The service account is `LocalSystem`; do not change it to a normal user account unless equivalent WMI, registry, token-file, and service permissions are configured.
- TCP port `46934` must be free on `127.0.0.1`. The port can be changed through the `ApiPort` DWORD under `HKLM\SOFTWARE\AcerControl\Service` before service startup.

### Service Runtime Requirements

- `root\wmi:AcerGamingFunction` must exist and expose the methods used for fan, keyboard, profile, and sensor control.
- The Acer ACPI/WMI firmware driver that provides `AcerGamingFunction` must remain installed and enabled.
- The service must be able to read and write `HKLM\SOFTWARE\AcerControl\Service`.
- The API token must exist at `%ProgramData%\AcerControl\api-token`. The installer generates it and grants local Users read access.
- Loopback HTTP on `127.0.0.1:46934` must be available. No external listener or firewall exception is required.
- Profile availability is firmware-dependent. Eco may require battery power; Turbo may require AC power.

The published executable is self-contained and bundles its native libraries. A separate .NET runtime is **not** required on the target computer. The .NET 10 SDK is needed only to build or test from source.

The service does **not** require AcerAgentService, Acer Lighting Service, or a separately installed OpenRGB server because it accesses `AcerGamingFunction` directly.

### Service Clients

#### PowerShell client

`installable_service\acer-service-control.ps1` requires:

- The `AcerControlService` service installed and running.
- Loopback access to the configured API port, default `127.0.0.1:46934`.
- Read access to `%ProgramData%\AcerControl\api-token`.
- Windows PowerShell 5.1 or PowerShell 7 with `Invoke-RestMethod`.
- No administrator elevation under the default installer ACLs.

Optional environment overrides:

- `ACER_CONTROL_BASE_URL`
- `ACER_CONTROL_TOKEN_FILE`

#### Python client

`installable_service\clients\python` requires:

- Python 3.10 or newer to run.
- `pip` and `setuptools` 68 or newer to install/build the package.
- No third-party runtime packages; HTTP and JSON handling use the Python standard library.
- The installed/running service, loopback API access, and API-token read access described above.

Install locally with:

```powershell
py -m pip install .\installable_service\clients\python
```

## Root PowerShell Scripts

These scripts are independent tools. Their requirements differ from the installable service.

| Script | Privilege | Required Acer component/interface | Local port | Other requirements |
|---|---|---|---:|---|
| `acer-control.ps1` | Administrator; self-elevates through UAC | `root\wmi:AcerGamingFunction` and its Acer firmware driver | None | Inbox Windows PowerShell 5.1 must be present; supports fan, static keyboard, profile, and status operations directly |
| `acer-fan-control.ps1` | Normal user under the standard Acer service configuration | Running AcerAgentService (`AASSvc`) and its system driver/service | 46933 | AcerAgentService must expose the local `FAN_CONTROL` JSON protocol |
| `acer-keyboard-led.ps1` | Normal user | Running Acer Lighting Service (`AcerLightingService`) and its bundled OpenRGB server | 6742 | OpenRGB protocol version 3 or newer and an `AcerECKeyboard Device`/compatible Acer keyboard controller |
| `acer-performance-profile.ps1` | Normal user under the standard Acer service configuration | Running AcerAgentService (`AASSvc`) | 46933 | AcerAgentService must expose operating-mode capability and control requests |
| `detect-nitrosense-key.ps1` | Normal interactive user | None | None | Interactive desktop, `user32.dll`, and `Add-Type`; captures global low-level keyboard events for the requested interval |
| `nitrosense-key-task-manager.ps1` | Normal interactive user | None | None | `user32.dll`, `taskmgr.exe`, `WScript.Shell` COM, CIM/WMI process queries, current-user Startup-folder access, and inbox `powershell.exe` |

### Root Script Notes

#### `acer-control.ps1`

- Uses `Get-WmiObject` against `root\wmi:AcerGamingFunction`; this cmdlet is supplied by Windows PowerShell 5.1.
- Requests administrator access when needed and displays a UAC prompt.
- Uses `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` for elevated/direct WMI execution.
- Does not require the new `AcerControlService` and does not update its persisted desired state.
- Does not require Acer Lighting Service or OpenRGB.

#### `acer-fan-control.ps1` and `acer-performance-profile.ps1`

- Connect only to `127.0.0.1:46933`; remote network access is not required.
- Require AcerAgentService to be running and accepting its `ACER`-framed JSON protocol.
- Will fail if `AASSvc`/AcerAgentService is disabled, stopped, incompatible, or port 46933 is unavailable.
- Profile and fan support remains dependent on the laptop model, BIOS, power source, and Acer firmware.

#### `acer-keyboard-led.ps1`

- Connects only to the OpenRGB server at `127.0.0.1:6742`.
- Requires Acer Lighting Service to start its bundled OpenRGB server.
- Requires OpenRGB protocol version 3 or newer for brightness control.
- Requires the server to enumerate the Acer keyboard as `AcerECKeyboard Device` or a compatible Acer keyboard controller.
- Supports uniform static color and brightness; available effects and zones depend on the hardware/controller.

#### NitroSense key utilities

- Must run in the signed-in user's interactive desktop session; a Windows service session cannot receive the same low-level keyboard events.
- `detect-nitrosense-key.ps1` dynamically compiles a small C# keyboard-hook helper through `Add-Type`.
- `nitrosense-key-task-manager.ps1 --install` creates a current-user Startup shortcut and launches a hidden Windows PowerShell process. It does not install a Windows service or require administrator access.
- Endpoint-security software may restrict global keyboard hooks, dynamic `Add-Type` compilation, hidden PowerShell startup, or Task Manager launch.

## Operational Constraints

- Do not run competing fan/profile/keyboard controllers concurrently unless their interaction is understood. NitroSense, the new service, and standalone scripts can overwrite one another's settings.
- Changing a performance profile can reset fan mode or custom fan targets. The new service restores in profile, fan, keyboard order.
- Firmware writes are model-specific and may be rejected even when the interface exists.
- Suspend/resume, reboot, Acer software, BIOS updates, or driver updates can reset hardware state.
- Keep Acer firmware/ACPI drivers and the BIOS current using packages intended for the exact laptop model.