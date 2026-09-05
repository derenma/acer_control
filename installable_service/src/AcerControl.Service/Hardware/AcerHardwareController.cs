using System.Globalization;
using AcerControl.Service.Models;

namespace AcerControl.Service.Hardware;

public sealed class AcerHardwareController(IAcerGamingInterface gaming)
    : IAcerHardwareController
{
    private const ulong AutoFanBehavior = 0x00410009;
    private const ulong MaxFanBehavior = 0x00820009;
    private const ulong CustomFanBehavior = 0x00C30009;
    private const int SettleMilliseconds = 300;

    private static readonly byte[] KeyboardZones = [0x01, 0x02, 0x04, 0x08];
    private static readonly IReadOnlyDictionary<string, byte> ProfileIds =
        new Dictionary<string, byte>(StringComparer.OrdinalIgnoreCase)
        {
            ["Eco"] = 6,
            ["Quiet"] = 0,
            ["Balanced"] = 1,
            ["Performance"] = 4,
            ["Turbo"] = 5
        };
    private static readonly IReadOnlyDictionary<byte, string> ProfileNames =
        ProfileIds.ToDictionary(pair => pair.Value, pair => pair.Key);
    private static readonly string[] ProfileOrder =
        ["Eco", "Quiet", "Balanced", "Performance", "Turbo"];

    public Task<FanState> GetFanStateAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(ReadFanState(null));
    }

    public async Task<FanState> SetFanAsync(
        FanUpdate update,
        CancellationToken cancellationToken)
    {
        ValidateFanUpdate(update);

        switch (update.Mode)
        {
            case FanMode.Auto:
                gaming.Set("SetGamingFanBehavior", AutoFanBehavior);
                break;
            case FanMode.Max:
                gaming.Set("SetGamingFanBehavior", MaxFanBehavior);
                break;
            case FanMode.Custom:
                await SetCustomFansAsync(
                    update.CpuPercent!.Value,
                    update.GpuPercent!.Value,
                    cancellationToken);
                return ReadFanState(FanMode.Custom);
            default:
                throw new ArgumentOutOfRangeException(nameof(update));
        }

        await Task.Delay(SettleMilliseconds, cancellationToken);
        return ReadFanState(update.Mode);
    }

    public Task<KeyboardState> GetKeyboardStateAsync(
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(ReadKeyboardState());
    }

    public async Task<KeyboardState> SetKeyboardAsync(
        KeyboardUpdate update,
        CancellationToken cancellationToken)
    {
        var color = NormalizeColor(update.Color);
        var red = byte.Parse(color.AsSpan(1, 2), NumberStyles.HexNumber);
        var green = byte.Parse(color.AsSpan(3, 2), NumberStyles.HexNumber);
        var blue = byte.Parse(color.AsSpan(5, 2), NumberStyles.HexNumber);

        foreach (var zone in KeyboardZones)
        {
            gaming.Set(
                "SetGamingRgbKb",
                FirmwareProtocol.EncodeColor(zone, red, green, blue));
        }

        gaming.Set(
            "SetGamingKBBacklight",
            FirmwareProtocol.CreateStaticKeyboardPayload(
                update.Brightness,
                red,
                green,
                blue));

        await Task.Delay(SettleMilliseconds, cancellationToken);
        var state = ReadKeyboardState();
        if (!string.Equals(state.Mode, "Static", StringComparison.Ordinal) ||
            state.Brightness != update.Brightness ||
            state.Colors.Count != 1 ||
            !string.Equals(state.Colors[0], color, StringComparison.OrdinalIgnoreCase))
        {
            throw new FirmwareOperationException(
                $"Keyboard readback was mode '{state.Mode}', color " +
                $"'{string.Join(", ", state.Colors)}', brightness '{state.Brightness}%'.");
        }

        return state;
    }

    public Task<ProfileState> GetProfileStateAsync(
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(ReadProfileState());
    }

    public async Task<ProfileState> SetProfileAsync(
        string profile,
        CancellationToken cancellationToken)
    {
        var requested = ProfileIds.Keys.FirstOrDefault(
            name => string.Equals(name, profile, StringComparison.OrdinalIgnoreCase));
        if (requested is null)
        {
            throw new ArgumentException($"Unknown profile '{profile}'.", nameof(profile));
        }

        var supported = ReadSupportedProfiles();
        if (!supported.Contains(requested, StringComparer.OrdinalIgnoreCase))
        {
            throw new ArgumentException(
                $"The '{requested}' profile is not supported by this laptop.",
                nameof(profile));
        }

        var modeId = ProfileIds[requested];
        gaming.Set("SetGamingMiscSetting", FirmwareProtocol.EncodeProfile(modeId));
        await Task.Delay(SettleMilliseconds, cancellationToken);
        var state = ReadProfileState();
        if (state.ModeId != modeId)
        {
            throw new FirmwareOperationException(
                $"Requested '{requested}', but firmware reports '{state.Profile}'.");
        }

        return state;
    }

    public string GetNextProfile(ProfileState current)
    {
        var supported = ProfileOrder
            .Where(profile => current.SupportedProfiles.Contains(
                profile,
                StringComparer.OrdinalIgnoreCase))
            .ToArray();
        if (supported.Length == 0)
        {
            throw new FirmwareOperationException(
                "The firmware did not report any supported profiles.");
        }

        var currentIndex = Array.FindIndex(
            supported,
            profile => string.Equals(
                profile,
                current.Profile,
                StringComparison.OrdinalIgnoreCase));
        return supported[(currentIndex + 1) % supported.Length];
    }

    private async Task SetCustomFansAsync(
        byte cpuPercent,
        byte gpuPercent,
        CancellationToken cancellationToken)
    {
        try
        {
            for (var attempt = 0; attempt < 2; attempt++)
            {
                gaming.Set("SetGamingFanBehavior", CustomFanBehavior);
                gaming.Set(
                    "SetGamingFanSpeed",
                    FirmwareProtocol.EncodeFanTarget(0x01, cpuPercent));
                gaming.Set(
                    "SetGamingFanSpeed",
                    FirmwareProtocol.EncodeFanTarget(0x04, gpuPercent));
            }

            await Task.Delay(SettleMilliseconds, cancellationToken);
            var cpuReadback = ReadFanTarget(0x01);
            var gpuReadback = ReadFanTarget(0x04);
            if (cpuReadback != cpuPercent || gpuReadback != gpuPercent)
            {
                throw new FirmwareOperationException(
                    $"Fan target readback was CPU {cpuReadback}%, GPU {gpuReadback}%.");
            }
        }
        catch (Exception fanException) when (fanException is not OperationCanceledException)
        {
            try
            {
                gaming.Set("SetGamingFanBehavior", AutoFanBehavior);
            }
            catch (Exception restoreException)
            {
                throw new FirmwareOperationException(
                    $"{fanException.Message} Restoring automatic fan control also failed: " +
                    restoreException.Message,
                    fanException);
            }

            throw;
        }
    }

    private FanState ReadFanState(FanMode? mode)
    {
        return new FanState(
            mode,
            ReadFanTarget(0x01),
            ReadFanTarget(0x04),
            ReadSensor(0x0201, 0xFFFF),
            ReadSensor(0x0601, 0xFFFF),
            ReadSensor(0x0101, 0xFF),
            ReadSensor(0x0A01, 0xFF));
    }

    private byte ReadFanTarget(uint selector)
    {
        return FirmwareProtocol.DecodeByte(
            gaming.GetUInt64("GetGamingFanSpeed", selector));
    }

    private int? ReadSensor(uint selector, uint mask)
    {
        return FirmwareProtocol.DecodeSensor(
            gaming.GetUInt64("GetGamingSysInfo", selector),
            mask);
    }

    private KeyboardState ReadKeyboardState()
    {
        var data = gaming.GetBytes("GetGamingKBBacklight", 1);
        if (data.Length < 8)
        {
            throw new FirmwareOperationException(
                "GetGamingKBBacklight returned incomplete data.");
        }

        var mode = data[0] switch
        {
            0 => "Static",
            1 => "Breathing",
            2 => "Neon",
            3 => "Wave",
            4 => "Shifting",
            5 => "Zoom",
            6 => "Meteor",
            7 => "Twinkling",
            _ => $"Unknown ({data[0]})"
        };
        var colors = KeyboardZones
            .Select(zone => FirmwareProtocol.DecodeColor(
                gaming.GetUInt64("GetGamingRgbKb", zone)))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        return new KeyboardState(mode, colors, data[2]);
    }

    private ProfileState ReadProfileState()
    {
        var supported = ReadSupportedProfiles();
        var modeId = FirmwareProtocol.DecodeByte(
            gaming.GetUInt64("GetGamingMiscSetting", 0x0B));
        var name = ProfileNames.TryGetValue(modeId, out var profile)
            ? profile
            : $"Unknown ({modeId})";
        return new ProfileState(name, modeId, supported);
    }

    private IReadOnlyList<string> ReadSupportedProfiles()
    {
        var mask = FirmwareProtocol.DecodeByte(
            gaming.GetUInt64("GetGamingMiscSetting", 0x0A));
        return ProfileOrder
            .Where(profile => (mask & (1 << ProfileIds[profile])) != 0)
            .ToArray();
    }

    private static string NormalizeColor(string color)
    {
        var value = color.Trim().TrimStart('#');
        if (value.Length != 6 || !value.All(Uri.IsHexDigit))
        {
            throw new ArgumentException(
                $"'{color}' is not a six-digit RGB color.",
                nameof(color));
        }

        return $"#{value.ToUpperInvariant()}";
    }

    private static void ValidateFanUpdate(FanUpdate update)
    {
        if (update.Mode == FanMode.Custom &&
            (update.CpuPercent is null || update.GpuPercent is null))
        {
            throw new ArgumentException(
                "Custom fan mode requires cpuPercent and gpuPercent.",
                nameof(update));
        }
    }
}