using AcerControl.Service.Control;
using AcerControl.Service.Hardware;
using AcerControl.Service.Models;
using AcerControl.Service.Persistence;
using Microsoft.Extensions.Logging.Abstractions;

namespace AcerControl.Service.Tests;

public sealed class AcerControlCoordinatorTests
{
    [Fact]
    public async Task RestoreAppliesProfileThenFanThenKeyboard()
    {
        var hardware = new FakeHardwareController();
        var settings = new FakeSettingsStore
        {
            State = new DesiredState(
                ProfileManaged: true,
                Profile: "Performance",
                FanManaged: true,
                FanMode: FanMode.Custom,
                FanCpuPercent: 60,
                FanGpuPercent: 70,
                KeyboardManaged: true,
                KeyboardColor: "#112233",
                KeyboardBrightness: 50)
        };
        var coordinator = CreateCoordinator(hardware, settings);

        await coordinator.RestoreAsync(CancellationToken.None);

        Assert.Equal(["profile:Performance", "fan:Custom", "keyboard:#112233"], hardware.Calls);
    }

    [Fact]
    public async Task ProfileChangeReappliesManagedFansBeforeSaving()
    {
        var hardware = new FakeHardwareController();
        var settings = new FakeSettingsStore
        {
            State = new DesiredState(
                FanManaged: true,
                FanMode: FanMode.Custom,
                FanCpuPercent: 55,
                FanGpuPercent: 65)
        };
        var coordinator = CreateCoordinator(hardware, settings);

        await coordinator.SetProfileAsync("Turbo", CancellationToken.None);

        Assert.Equal(["profile:Turbo", "fan:Custom"], hardware.Calls);
        Assert.True(settings.State.ProfileManaged);
        Assert.Equal("Turbo", settings.State.Profile);
    }

    [Fact]
    public async Task RestoreAttemptsRemainingSettingsThenReportsFailures()
    {
        var hardware = new FakeHardwareController { FailFan = true };
        var settings = new FakeSettingsStore
        {
            State = new DesiredState(
                ProfileManaged: true,
                Profile: "Performance",
                FanManaged: true,
                FanMode: FanMode.Auto,
                KeyboardManaged: true,
                KeyboardColor: "#112233",
                KeyboardBrightness: 50)
        };
        var coordinator = CreateCoordinator(hardware, settings);

        var exception = await Assert.ThrowsAsync<FirmwareOperationException>(() =>
            coordinator.RestoreAsync(CancellationToken.None));

        Assert.Contains("fan", exception.Message);
        Assert.Equal(["profile:Performance", "fan:Auto", "keyboard:#112233"], hardware.Calls);
    }

    [Fact]
    public async Task PersistenceFailureReportsThatHardwareWasApplied()
    {
        var hardware = new FakeHardwareController();
        var settings = new FakeSettingsStore { ThrowOnSave = true };
        var coordinator = CreateCoordinator(hardware, settings);

        var exception = await Assert.ThrowsAsync<SettingsPersistenceException>(() =>
            coordinator.SetFanAsync(
                new FanUpdate(FanMode.Auto, null, null),
                CancellationToken.None));

        Assert.True(exception.Applied);
        Assert.False(exception.Persisted);
        Assert.Equal(["fan:Auto"], hardware.Calls);
    }

    private static AcerControlCoordinator CreateCoordinator(
        IAcerHardwareController hardware,
        ISettingsStore settings)
    {
        return new AcerControlCoordinator(
            hardware,
            settings,
            NullLogger<AcerControlCoordinator>.Instance);
    }

    private sealed class FakeSettingsStore : ISettingsStore
    {
        public DesiredState State { get; set; } = new();

        public bool ThrowOnSave { get; init; }

        public ServiceConfiguration LoadConfiguration() => new();

        public DesiredState LoadDesiredState() => State;

        public void SaveDesiredState(DesiredState state)
        {
            if (ThrowOnSave)
            {
                throw new IOException("Registry unavailable.");
            }

            State = state;
        }
    }

    private sealed class FakeHardwareController : IAcerHardwareController
    {
        public List<string> Calls { get; } = [];

        public bool FailFan { get; init; }

        public Task<FanState> GetFanStateAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(new FanState(null, 50, 50, 3000, 2500, 50, 45));
        }

        public Task<FanState> SetFanAsync(
            FanUpdate update,
            CancellationToken cancellationToken)
        {
            Calls.Add($"fan:{update.Mode}");
            if (FailFan)
            {
                throw new FirmwareOperationException("Fan write failed.");
            }

            return Task.FromResult(new FanState(
                update.Mode,
                update.CpuPercent ?? 50,
                update.GpuPercent ?? 50,
                3000,
                2500,
                50,
                45));
        }

        public Task<KeyboardState> GetKeyboardStateAsync(
            CancellationToken cancellationToken)
        {
            return Task.FromResult<KeyboardState>(new("Static", ["#112233"], 50));
        }

        public Task<KeyboardState> SetKeyboardAsync(
            KeyboardUpdate update,
            CancellationToken cancellationToken)
        {
            Calls.Add($"keyboard:{update.Color}");
            return Task.FromResult<KeyboardState>(new("Static", [update.Color], update.Brightness));
        }

        public Task<ProfileState> GetProfileStateAsync(
            CancellationToken cancellationToken)
        {
            return Task.FromResult<ProfileState>(new(
                "Balanced",
                1,
                ["Quiet", "Balanced", "Performance", "Turbo"]));
        }

        public Task<ProfileState> SetProfileAsync(
            string profile,
            CancellationToken cancellationToken)
        {
            Calls.Add($"profile:{profile}");
            return Task.FromResult<ProfileState>(new(
                profile,
                profile == "Turbo" ? (byte)5 : (byte)4,
                ["Quiet", "Balanced", "Performance", "Turbo"]));
        }
    }
}