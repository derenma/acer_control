namespace AcerControl.Service.Hosting;

public sealed class ServiceHealthState
{
    private readonly object sync = new();
    private string status = "starting";
    private string? message = "Waiting for the Acer firmware interface.";

    public string Status
    {
        get
        {
            lock (sync)
            {
                return status;
            }
        }
    }

    public string? Message
    {
        get
        {
            lock (sync)
            {
                return message;
            }
        }
    }

    public void MarkHealthy()
    {
        Set("healthy", null);
    }

    public void MarkDegraded(string value)
    {
        Set("degraded", value);
    }

    private void Set(string newStatus, string? newMessage)
    {
        lock (sync)
        {
            status = newStatus;
            message = newMessage;
        }
    }
}