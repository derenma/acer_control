<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

$ErrorActionPreference = 'Stop'

function Show-Help {
    @'
Set the custom CPU and GPU fan speeds on a supported Acer laptop.

Usage:
  .\acer-fan-control.ps1 <CPU_PERCENT> <GPU_PERCENT>
  .\acer-fan-control.ps1 --help

Arguments:
  CPU_PERCENT  CPU fan speed from 0 through 100.
  GPU_PERCENT  GPU fan speed from 0 through 100.

Examples:
  .\acer-fan-control.ps1 60 60
  .\acer-fan-control.ps1 75 65

No fan settings are changed when arguments are missing or invalid.
'@
}

function ConvertTo-FanSpeed {
    param([string]$Value)

    $speed = 0
    if (-not [int]::TryParse($Value, [ref]$speed) -or $speed -lt 0 -or $speed -gt 100) {
        return $null
    }

    return $speed
}

$cliArguments = @($args)
if ($cliArguments.Count -eq 1 -and $cliArguments[0] -in @('--help', '-help', '-h', '/?')) {
    Show-Help
    return
}

if ($cliArguments.Count -ne 2) {
    Show-Help
    return
}

$cpuSpeed = ConvertTo-FanSpeed -Value $cliArguments[0]
$gpuSpeed = ConvertTo-FanSpeed -Value $cliArguments[1]
if ($null -eq $cpuSpeed -or $null -eq $gpuSpeed) {
    Show-Help
    return
}

function Read-AcerResponse {
    param([System.Net.Sockets.NetworkStream]$Stream)

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
        $header = [System.Text.Encoding]::ASCII.GetBytes('ACER')
        $packet = [byte[]]::new(8 + [System.Text.Encoding]::UTF8.GetByteCount($json))
        [Array]::Copy($header, 0, $packet, 0, 4)
        [Array]::Copy([BitConverter]::GetBytes($PacketId), 0, $packet, 4, 4)
        [System.Text.Encoding]::UTF8.GetBytes($json, 0, $json.Length, $packet, 8) | Out-Null

        $stream.Write($packet, 0, $packet.Length)
        $response = Read-AcerResponse -Stream $stream
        if ([string]$response.result -ne '0') {
            throw "AcerAgentService rejected '$($response.request)' with result $($response.result)."
        }
        return $response.data
    }
    catch [System.Net.Sockets.SocketException] {
        throw 'Cannot connect to AcerAgentService. Keep the Acer system driver/service installed and running.'
    }
    finally {
        $client.Dispose()
    }
}

function Get-FanState {
    Invoke-AcerRequest -PacketId 20 -Body @{ Function = 'FAN_CONTROL' }
}

function Show-FanState {
    $state = Get-FanState
    $modeName = @('Auto', 'Max', 'Custom')[[int]$state.mode]

    [pscustomobject]@{
        Mode       = $modeName
        CPUPercent = ($state.custom_fan_data | Where-Object fan_name -eq 'CPU').fan_custom_speed
        GPUPercent = ($state.custom_fan_data | Where-Object fan_name -eq 'GPU').fan_custom_speed
    } | Format-Table -AutoSize
}

$state = Get-FanState
$state.mode = 2
foreach ($fan in $state.custom_fan_data) {
    $fan.fan_custom_auto = 0
    if ($fan.fan_name -eq 'CPU') {
        $fan.fan_custom_speed = $cpuSpeed
    }
    elseif ($fan.fan_name -eq 'GPU') {
        $fan.fan_custom_speed = $gpuSpeed
    }
}

Invoke-AcerRequest -PacketId 100 -Body @{
    Function  = 'FAN_CONTROL'
    Parameter = $state
} | Out-Null

Start-Sleep -Milliseconds 300
Show-FanState
