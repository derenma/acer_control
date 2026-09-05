namespace AcerControl.Service.Models;

public enum FanMode
{
    Auto,
    Max,
    Custom
}

public sealed record FanState(
    FanMode? Mode,
    byte CpuPercent,
    byte GpuPercent,
    int? CpuRpm,
    int? GpuRpm,
    int? CpuTempC,
    int? GpuTempC);

public sealed record FanUpdate(FanMode Mode, byte? CpuPercent, byte? GpuPercent);

public sealed record KeyboardState(
    string Mode,
    IReadOnlyList<string> Colors,
    byte Brightness);

public sealed record KeyboardUpdate(string Color, byte Brightness);

public sealed record ProfileState(
    string Profile,
    byte ModeId,
    IReadOnlyList<string> SupportedProfiles);

public sealed record ControlStatus(
    FanState Fan,
    KeyboardState Keyboard,
    ProfileState Profile);

public sealed record DesiredState(
    bool ProfileManaged = false,
    string? Profile = null,
    bool FanManaged = false,
    FanMode? FanMode = null,
    byte? FanCpuPercent = null,
    byte? FanGpuPercent = null,
    bool KeyboardManaged = false,
    string? KeyboardColor = null,
    byte? KeyboardBrightness = null);

public sealed record ServiceConfiguration(
    int ApiPort = 46934,
    bool RestoreOnStartup = true,
    bool RestoreOnResume = true);

public sealed record ProfileUpdate(string Profile);

public sealed record ApiError(string Code, string Message);

public sealed record ApiErrorResponse(
    string Status,
    ApiError Error,
    bool? Applied = null,
    bool? Persisted = null);

public sealed record HealthResponse(string Status, string? Message);

public sealed class FirmwareUnavailableException(string message, Exception? inner = null)
    : Exception(message, inner);

public sealed class FirmwareOperationException(string message, Exception? inner = null)
    : Exception(message, inner);

public sealed class SettingsPersistenceException(string message, Exception inner)
    : Exception(message, inner)
{
    public bool Applied => true;

    public bool Persisted => false;
}