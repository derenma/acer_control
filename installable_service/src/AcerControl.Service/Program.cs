using System.Net;
using System.Text.Json.Serialization;
using AcerControl.Service.Api;
using AcerControl.Service.Control;
using AcerControl.Service.Hardware;
using AcerControl.Service.Hosting;
using AcerControl.Service.Persistence;
using Microsoft.AspNetCore.Server.Kestrel.Core;

var configurationStore = new RegistrySettingsStore();
var serviceConfiguration = configurationStore.LoadConfiguration();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseWindowsService(options =>
{
    options.ServiceName = "AcerControlService";
});
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 16 * 1024;
    options.Listen(IPAddress.Loopback, serviceConfiguration.ApiPort, listenOptions =>
    {
        listenOptions.Protocols = HttpProtocols.Http1;
    });
});
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
builder.Services.AddSingleton<ISettingsStore>(configurationStore);
builder.Services.AddSingleton<IAcerGamingInterface, WmiAcerGamingInterface>();
builder.Services.AddSingleton<IAcerHardwareController, AcerHardwareController>();
builder.Services.AddSingleton<AcerControlCoordinator>();
builder.Services.AddSingleton<ApiTokenProvider>();
builder.Services.AddSingleton<ServiceHealthState>();
builder.Services.AddHostedService<StartupRestoreService>();
builder.Services.AddHostedService<PowerResumeMonitor>();

var app = builder.Build();
app.UseMiddleware<ApiExceptionMiddleware>();
app.UseMiddleware<BearerTokenMiddleware>();
app.MapAcerControlApi();
app.Run();

public partial class Program;
