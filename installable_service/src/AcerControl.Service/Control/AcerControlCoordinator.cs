using AcerControl.Service.Hardware;
using AcerControl.Service.Models;
using AcerControl.Service.Persistence;

namespace AcerControl.Service.Control;

public sealed class AcerControlCoordinator(
    IAcerHardwareController hardware,
    ISettingsStore settings,
    ILogger<AcerControlCoordinator> logger)
{
    private static readonly string[] ProfileOrder =
        ["Eco", "Quiet", "Balanced", "Performance", "Turbo"];
    private readonly SemaphoreSlim hardwareLock = new(1, 1);

    public async Task<ControlStatus> GetStatusAsync(CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var desired = settings.LoadDesiredState();
            var fan = await hardware.GetFanStateAsync(cancellationToken);
            if (desired.FanManaged)
            {
                fan = fan with { Mode = desired.FanMode };
            }

            var keyboard = await hardware.GetKeyboardStateAsync(cancellationToken);
            var profile = await hardware.GetProfileStateAsync(cancellationToken);
            return new ControlStatus(fan, keyboard, profile);
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public async Task<FanState> GetFanAsync(CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var fan = await hardware.GetFanStateAsync(cancellationToken);
            var desired = settings.LoadDesiredState();
            return desired.FanManaged ? fan with { Mode = desired.FanMode } : fan;
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public async Task<FanState> SetFanAsync(
        FanUpdate update,
        CancellationToken cancellationToken)
    {
        ValidateFan(update);
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var result = await hardware.SetFanAsync(update, cancellationToken);
            SaveAfterApply(settings.LoadDesiredState() with
            {
                FanManaged = true,
                FanMode = update.Mode,
                FanCpuPercent = update.Mode == FanMode.Custom ? update.CpuPercent : null,
                FanGpuPercent = update.Mode == FanMode.Custom ? update.GpuPercent : null
            });
            return result;
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public Task<KeyboardState> GetKeyboardAsync(CancellationToken cancellationToken)
    {
        return ExecuteLockedAsync(hardware.GetKeyboardStateAsync, cancellationToken);
    }

    public async Task<KeyboardState> SetKeyboardAsync(
        KeyboardUpdate update,
        CancellationToken cancellationToken)
    {
        ValidateKeyboard(update);
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var result = await hardware.SetKeyboardAsync(update, cancellationToken);
            SaveAfterApply(settings.LoadDesiredState() with
            {
                KeyboardManaged = true,
                KeyboardColor = NormalizeColor(update.Color),
                KeyboardBrightness = update.Brightness
            });
            return result;
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public Task<ProfileState> GetProfileAsync(CancellationToken cancellationToken)
    {
        return ExecuteLockedAsync(hardware.GetProfileStateAsync, cancellationToken);
    }

    public Task<ProfileState> SetProfileAsync(
        string profile,
        CancellationToken cancellationToken)
    {
        return SetProfileCoreAsync(profile, cancellationToken);
    }

    public async Task<ProfileState> SetNextProfileAsync(
        CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var current = await hardware.GetProfileStateAsync(cancellationToken);
            var supported = ProfileOrder
                .Where(item => current.SupportedProfiles.Contains(
                    item,
                    StringComparer.OrdinalIgnoreCase))
                .ToArray();
            if (supported.Length == 0)
            {
                throw new FirmwareOperationException(
                    "The firmware did not report any supported profiles.");
            }

            var index = Array.FindIndex(
                supported,
                item => string.Equals(item, current.Profile, StringComparison.OrdinalIgnoreCase));
            return await SetProfileWhileLockedAsync(
                supported[(index + 1) % supported.Length],
                cancellationToken);
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public async Task CaptureInitialStateAsync(CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var desired = settings.LoadDesiredState();
            var changed = false;

            if (!desired.ProfileManaged)
            {
                try
                {
                    var profile = await hardware.GetProfileStateAsync(cancellationToken);
                    if (!profile.Profile.StartsWith("Unknown", StringComparison.Ordinal))
                    {
                        desired = desired with
                        {
                            ProfileManaged = true,
                            Profile = profile.Profile
                        };
                        changed = true;
                    }
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    logger.LogWarning(exception, "Could not capture the initial profile state.");
                }
            }

            if (!desired.KeyboardManaged)
            {
                try
                {
                    var keyboard = await hardware.GetKeyboardStateAsync(cancellationToken);
                    if (string.Equals(keyboard.Mode, "Static", StringComparison.Ordinal) &&
                        keyboard.Colors.Count == 1)
                    {
                        desired = desired with
                        {
                            KeyboardManaged = true,
                            KeyboardColor = keyboard.Colors[0],
                            KeyboardBrightness = keyboard.Brightness
                        };
                        changed = true;
                    }
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    logger.LogWarning(exception, "Could not capture the initial keyboard state.");
                }
            }

            if (changed)
            {
                settings.SaveDesiredState(desired);
            }
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    public async Task RestoreAsync(CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            var desired = settings.LoadDesiredState();
            var failures = new List<string>();
            if (desired.ProfileManaged && desired.Profile is not null)
            {
                if (!await RestorePartAsync(
                    "profile",
                    token => hardware.SetProfileAsync(desired.Profile, token),
                    cancellationToken))
                {
                    failures.Add("profile");
                }
            }

            if (desired.FanManaged && desired.FanMode is not null)
            {
                var fan = new FanUpdate(
                    desired.FanMode.Value,
                    desired.FanCpuPercent,
                    desired.FanGpuPercent);
                if (!await RestorePartAsync(
                    "fan",
                    token => hardware.SetFanAsync(fan, token),
                    cancellationToken))
                {
                    failures.Add("fan");
                }
            }

            if (desired.KeyboardManaged &&
                desired.KeyboardColor is not null &&
                desired.KeyboardBrightness is not null)
            {
                var keyboard = new KeyboardUpdate(
                    desired.KeyboardColor,
                    desired.KeyboardBrightness.Value);
                if (!await RestorePartAsync(
                    "keyboard",
                    token => hardware.SetKeyboardAsync(keyboard, token),
                    cancellationToken))
                {
                    failures.Add("keyboard");
                }
            }

            if (failures.Count > 0)
            {
                throw new FirmwareOperationException(
                    $"Could not restore managed settings: {string.Join(", ", failures)}.");
            }
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    private async Task<ProfileState> SetProfileCoreAsync(
        string profile,
        CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            return await SetProfileWhileLockedAsync(profile, cancellationToken);
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    private async Task<ProfileState> SetProfileWhileLockedAsync(
        string profile,
        CancellationToken cancellationToken)
    {
        var result = await hardware.SetProfileAsync(profile, cancellationToken);
        var desired = settings.LoadDesiredState() with
        {
            ProfileManaged = true,
            Profile = result.Profile
        };

        if (desired.FanManaged && desired.FanMode is not null)
        {
            await hardware.SetFanAsync(
                new FanUpdate(
                    desired.FanMode.Value,
                    desired.FanCpuPercent,
                    desired.FanGpuPercent),
                cancellationToken);
        }

        SaveAfterApply(desired);
        return result;
    }

    private async Task<T> ExecuteLockedAsync<T>(
        Func<CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken)
    {
        await hardwareLock.WaitAsync(cancellationToken);
        try
        {
            return await operation(cancellationToken);
        }
        finally
        {
            hardwareLock.Release();
        }
    }

    private async Task<bool> RestorePartAsync<T>(
        string name,
        Func<CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken)
    {
        try
        {
            await operation(cancellationToken);
            logger.LogInformation("Restored managed {SettingName} settings.", name);
            return true;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Could not restore managed {SettingName} settings.", name);
            return false;
        }
    }

    private void SaveAfterApply(DesiredState state)
    {
        try
        {
            settings.SaveDesiredState(state);
        }
        catch (Exception exception)
        {
            throw new SettingsPersistenceException(
                "The hardware setting was applied, but its desired state could not be persisted.",
                exception);
        }
    }

    private static void ValidateFan(FanUpdate update)
    {
        if (update.Mode == FanMode.Custom &&
            (update.CpuPercent is null || update.GpuPercent is null))
        {
            throw new ArgumentException(
                "Custom fan mode requires cpuPercent and gpuPercent.");
        }
    }

    private static void ValidateKeyboard(KeyboardUpdate update)
    {
        _ = NormalizeColor(update.Color);
    }

    private static string NormalizeColor(string color)
    {
        var value = color.Trim().TrimStart('#');
        if (value.Length != 6 || !value.All(Uri.IsHexDigit))
        {
            throw new ArgumentException($"'{color}' is not a six-digit RGB color.");
        }

        return $"#{value.ToUpperInvariant()}";
    }
}