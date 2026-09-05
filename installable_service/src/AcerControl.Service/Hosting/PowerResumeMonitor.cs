using System.Management;
using AcerControl.Service.Control;
using AcerControl.Service.Persistence;

namespace AcerControl.Service.Hosting;

public sealed class PowerResumeMonitor(
    AcerControlCoordinator coordinator,
    ISettingsStore settings,
    ServiceHealthState health,
    ILogger<PowerResumeMonitor> logger) : BackgroundService
{
    private readonly SemaphoreSlim resumeSignal = new(0, 1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var watcher = new ManagementEventWatcher(new WqlEventQuery(
            "SELECT * FROM Win32_PowerManagementEvent WHERE EventType = 7 OR EventType = 18"));
        watcher.EventArrived += OnResume;
        var watcherStarted = false;

        try
        {
            watcher.Start();
            watcherStarted = true;
            while (!stoppingToken.IsCancellationRequested)
            {
                await resumeSignal.WaitAsync(stoppingToken);
                await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
                while (resumeSignal.CurrentCount > 0)
                {
                    await resumeSignal.WaitAsync(stoppingToken);
                }

                if (!settings.LoadConfiguration().RestoreOnResume)
                {
                    continue;
                }

                try
                {
                    await coordinator.RestoreAsync(stoppingToken);
                    health.MarkHealthy();
                    logger.LogInformation("Managed Acer settings were restored after resume.");
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    health.MarkDegraded(exception.Message);
                    logger.LogError(exception, "Restore after resume failed.");
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            health.MarkDegraded(exception.Message);
            logger.LogError(exception, "Power resume monitoring stopped unexpectedly.");
        }
        finally
        {
            watcher.EventArrived -= OnResume;
            if (watcherStarted)
            {
                try
                {
                    watcher.Stop();
                }
                catch (ManagementException exception)
                {
                    logger.LogWarning(exception, "Could not stop the power resume watcher cleanly.");
                }
            }
        }
    }

    private void OnResume(object sender, EventArrivedEventArgs eventArgs)
    {
        if (resumeSignal.CurrentCount == 0)
        {
            resumeSignal.Release();
        }
    }
}