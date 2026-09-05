# Acer Control

Acer Control manages Nitro fan targets, static keyboard lighting, and performance profiles through the `AcerGamingFunction` WMI firmware interface.

The repository contains two control paths:

- `acer-control.ps1` directly accesses firmware and remains available as an elevated recovery tool.
- `AcerControlService` runs as `LocalSystem`, persists desired settings, restores managed settings after startup/resume, and exposes an authenticated loopback API.

## Build

Requirements: Windows x64 and the .NET 10 SDK.

Build all projects:

```powershell
.\build-all.ps1
```

Pass `-Clean` to clean the selected configuration before restoring and building:

```powershell
.\build-all.ps1 -Clean
```

Create the self-contained service package:

```powershell
.\scripts\Publish-AcerControlService.ps1
```

The publish script runs all tests and writes the executable to `artifacts\publish\AcerControlService`. This publish output must exist before installation; a normal build does not create it.

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
- Waits up to 60 seconds for the Acer firmware interface to become ready.
- Sets fan mode to Auto when no managed fan preference already exists.

The service listens only on `127.0.0.1:46934`. It creates no firewall rule and accepts no CORS/browser-origin requests.

During installation, service health may briefly report `starting` with the message `Waiting for the Acer firmware interface.` Installation continues when `AcerGamingFunction` becomes available and fails if it is not ready within 60 seconds.

## Control

### PowerShell client

Run `acer-service-control.ps1` from the `installable_service` directory. The
script accepts command arguments rather than PowerShell named parameters.

| Command | Description | Example |
|---|---|---|
| No arguments | Show help. | `.\acer-service-control.ps1` |
| `help` | Show help. The aliases are `--help`, `-h`, `-help`, and `/?`. | `.\acer-service-control.ps1 help`<br>`.\acer-service-control.ps1 --help`<br>`.\acer-service-control.ps1 -h`<br>`.\acer-service-control.ps1 -help`<br>`.\acer-service-control.ps1 /?` |
| `status` | Show the combined fan, keyboard, and profile status. | `.\acer-service-control.ps1 status` |
| `fan status` | Show the current fan mode, targets, and readings. | `.\acer-service-control.ps1 fan status` |
| `fan auto` | Let the firmware control both fans automatically. | `.\acer-service-control.ps1 fan auto` |
| `fan max` | Run both fans in maximum mode. | `.\acer-service-control.ps1 fan max` |
| `fan <CPU_PERCENT> <GPU_PERCENT>` | Set custom CPU and GPU fan targets. Each value must be an integer from `0` through `100`. | `.\acer-service-control.ps1 fan 50 60` |
| `fan custom <CPU_PERCENT> <GPU_PERCENT>` | Explicit form of the custom fan command. | `.\acer-service-control.ps1 fan custom 50 60` |
| `keyboard status` | Show the current static keyboard color and brightness. | `.\acer-service-control.ps1 keyboard status` |
| `keyboard color <RRGGBB> brightness <PERCENT>` | Set a uniform six-digit RGB color and brightness from `0` through `100`. A leading `#` is accepted when the color is quoted. The `color` and `brightness` pairs may appear in either order. | `.\acer-service-control.ps1 keyboard color 0411FF brightness 50`<br>`.\acer-service-control.ps1 keyboard brightness 50 color '#0411FF'` |
| `led ...` | Alias for every `keyboard` command. | `.\acer-service-control.ps1 led status`<br>`.\acer-service-control.ps1 led color 0411FF brightness 50` |
| `profile status` | Show the current profile and the profiles supported by the firmware. | `.\acer-service-control.ps1 profile status` |
| `profile next` | Switch to the next firmware-supported profile in the order Eco, Quiet, Balanced, Performance, and Turbo. | `.\acer-service-control.ps1 profile next` |
| `profile <NAME>` | Select a profile by name. Names are case-insensitive, and availability depends on the firmware. | `.\acer-service-control.ps1 profile Eco`<br>`.\acer-service-control.ps1 profile Quiet`<br>`.\acer-service-control.ps1 profile Balanced`<br>`.\acer-service-control.ps1 profile Performance`<br>`.\acer-service-control.ps1 profile Turbo` |
| `settings apply` | Reapply all managed settings saved by the service. | `.\acer-service-control.ps1 settings apply` |

Commands, keywords, and option names may also use a `--` prefix. For example:

```powershell
.\acer-service-control.ps1 --fan --custom 50 60
.\acer-service-control.ps1 --keyboard --color 0411FF --brightness 50
.\acer-service-control.ps1 --profile --next
```

The client reads the API token from `%ProgramData%\AcerControl\api-token` and
connects to `http://127.0.0.1:46934` by default. Set
`ACER_CONTROL_TOKEN_FILE` or `ACER_CONTROL_BASE_URL` to override those values.

### Python client

```powershell
py -m pip install .\clients\python
acer-service-control status
acer-service-control fan 50 60
```

### Python API

```python
from acer_control_client import AcerControlClient

client = AcerControlClient()
print(client.get_status())
client.set_fan("custom", 50, 60)
```

## Persistence

Only successfully applied and verified settings are persisted. Restoration order is profile, fans, then keyboard because profile changes reset fan behavior.

See [REGISTRY.md](REGISTRY.md) for the complete key, value, type, permission, and removal reference.

On first installation, the service captures the current profile and a uniform static keyboard state. If no managed fan preference exists, the installer applies and verifies Auto mode through the service API. The service then saves Auto as the desired fan mode in the registry for restoration at startup and resume. Existing managed fan preferences retained from an earlier installation are not overwritten.

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