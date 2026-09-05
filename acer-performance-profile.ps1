<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

$ErrorActionPreference = 'Stop'

function Show-Help {
    @'
Read or change the Acer NitroSense performance profile.

Usage:
  .\acer-performance-profile.ps1 --status
  .\acer-performance-profile.ps1 --next
  .\acer-performance-profile.ps1 Eco
  .\acer-performance-profile.ps1 Quiet
  .\acer-performance-profile.ps1 Balanced
  .\acer-performance-profile.ps1 Performance
  .\acer-performance-profile.ps1 Turbo
  .\acer-performance-profile.ps1 --help

Eco may require battery power, while Turbo may require AC power. Changing
profiles can also change fan behavior, power limits, and GPU overclocking
exactly as it does in NitroSense.
'@
}

$profileIds = @{
    Eco         = 6
    Quiet       = 0
    Balanced    = 1
    Performance = 4
    Turbo       = 5
}

$profileNames = @{
    0 = 'Quiet'
    1 = 'Balanced'
    4 = 'Performance'
    5 = 'Turbo'
    6 = 'Eco'
}

function Read-AcerResponse {
    param(
        [Parameter(Mandatory)]
        [System.Net.Sockets.NetworkStream]$Stream
    )

    $builder = [System.Text.StringBuilder]::new()
    $depth = 0
    $started = $false
    $inString = $false
    $escaped = $false

    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) {
            throw 'AcerAgentService closed the connection before replying.'
        }

        $character = [char]$value
        if (-not $started) {
            if ($character -ne '{') {
                continue
            }
            $started = $true
        }

        [void]$builder.Append($character)

        if ($inString) {
            if ($escaped) {
                $escaped = $false
            }
            elseif ($character -eq '\') {
                $escaped = $true
            }
            elseif ($character -eq '"') {
                $inString = $false
            }
        }
        elseif ($character -eq '"') {
            $inString = $true
        }
        elseif ($character -eq '{') {
            $depth++
        }
        elseif ($character -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $builder.ToString() | ConvertFrom-Json
            }
        }
    }
}

function Invoke-AcerRequest {
    param(
        [Parameter(Mandatory)]
        [uint32]$PacketId,

        [Parameter(Mandatory)]
        [hashtable]$Body
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 5000
        $client.Connect('127.0.0.1', 46933)
        $stream = $client.GetStream()

        $json = $Body | ConvertTo-Json -Compress -Depth 8
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $packet = [byte[]]::new(8 + $jsonBytes.Length)

        [Array]::Copy(
            [System.Text.Encoding]::ASCII.GetBytes('ACER'),
            0,
            $packet,
            0,
            4
        )
        [Array]::Copy(
            [BitConverter]::GetBytes($PacketId),
            0,
            $packet,
            4,
            4
        )
        [Array]::Copy($jsonBytes, 0, $packet, 8, $jsonBytes.Length)

        $stream.Write($packet, 0, $packet.Length)
        $response = Read-AcerResponse -Stream $stream
        if ([string]$response.result -ne '0') {
            throw "AcerAgentService rejected '$($response.request)' with result $($response.result)."
        }

        return $response.data
    }
    catch [System.Net.Sockets.SocketException] {
        throw 'Cannot connect to AcerAgentService on 127.0.0.1:46933. Ensure AASSvc is running.'
    }
    finally {
        $client.Dispose()
    }
}

function Get-SupportedProfileIds {
    @(Invoke-AcerRequest -PacketId 0 -Body @{
        Function = 'SUPPORT_OPERATING_MODE_CAPABILITY'
    })
}

function Get-CurrentProfile {
    $state = Invoke-AcerRequest -PacketId 20 -Body @{
        Function = 'OPERATING_MODE'
    }

    $mode = [int]$state.mode
    [pscustomobject]@{
        Profile = if ($profileNames.ContainsKey($mode)) {
            $profileNames[$mode]
        }
        else {
            "Unknown ($mode)"
        }
        ModeId = $mode
    }
}

$arguments = @($args)
if ($arguments.Count -ne 1) {
    Show-Help
    exit 2
}

if ($arguments[0] -in @('--help', '-help', '-h', '/?')) {
    Show-Help
    exit
}

if ($arguments[0] -eq '--status') {
    Get-CurrentProfile | Format-Table -AutoSize
    exit
}

if ($arguments[0] -eq '--next') {
    $supportedModes = Get-SupportedProfileIds
    $profileOrder = @('Eco', 'Quiet', 'Balanced', 'Performance', 'Turbo') |
        Where-Object { $profileIds[$_] -in $supportedModes }
    $currentProfile = Get-CurrentProfile
    $currentIndex = [Array]::IndexOf(
        [string[]]$profileOrder,
        [string]$currentProfile.Profile
    )
    $requestedProfile = $profileOrder[($currentIndex + 1) % $profileOrder.Count]
}
else {
    $requestedProfile = $profileIds.Keys |
        Where-Object { $_ -ieq $arguments[0] } |
        Select-Object -First 1
}

if (-not $requestedProfile) {
    Show-Help
    exit 2
}

$requestedMode = $profileIds[$requestedProfile]
if ($null -eq $supportedModes) {
    $supportedModes = Get-SupportedProfileIds
}
if ($requestedMode -notin $supportedModes) {
    throw "The '$requestedProfile' profile is not supported by this laptop."
}

Invoke-AcerRequest -PacketId 100 -Body @{
    Function  = 'OPERATING_MODE'
    Parameter = @{
        mode = $requestedMode
    }
} | Out-Null

Start-Sleep -Milliseconds 300
$currentProfile = Get-CurrentProfile
if ($currentProfile.ModeId -ne $requestedMode) {
    throw "Requested '$requestedProfile', but AcerAgentService reports '$($currentProfile.Profile)'."
}

$currentProfile | Format-Table -AutoSize
