using System.Management;
using AcerControl.Service.Models;

namespace AcerControl.Service.Hardware;

public sealed class WmiAcerGamingInterface : IAcerGamingInterface
{
    private ManagementObject? gamingInterface;

    public ulong GetUInt64(string method, uint inputValue)
    {
        using var output = Invoke(method, inputValue);
        var value = output["gmOutput"] ?? throw new FirmwareOperationException(
            $"{method} did not return data.");
        return Convert.ToUInt64(value);
    }

    public byte[] GetBytes(string method, uint inputValue)
    {
        using var output = Invoke(method, inputValue);
        var returnValue = output["gmReturn"] ?? throw new FirmwareOperationException(
            $"{method} did not return a status.");
        var status = Convert.ToByte(returnValue);
        if (status != 0)
        {
            throw new FirmwareOperationException(
                $"{method} returned status 0x{status:X2}.");
        }

        return output["gmOutput"] as byte[] ?? throw new FirmwareOperationException(
            $"{method} did not return byte data.");
    }

    public void Set(string method, object inputValue)
    {
        using var output = Invoke(method, inputValue);
        var value = output["gmOutput"] ?? throw new FirmwareOperationException(
            $"{method} did not return a status.");
        FirmwareProtocol.EnsureSuccess(Convert.ToUInt64(value), method);
    }

    public void Dispose()
    {
        gamingInterface?.Dispose();
        gamingInterface = null;
    }

    private ManagementBaseObject Invoke(string method, object inputValue)
    {
        var gaming = GetGamingInterface();
        using var input = gaming.GetMethodParameters(method) ??
            throw new FirmwareOperationException(
                $"The firmware does not expose {method}.");
        var inputProperties = input.Properties.Cast<PropertyData>().ToArray();
        if (inputProperties.Length != 1)
        {
            throw new FirmwareOperationException(
                $"{method} has {inputProperties.Length} input parameters; expected one.");
        }

        input[inputProperties[0].Name] = inputValue;
        try
        {
            return gaming.InvokeMethod(method, input, null) ??
                throw new FirmwareOperationException($"{method} returned no response.");
        }
        catch (ManagementException exception)
        {
            throw new FirmwareOperationException(
                $"Calling {method} through AcerGamingFunction failed.", exception);
        }
    }

    private ManagementObject GetGamingInterface()
    {
        if (gamingInterface is not null)
        {
            return gamingInterface;
        }

        try
        {
            var scope = new ManagementScope(@"\\.\root\wmi");
            scope.Connect();
            using var searcher = new ManagementObjectSearcher(
                scope,
                new ObjectQuery("SELECT * FROM AcerGamingFunction"));
            using var instances = searcher.Get();
            gamingInterface = instances.Cast<ManagementObject>().FirstOrDefault() ??
                throw new FirmwareUnavailableException(
                    "The AcerGamingFunction firmware interface was not found.");
            return gamingInterface;
        }
        catch (ManagementException exception)
        {
            throw new FirmwareUnavailableException(
                "The AcerGamingFunction firmware interface is unavailable.", exception);
        }
    }
}