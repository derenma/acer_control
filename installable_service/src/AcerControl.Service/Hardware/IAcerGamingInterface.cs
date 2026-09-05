namespace AcerControl.Service.Hardware;

public interface IAcerGamingInterface : IDisposable
{
    ulong GetUInt64(string method, uint inputValue);

    byte[] GetBytes(string method, uint inputValue);

    void Set(string method, object inputValue);
}