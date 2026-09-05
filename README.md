# Acer Control

Windows tools for controlling and investigating supported Acer Nitro laptop
hardware. The project can manage fan targets, static keyboard lighting, and
performance profiles either directly through Acer's WMI firmware interface or
through an installable local service.

> [!CAUTION]
> These tools write model-specific firmware settings. Incorrect fan or profile
> settings can affect system temperature, noise, performance, and stability.
> Confirm compatibility with your exact laptop and keep Acer firmware and
> drivers available before making changes.

This is an independent project and is not affiliated with or endorsed by Acer.
See [MANUFACTURER.md](MANUFACTURER.md) for attribution details.

## Choose a Tool

| Path | Purpose | Main requirement |
|---|---|---|
| [Installable service](installable_service/README.md) | Persistent fan, keyboard, and profile control with startup/resume restoration and authenticated local clients | Windows x64, .NET 10 SDK to build, administrator access to install |
| [`acer-control.ps1`](acer-control.ps1) | Direct elevated firmware control and recovery without installing the custom service | Windows PowerShell 5.1 and `root\wmi:AcerGamingFunction` |
| [`acer-fan-control.ps1`](acer-fan-control.ps1) | Set custom fan percentages through AcerAgentService | AcerAgentService on `127.0.0.1:46933` |
| [`acer-performance-profile.ps1`](acer-performance-profile.ps1) | Read or change NitroSense performance profiles through AcerAgentService | AcerAgentService on `127.0.0.1:46933` |
| [`acer-keyboard-led.ps1`](acer-keyboard-led.ps1) | Read or set static keyboard color and brightness | Acer Lighting Service and bundled OpenRGB on `127.0.0.1:6742` |
| [`acer-enumerate-services.ps1`](acer-enumerate-services.ps1) | Identify Windows services likely distributed by Acer | Read-only CIM, file metadata, and signature access |
| [Key remapping tools](key-remap/README.md) | Detect and experimentally remap the NitroSense key | Interactive Windows desktop session |

See [SERVICES_AND_TOOLS.md](SERVICES_AND_TOOLS.md) for the full comparison and
[REQUIREMENTS.md](REQUIREMENTS.md) for detailed platform, privilege, firmware,
and dependency requirements.

## Installable Service Quick Start

The service is the primary path for persistent control. It runs as
`LocalSystem`, serializes firmware operations, stores desired settings in the
registry, restores them after startup and resume, and exposes an authenticated
API only on `127.0.0.1:46934`.

Build and publish from PowerShell:

```powershell
Set-Location .\installable_service
.\scripts\Publish-AcerControlService.ps1
```

The publish script runs the .NET tests and creates a self-contained `win-x64`
build under `artifacts\publish\AcerControlService`.

Run the clean installer from an elevated Windows PowerShell 5.1 or PowerShell
7 session:

```powershell
.\scripts\Install-AcerControlService.ps1
```

Control the installed service without elevation under the default ACLs:

```powershell
.\acer-service-control.ps1 status
.\acer-service-control.ps1 fan 50 60
.\acer-service-control.ps1 fan auto
.\acer-service-control.ps1 keyboard color 0411FF brightness 50
.\acer-service-control.ps1 profile next
```

The service also includes a Python 3.10+ client:

```powershell
py -m pip install .\clients\python
acer-service-control status
```

Full installation, persistence, API, and removal details are in the
[service README](installable_service/README.md) and
[API reference](installable_service/docs/api.md).

## Direct Firmware Control

Use the direct script as an elevated recovery path or when the custom service
is not installed:

```powershell
.\acer-control.ps1 status
.\acer-control.ps1 fan auto
.\acer-control.ps1 fan 50 60
.\acer-control.ps1 keyboard color "0411FF" brightness 50
.\acer-control.ps1 profile Balanced
```

Hardware commands are executed through inbox Windows PowerShell 5.1 because
`Get-WmiObject` is not available in PowerShell 7. The script relaunches itself
in the required host and requests elevation when necessary.

Do not run competing fan, profile, or keyboard controllers unless their
interaction is understood. NitroSense, Acer services, the custom service, and
standalone scripts can overwrite one another's settings. Profile changes can
also reset custom fan behavior.

## Test

Run the service tests:

```powershell
Set-Location .\installable_service
dotnet test .\AcerControl.sln
```

Run the Python client tests from the same directory:

```powershell
$env:PYTHONPATH = (Resolve-Path .\clients\python\src)
py -3 -m unittest discover -s .\clients\python\tests -v
```

## Privacy and Scope

The custom AcerControlService and its clients use loopback communication and do
not implement cloud endpoints or outbound telemetry. The stock Acer software
analyzed in this repository has separate network behavior documented in
[PRIVACY.md](PRIVACY.md).

Hardware and service findings were collected on an Acer Nitro AN17-42 and may
not apply to other models, BIOS versions, drivers, or Acer software releases.
The evidence and limitations are documented in
[acer_analysis.md](acer_analysis.md).

## Documentation

- [Requirements](REQUIREMENTS.md)
- [Services and tools reference](SERVICES_AND_TOOLS.md)
- [Installable service](installable_service/README.md)
- [Service API](installable_service/docs/api.md)
- [Experimental key remapping](key-remap/README.md)
- [Privacy findings](PRIVACY.md)
- [Manufacturer attribution](MANUFACTURER.md)
- [Project and third-party licenses](LICENSES.md)

## License

Project-authored work is available under the [MIT License](LICENSE), subject to
the exclusions and third-party terms described in [LICENSES.md](LICENSES.md).
