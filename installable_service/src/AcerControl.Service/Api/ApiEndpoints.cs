using AcerControl.Service.Control;
using AcerControl.Service.Hosting;
using AcerControl.Service.Models;

namespace AcerControl.Service.Api;

public static class ApiEndpoints
{
    public static void MapAcerControlApi(this WebApplication app)
    {
        app.MapGet("/healthz", (ServiceHealthState health) =>
            Results.Json(new HealthResponse(health.Status, health.Message)));

        var api = app.MapGroup("/api/v1");
        api.MapGet("/status", (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.GetStatusAsync(cancellationToken));
        api.MapGet("/fan", (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.GetFanAsync(cancellationToken));
        api.MapPut("/fan", (
            FanUpdate update,
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.SetFanAsync(update, cancellationToken));
        api.MapGet("/keyboard", (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.GetKeyboardAsync(cancellationToken));
        api.MapPut("/keyboard", (
            KeyboardUpdate update,
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.SetKeyboardAsync(update, cancellationToken));
        api.MapGet("/profile", (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.GetProfileAsync(cancellationToken));
        api.MapPut("/profile", (
            ProfileUpdate update,
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.SetProfileAsync(update.Profile, cancellationToken));
        api.MapPost("/profile/next", (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
            coordinator.SetNextProfileAsync(cancellationToken));
        api.MapPost("/settings/apply", async (
            AcerControlCoordinator coordinator,
            CancellationToken cancellationToken) =>
        {
            await coordinator.RestoreAsync(cancellationToken);
            return Results.NoContent();
        });
    }
}