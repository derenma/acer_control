using AcerControl.Service.Models;

namespace AcerControl.Service.Persistence;

public interface ISettingsStore
{
    ServiceConfiguration LoadConfiguration();

    DesiredState LoadDesiredState();

    void SaveDesiredState(DesiredState state);
}