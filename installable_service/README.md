# Acer Control

Acer Control manages Nitro fan targets, static keyboard lighting, and performance profiles through the `AcerGamingFunction` WMI firmware interface.

The repository contains two control paths:

- `acer-control.ps1` directly accesses firmware and remains available as an elevated recovery tool.
- `AcerControlService` runs as `LocalSystem`, persists desired settings, restores managed settings after startup/resume, and exposes an authenticated loopback API.

## Build

Requirements: Windows x64 and the .NET 10 SDK.

```powershell
.\scripts\Publish-AcerControlService.ps1
```

The script runs all tests and publishes a self-contained executable under `artifacts\publish\AcerControlService`.

## Install

Run from an elevated PowerShell window:

```powershell
.\scripts\Install-AcerControlService.ps1
```

The installer:

- Copies protected binaries to `%ProgramFiles%\AcerControl`.
- Creates a shared local API token at `%ProgramData%\AcerControl\api-token`.
- Creates settings under `HKLM\SOFTWARE\AcerControl\Service`.
- Registers `AcerControlService` as a delayed automatic `LocalSystem` service.
- Configures service restart-on-failure actions.

The service listens only on `127.0.0.1:46934`. It creates no firewall rule and accepts no CORS/browser-origin requests.

## Control

PowerShell:

```powershell
.\acer-service-control.ps1 status
.\acer-service-control.ps1 fan 50 60
.\acer-service-control.ps1 fan auto
.\acer-service-control.ps1 keyboard color 0411FF brightness 50
.\acer-service-control.ps1 profile next
```

Python:

```powershell
py -m pip install .\clients\python
acer-service-control status
acer-service-control fan 50 60
```

Python API:

```python
from acer_control_client import AcerControlClient

client = AcerControlClient()
print(client.get_status())
client.set_fan("custom", 50, 60)
```

## Persistence

Only successfully applied and verified settings are persisted. Restoration order is profile, fans, then keyboard because profile changes reset fan behavior.

On first installation, the service captures the current profile and a uniform static keyboard state. Fan mode remains unmanaged until explicitly set because firmware exposes fan targets but does not report whether Auto, Max, or Custom mode is active.

The service restores managed settings at startup and resume. It does not continuously overwrite changes made in NitroSense. Direct use of `acer-control.ps1` bypasses persistence and can cause temporary drift until the next restore or `settings apply` call.

## Uninstall

```powershell
.\scripts\Uninstall-AcerControlService.ps1
```

Desired registry state is retained for reinstall. Pass `-Purge` to remove it. Acer OEM services and drivers are never modified.

## Limitations

- Keyboard writes support uniform static color only.
- Eco and Turbo availability still depends on firmware and AC/battery state.
- This project is specific to systems exposing `root\wmi:AcerGamingFunction`.
- The shared token prevents unauthenticated browser requests; it is not a security boundary between local user processes.