# Manufacturer, Product, and Copyright Attribution

This is an independent interoperability project. It is not affiliated with, endorsed by, sponsored by, or supported by Acer Incorporated or Microsoft Corporation. Product and service names are used only to identify compatible hardware, software, protocols, and build tools.

## Acer

Acer, Acer product names, Acer software names, Acer service names, and associated logos and brand assets are owned by Acer Incorporated or its affiliates. Acer firmware, drivers, applications, services, documentation, and other vendor-supplied files remain copyright Acer Incorporated and its licensors. All rights reserved by their respective owners.

Names referenced by this project include:

| Owner | Name or identifier | Use in this project |
|---|---|---|
| Acer Incorporated | Acer | Hardware manufacturer and software publisher |
| Acer Incorporated | Acer Nitro | Gaming notebook product family |
| Acer Incorporated | Acer Nitro AN17-42 | Laptop model on which this project was researched and tested |
| Acer Incorporated | NitroSense | Acer hardware monitoring and control application |
| Acer Incorporated | AcerSense | Acer system management application family |
| Acer Incorporated | Predator and PredatorSense | Acer gaming product and control application names found in shared Acer components |
| Acer Incorporated | Acer Care Center | Battery, storage, and support application |
| Acer Incorporated | Acer Quick Access | Acer hardware convenience application |
| Acer Incorporated | Acer Experience Zone | Acer local application and service component |
| Acer Incorporated | Acer QuickPanel and Acer Purified Voice | Acer applications detected during system analysis |
| Acer Incorporated | AcerAgentService, AcerGamingFunction, and other Acer service/interface identifiers | Technical identifiers used for compatibility and analysis |

No ownership is claimed in these names, Acer binaries, Acer firmware interfaces, or Acer documentation. The project name "Acer Control" is descriptive of compatibility and does not imply that Acer published or approved it.

## Microsoft

Microsoft, Windows, Windows PowerShell, PowerShell, .NET, ASP.NET Core, MSBuild, NuGet, Roslyn, Visual Studio, and Visual Studio Test Platform are names or trademarks of the Microsoft group of companies. Microsoft brand assets are owned by Microsoft Corporation and its affiliates.

Proprietary Windows components and tools are copyright Microsoft Corporation. Open-source Microsoft and .NET components retain their upstream copyright notices and are licensed as listed in [LICENSES.md](LICENSES.md).

### Microsoft build and platform tools used

| Tool or component | Project use | Version |
|---|---|---|
| .NET SDK | Restore, compile, test, and publish the Windows service | 10.x; 10.0.400 observed during documentation |
| Microsoft Build Engine (MSBuild) | Build orchestration invoked by the .NET SDK | 18.9.6 observed during documentation |
| Roslyn C# compiler | Compiles the C# service and tests; also underlies PowerShell `Add-Type` compilation | Bundled with the .NET SDK; 5.900.26.38015 observed |
| NuGet | Restores declared .NET packages | Bundled with the .NET SDK |
| Microsoft Visual Studio Test Platform / `Microsoft.NET.Test.Sdk` | Runs the service test suite | 17.14.1 package |
| Windows PowerShell | Runs the root scripts and Windows management commands | 5.1 |
| PowerShell | Optional shell for build, publish, install, and client scripts | 7.x supported |
| Windows SDK and inbox utilities | Windows APIs plus `sc.exe` and `icacls.exe` used for service installation | Supplied by the installed Windows/build environment |

The observed versions describe the machine used to prepare this document. Supported requirements remain those stated in [REQUIREMENTS.md](REQUIREMENTS.md).

## Project-authored work

Except for third-party packages, vendor software, generated build output, and analysis/reference artifacts obtained from installed software, original source code, scripts, tests, and documentation authored for this project are:

Copyright (c) 2026 Matt Deren

They are licensed under the MIT License stated in [LICENSES.md](LICENSES.md). Every third-party component retains its own copyright and license.
