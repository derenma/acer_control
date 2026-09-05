using AcerControl.Service.Hardware;
using AcerControl.Service.Models;

namespace AcerControl.Service.Tests;

public sealed class FirmwareProtocolTests
{
    [Fact]
    public void EncodesFirmwarePayloads()
    {
        Assert.Equal(0x3C01UL, FirmwareProtocol.EncodeFanTarget(0x01, 60));
        Assert.Equal(0x040BUL, FirmwareProtocol.EncodeProfile(4));
        Assert.Equal(
            0x0033221101UL,
            FirmwareProtocol.EncodeColor(0x01, 0x11, 0x22, 0x33));
        Assert.Equal(
            [0, 0, 50, 0, 0, 0x11, 0x22, 0x33, 0, 1, 0, 0, 0, 0, 0, 0],
            FirmwareProtocol.CreateStaticKeyboardPayload(50, 0x11, 0x22, 0x33));
    }

    [Fact]
    public void RejectsFailedFirmwareStatus()
    {
        var exception = Assert.Throws<FirmwareOperationException>(
            () => FirmwareProtocol.DecodeByte(0x12FF));

        Assert.Contains("0xFF", exception.Message);
    }

    [Fact]
    public async Task CustomFansUseTwoWritePasses()
    {
        using var gaming = new FakeGamingInterface
        {
            GetUInt64Handler = (method, input) => method switch
            {
                "GetGamingFanSpeed" when input == 0x01 => 50UL << 8,
                "GetGamingFanSpeed" when input == 0x04 => 60UL << 8,
                "GetGamingSysInfo" => 0,
                _ => throw new InvalidOperationException()
            }
        };
        var controller = new AcerHardwareController(gaming);

        var state = await controller.SetFanAsync(
            new FanUpdate(FanMode.Custom, 50, 60),
            CancellationToken.None);

        Assert.Equal(FanMode.Custom, state.Mode);
        Assert.Equal(50, state.CpuPercent);
        Assert.Equal(60, state.GpuPercent);
        Assert.Equal(
            [
                ("SetGamingFanBehavior", 0x00C30009UL),
                ("SetGamingFanSpeed", 0x3201UL),
                ("SetGamingFanSpeed", 0x3C04UL),
                ("SetGamingFanBehavior", 0x00C30009UL),
                ("SetGamingFanSpeed", 0x3201UL),
                ("SetGamingFanSpeed", 0x3C04UL)
            ],
            gaming.SetCalls.Select(call => (call.Method, Convert.ToUInt64(call.Value))));
    }

    [Fact]
    public async Task CustomFanReadbackFailureRestoresAutoMode()
    {
        using var gaming = new FakeGamingInterface
        {
            GetUInt64Handler = (method, input) => method == "GetGamingFanSpeed"
                ? (input == 0x01 ? 49UL : 60UL) << 8
                : 0
        };
        var controller = new AcerHardwareController(gaming);

        await Assert.ThrowsAsync<FirmwareOperationException>(() =>
            controller.SetFanAsync(
                new FanUpdate(FanMode.Custom, 50, 60),
                CancellationToken.None));

        var finalCall = Assert.Single(gaming.SetCalls.TakeLast(1));
        Assert.Equal("SetGamingFanBehavior", finalCall.Method);
        Assert.Equal(0x00410009UL, finalCall.Value);
    }

    private sealed class FakeGamingInterface : IAcerGamingInterface
    {
        public Func<string, uint, ulong> GetUInt64Handler { get; init; } =
            (_, _) => 0;

        public List<(string Method, object Value)> SetCalls { get; } = [];

        public ulong GetUInt64(string method, uint inputValue)
        {
            return GetUInt64Handler(method, inputValue);
        }

        public byte[] GetBytes(string method, uint inputValue)
        {
            return [0, 0, 50, 0, 0, 0, 0, 0];
        }

        public void Set(string method, object inputValue)
        {
            SetCalls.Add((method, inputValue));
        }

        public void Dispose()
        {
        }
    }
}