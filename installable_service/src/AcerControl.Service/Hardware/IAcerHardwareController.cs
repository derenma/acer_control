using AcerControl.Service.Models;

namespace AcerControl.Service.Hardware;

public interface IAcerHardwareController
{
    Task<FanState> GetFanStateAsync(CancellationToken cancellationToken);

    Task<FanState> SetFanAsync(FanUpdate update, CancellationToken cancellationToken);

    Task<KeyboardState> GetKeyboardStateAsync(CancellationToken cancellationToken);

    Task<KeyboardState> SetKeyboardAsync(
        KeyboardUpdate update,
        CancellationToken cancellationToken);

    Task<ProfileState> GetProfileStateAsync(CancellationToken cancellationToken);

    Task<ProfileState> SetProfileAsync(
        string profile,
        CancellationToken cancellationToken);
}