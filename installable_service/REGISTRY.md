# Registry Reference

Acer Control stores service configuration and desired hardware state in the 64-bit local-machine registry view. The installer also registers the Windows service through the Service Control Manager (SCM).

Do not edit these values while the service is running. Use `acer-service-control.ps1` or the local API for hardware preferences so changes are applied, verified, and persisted together.

## Application settings

### `HKEY_LOCAL_MACHINE\SOFTWARE\AcerControl`

This is a container key. It has no values of its own.

### `HKEY_LOCAL_MACHINE\SOFTWARE\AcerControl\Service`

| Value | Type | Default | Proper values | Purpose |
|---|---|---:|---|---|
| `SchemaVersion` | `REG_DWORD` | `1` | `1` | Registry schema version. |
| `ApiPort` | `REG_DWORD` | `46934` | `46934` | Loopback HTTP API port. The current installer and clients expect this value. |
| `RestoreOnStartup` | `REG_DWORD` | `1` | `0` or `1` | Restores managed settings during service startup when set to `1`. |
| `RestoreOnResume` | `REG_DWORD` | `1` | `0` or `1` | Restores managed settings after resume when set to `1`. |

The installer creates missing values but preserves existing values during reinstall.

### `HKEY_LOCAL_MACHINE\SOFTWARE\AcerControl\Service\DesiredState`

The service creates this key when it first saves desired state. Optional values are absent when their setting is unmanaged or not applicable.

| Value | Type | Proper values | Purpose |
|---|---|---|---|
| `ProfileManaged` | `REG_DWORD` | `0` or `1` | Whether the service restores `Profile`. |
| `Profile` | `REG_SZ` | `Eco`, `Quiet`, `Balanced`, `Performance`, or `Turbo` | Desired performance profile. It must be supported by the current firmware. Absent when unmanaged. |
| `FanManaged` | `REG_DWORD` | `0` or `1` | Whether the service restores fan settings. A successful first installation sets this to `1`. |
| `FanMode` | `REG_SZ` | `Auto`, `Max`, or `Custom` | Desired fan mode. A successful first installation defaults to `Auto`. Absent when unmanaged. |
| `FanCpuPercent` | `REG_DWORD` | `0` through `100` | CPU fan target. Required for `Custom`; absent for `Auto`, `Max`, or unmanaged fans. |
| `FanGpuPercent` | `REG_DWORD` | `0` through `100` | GPU fan target. Required for `Custom`; absent for `Auto`, `Max`, or unmanaged fans. |
| `KeyboardManaged` | `REG_DWORD` | `0` or `1` | Whether the service restores keyboard settings. |
| `KeyboardColor` | `REG_SZ` | `#RRGGBB`, uppercase hexadecimal | Uniform static keyboard color. Absent when unmanaged. |
| `KeyboardBrightness` | `REG_DWORD` | `0` through `100` | Static keyboard brightness. Absent when unmanaged. |
| `LastUpdatedUtc` | `REG_SZ` | ISO 8601 round-trip timestamp | UTC timestamp written whenever desired state is saved. |

Managed-value consistency rules:

- A managed flag set to `0` means its related values must not be treated as desired state.
- `FanMode=Custom` requires both fan percentage values. Other fan modes omit them.
- Managed keyboard state requires both `KeyboardColor` and `KeyboardBrightness`.
- The service saves only settings that were successfully applied and verified.

## Permissions

The installer disables inherited permissions on `HKEY_LOCAL_MACHINE\SOFTWARE\AcerControl\Service` and applies these inheritable access rules:

| Principal | Access |
|---|---|
| `SYSTEM` (`S-1-5-18`) | Full control |
| `Administrators` (`S-1-5-32-544`) | Full control |
| `Users` (`S-1-5-32-545`) | Read |

## Windows service registration

The installer uses `sc.exe`; Windows owns the resulting key:

`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AcerControlService`

The project configures the following principal values. The image path is stored as a quoted absolute path; `%ProgramFiles%` below denotes the machine's actual Program Files directory.

| Value | Type | Proper value |
|---|---|---|
| `Type` | `REG_DWORD` | `0x10` (`16`), Win32 own-process service |
| `Start` | `REG_DWORD` | `2`, automatic start |
| `DelayedAutoStart` | `REG_DWORD` | `1`, delayed automatic start enabled |
| `ErrorControl` | `REG_DWORD` | `1`, normal error handling |
| `ImagePath` | `REG_EXPAND_SZ` | `"%ProgramFiles%\AcerControl\AcerControlService.exe"` |
| `DisplayName` | `REG_SZ` | `Acer Control Service` |
| `ObjectName` | `REG_SZ` | `LocalSystem` |
| `Description` | `REG_SZ` | `Controls Acer Nitro fan, keyboard lighting, and performance profile settings.` |
| `FailureActions` | `REG_BINARY` | SCM encoding of a `86400`-second reset period and restarts after 5, 15, and 60 seconds |
| `FailureActionsOnNonCrashFailures` | `REG_DWORD` | `1`, enabled |

The service name is the key name, `AcerControlService`. SCM may add other Windows-managed metadata or security values. Their raw representation can vary by Windows version and should be managed with `sc.exe`, not Registry Editor.

When the service writes to Windows Event Log, .NET or Windows may also create an `AcerControlService` event-source subkey under `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application`. That key is runtime-managed and is not part of the Acer Control settings schema.

## Removal

Normal uninstall removes the SCM service registration but retains `HKEY_LOCAL_MACHINE\SOFTWARE\AcerControl` for reinstall. Running the uninstall script with `-Purge` also removes the complete Acer Control application-settings tree.