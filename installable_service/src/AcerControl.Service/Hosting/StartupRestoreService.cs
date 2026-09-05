using AcerControl.Service.Control;
using AcerControl.Service.Persistence;

namespace AcerControl.Service.Hosting;

public sealed class StartupRestoreService(
    AcerControlCoordinator coordinator,
    ISettingsStore settings,
    ServiceHealthState health,
    ILogger<StartupRestoreService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        const int attempts = 6;
        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            try
            {
                await coordinator.CaptureInitialStateAsync(stoppingToken);
                if (settings.LoadConfiguration().RestoreOnStartup)
                {
                    await coordinator.RestoreAsync(stoppingToken);
                }

                await coordinator.GetProfileAsync(stoppingToken);
                health.MarkHealthy();
                logger.LogInformation("Acer Control startup initialization completed.");
                return;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogWarning(
                    exception,
                    "Acer firmware initialization attempt {Attempt} of {Attempts} failed.",
                    attempt,
                    attempts);
                if (attempt < attempts)
                {
                    await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                }
                else
                {
                    health.MarkDegraded(exception.Message);
                }
            }
        }
    }
}