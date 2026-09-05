using AcerControl.Service.Models;

namespace AcerControl.Service.Hardware;

public static class FirmwareProtocol
{
    public static byte DecodeByte(ulong value)
    {
        EnsureSuccess(value);
        return (byte)((value >> 8) & 0xFF);
    }

    public static int? DecodeSensor(ulong value, uint mask)
    {
        return (value & 0xFF) == 0
            ? (int)((value >> 8) & mask)
            : null;
    }

    public static ulong EncodeFanTarget(byte selector, byte percentage)
    {
        return selector | ((ulong)percentage << 8);
    }

    public static ulong EncodeProfile(byte modeId)
    {
        return 0x0B | ((ulong)modeId << 8);
    }

    public static ulong EncodeColor(byte zone, byte red, byte green, byte blue)
    {
        return zone |
            ((ulong)red << 8) |
            ((ulong)green << 16) |
            ((ulong)blue << 24);
    }

    public static string DecodeColor(ulong value)
    {
        EnsureSuccess(value);
        return $"#{(value >> 8) & 0xFF:X2}{(value >> 16) & 0xFF:X2}{(value >> 24) & 0xFF:X2}";
    }

    public static byte[] CreateStaticKeyboardPayload(
        byte brightness,
        byte red,
        byte green,
        byte blue)
    {
        return
        [
            0, 0, brightness, 0, 0, red, green, blue,
            0, 1, 0, 0, 0, 0, 0, 0
        ];
    }

    public static void EnsureSuccess(ulong value, string operation = "Firmware")
    {
        var status = (byte)(value & 0xFF);
        if (status != 0)
        {
            throw new FirmwareOperationException(
                $"{operation} returned status 0x{status:X2}.");
        }
    }
}