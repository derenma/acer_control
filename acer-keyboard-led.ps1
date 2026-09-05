<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

$ErrorActionPreference = 'Stop'

function Show-Help {
    @'
Set the Acer Nitro keyboard backlight to a static color and brightness.

Usage:
  .\acer-keyboard-led.ps1 --color "<RRGGBB>" --brightness <0-100>
  .\acer-keyboard-led.ps1 --status
  .\acer-keyboard-led.ps1 --help

Arguments:
  --color       Six-digit RGB hex color, with or without a leading #.
  --brightness  Keyboard brightness from 0 through 100.
  --status      Show the active mode, color, and brightness without changing them.

Examples:
  .\acer-keyboard-led.ps1 --color "FF0000" --brightness 100
  .\acer-keyboard-led.ps1 --brightness 50 --color "#0066FF"
  .\acer-keyboard-led.ps1 --status

No lighting settings are changed when arguments are missing or invalid.
The Acer Lighting Service and its bundled OpenRGB server must be running.
'@
}

function Get-CommandOptions {
    param([string[]]$Arguments)

    if ($Arguments.Count -eq 1 -and $Arguments[0] -in @('--help', '-help', '-h', '/?')) {
        return $null
    }

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq '--status') {
        return @{ Action = 'Status' }
    }

    if ($Arguments.Count -ne 4) {
        return $null
    }

    $values = @{}
    for ($index = 0; $index -lt $Arguments.Count; $index += 2) {
        $name = $Arguments[$index].ToLowerInvariant()
        if ($name -notin @('--color', '--brightness') -or $values.ContainsKey($name)) {
            return $null
        }

        $values[$name] = $Arguments[$index + 1]
    }

    if (-not $values.ContainsKey('--color') -or -not $values.ContainsKey('--brightness')) {
        return $null
    }

    $colorText = $values['--color'].Trim().TrimStart('#')
    if ($colorText -notmatch '^[0-9A-Fa-f]{6}$') {
        return $null
    }

    $brightness = 0
    if (
        -not [int]::TryParse($values['--brightness'], [ref]$brightness) -or
        $brightness -lt 0 -or
        $brightness -gt 100
    ) {
        return $null
    }

    return @{
        Action     = 'Set'
        Red        = [Convert]::ToByte($colorText.Substring(0, 2), 16)
        Green      = [Convert]::ToByte($colorText.Substring(2, 2), 16)
        Blue       = [Convert]::ToByte($colorText.Substring(4, 2), 16)
        HexColor   = $colorText.ToUpperInvariant()
        Brightness = $brightness
    }
}

function Read-ControllerUInt16 {
    param([hashtable]$Reader)

    $value = [BitConverter]::ToUInt16($Reader.Data, $Reader.Offset)
    $Reader.Offset += 2
    return $value
}

function Read-ControllerUInt32 {
    param([hashtable]$Reader)

    $value = [BitConverter]::ToUInt32($Reader.Data, $Reader.Offset)
    $Reader.Offset += 4
    return $value
}

function Read-ControllerInt32 {
    param([hashtable]$Reader)

    $value = [BitConverter]::ToInt32($Reader.Data, $Reader.Offset)
    $Reader.Offset += 4
    return $value
}

function Read-ControllerString {
    param([hashtable]$Reader)

    $length = Read-ControllerUInt16 -Reader $Reader
    if ($length -lt 1 -or $Reader.Offset + $length -gt $Reader.Data.Length) {
        throw 'OpenRGB returned malformed controller text.'
    }

    $value = [System.Text.Encoding]::ASCII.GetString($Reader.Data, $Reader.Offset, $length - 1)
    $Reader.Offset += $length
    return $value
}

function Get-OpenRgbKeyboardState {
    param([byte[]]$Payload)

    $reader = @{ Data = $Payload; Offset = 0 }
    [void](Read-ControllerUInt32 -Reader $reader)
    [void](Read-ControllerInt32 -Reader $reader)
    [void](Read-ControllerString -Reader $reader)

    for ($metadataIndex = 0; $metadataIndex -lt 5; $metadataIndex++) {
        [void](Read-ControllerString -Reader $reader)
    }

    $modeCount = Read-ControllerUInt16 -Reader $reader
    $activeModeIndex = Read-ControllerInt32 -Reader $reader
    $modes = @()

    for ($modeIndex = 0; $modeIndex -lt $modeCount; $modeIndex++) {
        $name = Read-ControllerString -Reader $reader
        [void](Read-ControllerInt32 -Reader $reader)
        $flags = Read-ControllerUInt32 -Reader $reader
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)
        $brightness = Read-ControllerUInt32 -Reader $reader
        [void](Read-ControllerUInt32 -Reader $reader)
        [void](Read-ControllerUInt32 -Reader $reader)

        $colorCount = Read-ControllerUInt16 -Reader $reader
        $colors = @()
        for ($colorIndex = 0; $colorIndex -lt $colorCount; $colorIndex++) {
            $red = $reader.Data[$reader.Offset]
            $green = $reader.Data[$reader.Offset + 1]
            $blue = $reader.Data[$reader.Offset + 2]
            $reader.Offset += 4
            $colors += '#{0:X2}{1:X2}{2:X2}' -f $red, $green, $blue
        }

        $modes += @{
            Name       = $name
            Brightness = if (($flags -band 16) -ne 0) { $brightness } else { $null }
            Colors     = @($colors | Select-Object -Unique)
        }
    }

    if ($activeModeIndex -lt 0 -or $activeModeIndex -ge $modes.Count) {
        throw "OpenRGB returned invalid active mode index $activeModeIndex."
    }

    $activeMode = $modes[$activeModeIndex]
    return @{
        Mode       = $activeMode.Name
        Color      = if ($activeMode.Colors.Count -gt 0) {
            $activeMode.Colors -join ', '
        }
        else {
            'N/A for this effect'
        }
        Brightness = if ($null -ne $activeMode.Brightness) {
            "$($activeMode.Brightness)%"
        }
        else {
            'N/A'
        }
    }
}

function Read-ExactBytes {
    param(
        [Parameter(Mandatory)]
        [System.Net.Sockets.NetworkStream]$Stream,

        [Parameter(Mandatory)]
        [int]$Count
    )

    $buffer = [byte[]]::new($Count)
    $offset = 0
    while ($offset -lt $Count) {
        $read = $Stream.Read($buffer, $offset, $Count - $offset)
        if ($read -eq 0) {
            throw 'The OpenRGB server closed the connection unexpectedly.'
        }

        $offset += $read
    }

    return $buffer
}

function Send-OpenRgbPacket {
    param(
        [Parameter(Mandatory)]
        [System.Net.Sockets.NetworkStream]$Stream,

        [Parameter(Mandatory)]
        [uint32]$DeviceId,

        [Parameter(Mandatory)]
        [uint32]$PacketType,

        [byte[]]$Payload = [byte[]]::new(0)
    )

    $header = [byte[]]::new(16)
    [Array]::Copy([System.Text.Encoding]::ASCII.GetBytes('ORGB'), 0, $header, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes($DeviceId), 0, $header, 4, 4)
    [Array]::Copy([BitConverter]::GetBytes($PacketType), 0, $header, 8, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]$Payload.Length), 0, $header, 12, 4)

    $Stream.Write($header, 0, $header.Length)
    if ($Payload.Length -gt 0) {
        $Stream.Write($Payload, 0, $Payload.Length)
    }
}

function Receive-OpenRgbPacket {
    param(
        [Parameter(Mandatory)]
        [System.Net.Sockets.NetworkStream]$Stream
    )

    $header = Read-ExactBytes -Stream $Stream -Count 16
    if ([System.Text.Encoding]::ASCII.GetString($header, 0, 4) -ne 'ORGB') {
        throw 'Received an invalid response from the OpenRGB server.'
    }

    $payloadLength = [BitConverter]::ToUInt32($header, 12)
    return @{
        DeviceId   = [BitConverter]::ToUInt32($header, 4)
        PacketType = [BitConverter]::ToUInt32($header, 8)
        Payload    = if ($payloadLength -gt 0) {
            Read-ExactBytes -Stream $Stream -Count $payloadLength
        }
        else {
            [byte[]]::new(0)
        }
    }
}

function Get-OpenRgbControllerIdentity {
    param([byte[]]$Payload)

    if ($Payload.Length -lt 11) {
        throw 'OpenRGB returned incomplete controller data.'
    }

    $deviceType = [BitConverter]::ToInt32($Payload, 4)
    $nameLength = [BitConverter]::ToUInt16($Payload, 8)
    if ($nameLength -lt 1 -or 10 + $nameLength -gt $Payload.Length) {
        throw 'OpenRGB returned malformed controller data.'
    }

    return @{
        Type = $deviceType
        Name = [System.Text.Encoding]::ASCII.GetString($Payload, 10, $nameLength - 1)
    }
}

function Write-OpenRgbString {
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryWriter]$Writer,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Value)
    $Writer.Write([uint16]($bytes.Length + 1))
    $Writer.Write($bytes)
    $Writer.Write([byte]0)
}

function New-StaticModePayload {
    param(
        [Parameter(Mandatory)]
        [byte]$Red,

        [Parameter(Mandatory)]
        [byte]$Green,

        [Parameter(Mandatory)]
        [byte]$Blue,

        [Parameter(Mandatory)]
        [uint32]$Brightness
    )

    $bodyStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($bodyStream)
    try {
        $writer.Write([int32]1)
        Write-OpenRgbString -Writer $writer -Value 'STATIC'
        $writer.Write([int32]0)
        $writer.Write([uint32]81)
        $writer.Write([uint32]1)
        $writer.Write([uint32]9)
        $writer.Write([uint32]0)
        $writer.Write([uint32]100)
        $writer.Write([uint32]1)
        $writer.Write([uint32]1)
        $writer.Write([uint32]5)
        $writer.Write($Brightness)
        $writer.Write([uint32]0)
        $writer.Write([uint32]2)
        $writer.Write([uint16]1)
        $writer.Write($Red)
        $writer.Write($Green)
        $writer.Write($Blue)
        $writer.Write([byte]0)
        $writer.Flush()

        $body = $bodyStream.ToArray()
        $payloadStream = [System.IO.MemoryStream]::new()
        $payloadWriter = [System.IO.BinaryWriter]::new($payloadStream)
        try {
            $payloadWriter.Write([uint32]($body.Length + 4))
            $payloadWriter.Write($body)
            $payloadWriter.Flush()
            return $payloadStream.ToArray()
        }
        finally {
            $payloadWriter.Dispose()
            $payloadStream.Dispose()
        }
    }
    finally {
        $writer.Dispose()
        $bodyStream.Dispose()
    }
}

$options = Get-CommandOptions -Arguments @($args)
if ($null -eq $options) {
    Show-Help
    return
}

$client = [System.Net.Sockets.TcpClient]::new()
try {
    $client.ReceiveTimeout = 5000
    $client.SendTimeout = 5000
    $client.Connect('127.0.0.1', 6742)
    $stream = $client.GetStream()

    $protocolVersion = [uint32]3
    Send-OpenRgbPacket -Stream $stream -DeviceId 0 -PacketType 40 -Payload ([BitConverter]::GetBytes($protocolVersion))
    $protocolResponse = Receive-OpenRgbPacket -Stream $stream
    if ($protocolResponse.PacketType -ne 40 -or $protocolResponse.Payload.Length -ne 4) {
        throw 'OpenRGB did not return a valid protocol-version response.'
    }

    $serverVersion = [BitConverter]::ToUInt32($protocolResponse.Payload, 0)
    if ($serverVersion -lt 3) {
        throw "OpenRGB protocol version $serverVersion does not support keyboard brightness control."
    }

    $clientName = [System.Text.Encoding]::UTF8.GetBytes("acer-keyboard-led.ps1`0")
    Send-OpenRgbPacket -Stream $stream -DeviceId 0 -PacketType 50 -Payload $clientName

    Send-OpenRgbPacket -Stream $stream -DeviceId 0 -PacketType 0
    $countResponse = Receive-OpenRgbPacket -Stream $stream
    if ($countResponse.PacketType -ne 0 -or $countResponse.Payload.Length -ne 4) {
        throw 'OpenRGB did not return a valid controller count.'
    }

    $controllerCount = [BitConverter]::ToUInt32($countResponse.Payload, 0)
    $keyboardDeviceId = $null
    $keyboardControllerData = $null
    for ([uint32]$deviceId = 0; $deviceId -lt $controllerCount; $deviceId++) {
        Send-OpenRgbPacket -Stream $stream -DeviceId $deviceId -PacketType 1 -Payload ([BitConverter]::GetBytes($protocolVersion))
        $deviceResponse = Receive-OpenRgbPacket -Stream $stream
        if ($deviceResponse.PacketType -ne 1) {
            continue
        }

        $identity = Get-OpenRgbControllerIdentity -Payload $deviceResponse.Payload
        if (
            $identity.Name -eq 'AcerECKeyboard Device' -or
            ($identity.Type -eq 5 -and $identity.Name -match 'Acer.*Keyboard')
        ) {
            $keyboardDeviceId = $deviceId
            $keyboardControllerData = $deviceResponse.Payload
            break
        }
    }

    if ($null -eq $keyboardDeviceId) {
        throw 'The Acer keyboard lighting controller was not found.'
    }

    if ($options.Action -eq 'Status') {
        $state = Get-OpenRgbKeyboardState -Payload $keyboardControllerData
        [pscustomobject]@{
            Controller = 'AcerECKeyboard Device'
            Mode       = $state.Mode
            Color      = $state.Color
            Brightness = $state.Brightness
        } | Format-Table -AutoSize
    }
    else {
        $modePayload = New-StaticModePayload `
            -Red $options.Red `
            -Green $options.Green `
            -Blue $options.Blue `
            -Brightness $options.Brightness

        Send-OpenRgbPacket -Stream $stream -DeviceId $keyboardDeviceId -PacketType 1101 -Payload $modePayload

        [pscustomobject]@{
            Controller = 'AcerECKeyboard Device'
            Mode       = 'Static'
            Color      = "#$($options.HexColor)"
            Brightness = "$($options.Brightness)%"
        } | Format-Table -AutoSize
    }
}
catch [System.Net.Sockets.SocketException] {
    throw 'Cannot connect to the Acer OpenRGB server on 127.0.0.1:6742. Ensure AcerLightingService is running.'
}
finally {
    $client.Dispose()
}
