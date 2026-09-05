using Microsoft.Win32;
using AcerControl.Service.Models;

namespace AcerControl.Service.Persistence;

public sealed class RegistrySettingsStore : ISettingsStore
{
    public const string RegistryPath = @"SOFTWARE\AcerControl\Service";
    private const string DesiredStatePath = RegistryPath + @"\DesiredState";

    public ServiceConfiguration LoadConfiguration()
    {
        using var baseKey = OpenLocalMachine();
        using var key = baseKey.OpenSubKey(RegistryPath);
        return new ServiceConfiguration(
            ReadInt32(key, "ApiPort", 46934),
            ReadBoolean(key, "RestoreOnStartup", true),
            ReadBoolean(key, "RestoreOnResume", true));
    }

    public DesiredState LoadDesiredState()
    {
        using var baseKey = OpenLocalMachine();
        using var key = baseKey.OpenSubKey(DesiredStatePath);
        return new DesiredState(
            ReadBoolean(key, "ProfileManaged", false),
            key?.GetValue("Profile") as string,
            ReadBoolean(key, "FanManaged", false),
            ReadFanMode(key?.GetValue("FanMode") as string),
            ReadByte(key, "FanCpuPercent"),
            ReadByte(key, "FanGpuPercent"),
            ReadBoolean(key, "KeyboardManaged", false),
            key?.GetValue("KeyboardColor") as string,
            ReadByte(key, "KeyboardBrightness"));
    }

    public void SaveDesiredState(DesiredState state)
    {
        using var baseKey = OpenLocalMachine();
        using var serviceKey = baseKey.CreateSubKey(RegistryPath, true);
        serviceKey.SetValue("SchemaVersion", 1, RegistryValueKind.DWord);
        EnsureDefault(serviceKey, "ApiPort", 46934);
        EnsureDefault(serviceKey, "RestoreOnStartup", 1);
        EnsureDefault(serviceKey, "RestoreOnResume", 1);

        using var key = baseKey.CreateSubKey(DesiredStatePath, true);
        SetBoolean(key, "ProfileManaged", state.ProfileManaged);
        SetOptionalString(key, "Profile", state.Profile);
        SetBoolean(key, "FanManaged", state.FanManaged);
        SetOptionalString(key, "FanMode", state.FanMode?.ToString());
        SetOptionalDword(key, "FanCpuPercent", state.FanCpuPercent);
        SetOptionalDword(key, "FanGpuPercent", state.FanGpuPercent);
        SetBoolean(key, "KeyboardManaged", state.KeyboardManaged);
        SetOptionalString(key, "KeyboardColor", state.KeyboardColor);
        SetOptionalDword(key, "KeyboardBrightness", state.KeyboardBrightness);
        key.SetValue(
            "LastUpdatedUtc",
            DateTimeOffset.UtcNow.ToString("O"),
            RegistryValueKind.String);
    }

    private static RegistryKey OpenLocalMachine()
    {
        return RegistryKey.OpenBaseKey(
            RegistryHive.LocalMachine,
            RegistryView.Registry64);
    }

    private static void EnsureDefault(RegistryKey key, string name, int value)
    {
        if (key.GetValue(name) is null)
        {
            key.SetValue(name, value, RegistryValueKind.DWord);
        }
    }

    private static bool ReadBoolean(RegistryKey? key, string name, bool fallback)
    {
        return key?.GetValue(name) is int value ? value != 0 : fallback;
    }

    private static int ReadInt32(RegistryKey? key, string name, int fallback)
    {
        return key?.GetValue(name) is int value ? value : fallback;
    }

    private static byte? ReadByte(RegistryKey? key, string name)
    {
        return key?.GetValue(name) is int value && value is >= 0 and <= 100
            ? (byte)value
            : null;
    }

    private static FanMode? ReadFanMode(string? value)
    {
        return Enum.TryParse<FanMode>(value, true, out var mode) ? mode : null;
    }

    private static void SetBoolean(RegistryKey key, string name, bool value)
    {
        key.SetValue(name, value ? 1 : 0, RegistryValueKind.DWord);
    }

    private static void SetOptionalDword(RegistryKey key, string name, byte? value)
    {
        if (value is null)
        {
            key.DeleteValue(name, false);
        }
        else
        {
            key.SetValue(name, value.Value, RegistryValueKind.DWord);
        }
    }

    private static void SetOptionalString(RegistryKey key, string name, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            key.DeleteValue(name, false);
        }
        else
        {
            key.SetValue(name, value, RegistryValueKind.String);
        }
    }
}