using System.Security.Cryptography;
using System.Text;

namespace AcerControl.Service.Api;

public sealed class ApiTokenProvider
{
    public const string TokenEnvironmentVariable = "ACER_CONTROL_TOKEN_FILE";
    private readonly Lazy<byte[]> tokenHash;

    public ApiTokenProvider()
    {
        tokenHash = new Lazy<byte[]>(LoadTokenHash, true);
    }

    public bool IsValid(string candidate)
    {
        var candidateHash = SHA256.HashData(Encoding.UTF8.GetBytes(candidate));
        return CryptographicOperations.FixedTimeEquals(tokenHash.Value, candidateHash);
    }

    public static string GetTokenPath()
    {
        var overridePath = Environment.GetEnvironmentVariable(TokenEnvironmentVariable);
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            return overridePath;
        }

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AcerControl",
            "api-token");
    }

    private static byte[] LoadTokenHash()
    {
        var path = GetTokenPath();
        if (!File.Exists(path))
        {
            throw new FileNotFoundException(
                $"The Acer Control API token was not found at '{path}'.",
                path);
        }

        var token = File.ReadAllText(path).Trim();
        if (token.Length < 32)
        {
            throw new InvalidDataException("The Acer Control API token is invalid.");
        }

        return SHA256.HashData(Encoding.UTF8.GetBytes(token));
    }
}