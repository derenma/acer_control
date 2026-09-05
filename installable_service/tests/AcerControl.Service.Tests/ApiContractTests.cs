using System.Net;
using System.Net.Http.Headers;
using System.Text;
using AcerControl.Service.Api;
using AcerControl.Service.Hardware;
using AcerControl.Service.Models;
using AcerControl.Service.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace AcerControl.Service.Tests;

public sealed class ApiContractTests : IDisposable
{
    private const string Token = "test-token-with-at-least-thirty-two-characters";
    private readonly string tokenPath = Path.GetTempFileName();
    private readonly string? previousTokenPath;
    private readonly WebApplicationFactory<Program> factory;

    public ApiContractTests()
    {
        previousTokenPath = Environment.GetEnvironmentVariable(
            ApiTokenProvider.TokenEnvironmentVariable);
        File.WriteAllText(tokenPath, Token);
        Environment.SetEnvironmentVariable(
            ApiTokenProvider.TokenEnvironmentVariable,
            tokenPath);

        factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IHostedService>();
                services.RemoveAll<IAcerGamingInterface>();
                services.RemoveAll<IAcerHardwareController>();
                services.RemoveAll<ISettingsStore>();
                services.AddSingleton<IAcerHardwareController, FakeHardwareController>();
                services.AddSingleton<ISettingsStore, FakeSettingsStore>();
            });
        });
    }

    [Fact]
    public async Task HealthDoesNotRequireAuthentication()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/healthz");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ApiRequiresBearerToken()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/fan");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ApiRejectsBrowserOrigins()
    {
        using var client = CreateAuthenticatedClient();
        client.DefaultRequestHeaders.Add("Origin", "http://localhost");

        var response = await client.GetAsync("/api/v1/fan");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task FanUpdateAcceptsStringEnumAndPersistsState()
    {
        using var client = CreateAuthenticatedClient();
        using var content = new StringContent(
            """{"mode":"Custom","cpuPercent":60,"gpuPercent":70}""",
            Encoding.UTF8,
            "application/json");

        var response = await client.PutAsync("/api/v1/fan", content);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var settings = factory.Services.GetRequiredService<ISettingsStore>();
        var state = settings.LoadDesiredState();
        Assert.True(state.FanManaged);
        Assert.Equal(FanMode.Custom, state.FanMode);
        Assert.Equal<byte?>(60, state.FanCpuPercent);
        Assert.Equal<byte?>(70, state.FanGpuPercent);
    }

    public void Dispose()
    {
        factory.Dispose();
        Environment.SetEnvironmentVariable(
            ApiTokenProvider.TokenEnvironmentVariable,
            previousTokenPath);
        File.Delete(tokenPath);
    }

    private HttpClient CreateAuthenticatedClient()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", Token);
        return client;
    }

    private sealed class FakeSettingsStore : ISettingsStore
    {
        private DesiredState state = new();

        public ServiceConfiguration LoadConfiguration() => new();

        public DesiredState LoadDesiredState() => state;

        public void SaveDesiredState(DesiredState value)
        {
            state = value;
        }
    }

    private sealed class FakeHardwareController : IAcerHardwareController
    {
        public Task<FanState> GetFanStateAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(new FanState(null, 50, 50, 3000, 2500, 50, 45));
        }

        public Task<FanState> SetFanAsync(
            FanUpdate update,
            CancellationToken cancellationToken)
        {
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
            return Task.FromResult<ProfileState>(new(
                profile,
                1,
                ["Quiet", "Balanced", "Performance", "Turbo"]));
        }
    }
}