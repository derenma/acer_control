<#
PowerShell compatibility:
- Windows PowerShell 5.1: Required for hardware operations.
- PowerShell 7.x: Help is supported; hardware commands relaunch in Windows
    PowerShell 5.1.
#>

$ErrorActionPreference = 'Stop'

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

function Show-Help {
    @'
Control Acer Nitro fans, keyboard lighting, and performance profiles directly
through the AcerGamingFunction firmware interface.

Usage:
  .\acer-control.ps1 fan <CPU_PERCENT> <GPU_PERCENT>
    .\acer-control.ps1 fan auto
    .\acer-control.ps1 fan max
    .\acer-control.ps1 fan status

    .\acer-control.ps1 keyboard color "<RRGGBB>" brightness <0-100>
    .\acer-control.ps1 keyboard status

    .\acer-control.ps1 profile status
    .\acer-control.ps1 profile next
  .\acer-control.ps1 profile Eco
  .\acer-control.ps1 profile Quiet
  .\acer-control.ps1 profile Balanced
  .\acer-control.ps1 profile Performance
  .\acer-control.ps1 profile Turbo

  .\acer-control.ps1 status
    .\acer-control.ps1 help

The script requests administrator access when necessary. It can coexist with
AcerAgentService so unrelated Acer features remain available. It does not
require Acer Lighting Service or OpenRGB.

Changing the performance profile can reset custom fan control. Eco may require
battery power, while Turbo may require AC power.
'@
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Invoke-WindowsPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $windowsPowerShell = Join-Path $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
    $powerShellArguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $PSCommandPath
    ) + $Arguments
    & $windowsPowerShell @powerShellArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Windows PowerShell exited with code $LASTEXITCODE."
    }
}

function Invoke-Elevated {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $windowsPowerShell = Join-Path $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
    $outputPath = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("acer-control-{0}.log" -f [guid]::NewGuid())
    $invocation = @{
        ScriptPath = $PSCommandPath
        Arguments  = $Arguments
        OutputPath = $outputPath
    } | ConvertTo-Json -Compress
    $invocationBase64 = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($invocation)
    )
    $elevatedCommand = @"
`$ErrorActionPreference = 'Stop'
`$invocationJson = [Text.Encoding]::Unicode.GetString(
    [Convert]::FromBase64String('$invocationBase64')
)
`$invocation = `$invocationJson | ConvertFrom-Json
try {
    `$childArguments = @(`$invocation.Arguments)
    `$commandOutput = & `$invocation.ScriptPath @childArguments 2>&1 |
        Out-String -Width 240
    [IO.File]::WriteAllText(
        `$invocation.OutputPath,
        `$commandOutput,
        [Text.UTF8Encoding]::new(`$false)
    )
    exit 0
}
catch {
    `$errorOutput = `$_ | Out-String -Width 240
    [IO.File]::WriteAllText(
        `$invocation.OutputPath,
        `$errorOutput,
        [Text.UTF8Encoding]::new(`$false)
    )
    exit 1
}
"@
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($elevatedCommand)
    )

    try {
        $process = Start-Process `
            -FilePath $windowsPowerShell `
            -Verb RunAs `
            -WindowStyle Hidden `
            -Wait `
            -PassThru `
            -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-EncodedCommand', $encodedCommand
            )
        $commandOutput = if (Test-Path -LiteralPath $outputPath) {
            [IO.File]::ReadAllText($outputPath)
        }
        else {
            ''
        }

        if ($process.ExitCode -ne 0) {
            if ([string]::IsNullOrWhiteSpace($commandOutput)) {
                throw "The elevated process exited with code $($process.ExitCode) without returning an error."
            }

            throw $commandOutput.TrimEnd()
        }

        if (-not [string]::IsNullOrWhiteSpace($commandOutput)) {
            Write-Host $commandOutput.TrimEnd()
        }
    }
    finally {
        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }
    }
}

function Get-GamingInterface {
    $instances = @(
        Get-WmiObject `
            -Namespace root\wmi `
            -Class AcerGamingFunction `
            -ErrorAction Stop
    )
    if ($instances.Count -eq 0) {
        throw 'The AcerGamingFunction firmware interface was not found.'
    }

    return $instances[0]
}

function Invoke-GamingMethod {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [object]$InputValue
    )

    $methodDefinition = $Gaming.PSObject.Methods[$Method]
    if ($null -eq $methodDefinition) {
        throw "The firmware does not expose $Method."
    }

    $methodArguments = [object[]]::new(1)
    $methodArguments[0] = $InputValue
    $output = $methodDefinition.Invoke($methodArguments)
    if ($null -eq $output) {
        throw "$Method returned no response."
    }

    return $output
}

function Invoke-GamingSet {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [object]$InputValue,

        [uint32[]]$AcceptedStatuses = @(0)
    )

    $output = Invoke-GamingMethod `
        -Gaming $Gaming `
        -Method $Method `
        -InputValue $InputValue
    if ($null -eq $output['gmOutput']) {
        throw "$Method did not return a status."
    }

    $status = [uint32]$output['gmOutput']
    if (($status -band 0xFF) -notin $AcceptedStatuses) {
        throw ('{0} rejected the request with status 0x{1:X}.' -f `
            $Method, $status)
    }
}

function Invoke-GamingGetUInt64 {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [uint32]$InputValue
    )

    $output = Invoke-GamingMethod `
        -Gaming $Gaming `
        -Method $Method `
        -InputValue $InputValue
    if ($null -eq $output['gmOutput']) {
        throw "$Method did not return data."
    }

    return [uint64]$output['gmOutput']
}

function Get-ByteFromFirmwareResult {
    param([Parameter(Mandatory)][uint64]$Value)

    if (($Value -band 0xFF) -ne 0) {
        throw ('The firmware returned status 0x{0:X2}.' -f `
            ($Value -band 0xFF))
    }

    return [byte](($Value -shr 8) -band 0xFF)
}

function Get-FanTarget {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [uint32]$Selector
    )

    $value = Invoke-GamingGetUInt64 `
        -Gaming $Gaming `
        -Method 'GetGamingFanSpeed' `
        -InputValue $Selector
    return Get-ByteFromFirmwareResult -Value $value
}

function Get-SensorValue {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [uint32]$Selector,

        [Parameter(Mandatory)]
        [uint32]$Mask
    )

    $value = Invoke-GamingGetUInt64 `
        -Gaming $Gaming `
        -Method 'GetGamingSysInfo' `
        -InputValue $Selector
    if (($value -band 0xFF) -ne 0) {
        return $null
    }

    return [int](($value -shr 8) -band $Mask)
}

function Get-FanState {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [string]$Mode = 'Not independently verified'
    )

    return [pscustomobject]@{
        Mode       = $Mode
        CPUPercent = Get-FanTarget -Gaming $Gaming -Selector 0x01
        GPUPercent = Get-FanTarget -Gaming $Gaming -Selector 0x04
        CPURPM     = Get-SensorValue `
            -Gaming $Gaming -Selector 0x0201 -Mask 0xFFFF
        GPURPM     = Get-SensorValue `
            -Gaming $Gaming -Selector 0x0601 -Mask 0xFFFF
        CPUTempC   = Get-SensorValue `
            -Gaming $Gaming -Selector 0x0101 -Mask 0xFF
        GPUTempC   = Get-SensorValue `
            -Gaming $Gaming -Selector 0x0A01 -Mask 0xFF
    }
}

function ConvertTo-Percentage {
    param([Parameter(Mandatory)][string]$Value)

    $percentage = 0
    if (
        -not [int]::TryParse($Value, [ref]$percentage) -or
        $percentage -lt 0 -or
        $percentage -gt 100
    ) {
        throw "'$Value' is not a percentage from 0 through 100."
    }

    return [byte]$percentage
}

function Set-FanBehavior {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [uint64]$Behavior
    )

    Invoke-GamingSet `
        -Gaming $Gaming `
        -Method 'SetGamingFanBehavior' `
        -InputValue $Behavior
}

function Set-FanTarget {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [byte]$Selector,

        [Parameter(Mandatory)]
        [byte]$Percentage
    )

    $inputValue = [uint64]$Selector -bor ([uint64]$Percentage -shl 8)
    Invoke-GamingSet `
        -Gaming $Gaming `
        -Method 'SetGamingFanSpeed' `
        -InputValue $inputValue
}

function Set-CustomFans {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [byte]$CPU,

        [Parameter(Mandatory)]
        [byte]$GPU
    )

    try {
        for ($attempt = 0; $attempt -lt 2; $attempt++) {
            Set-FanBehavior -Gaming $Gaming -Behavior 0x00C30009
            Set-FanTarget -Gaming $Gaming -Selector 0x01 -Percentage $CPU
            Set-FanTarget -Gaming $Gaming -Selector 0x04 -Percentage $GPU
        }

        Start-Sleep -Milliseconds 300
        $cpuReadback = Get-FanTarget -Gaming $Gaming -Selector 0x01
        $gpuReadback = Get-FanTarget -Gaming $Gaming -Selector 0x04
        if ($cpuReadback -ne $CPU -or $gpuReadback -ne $GPU) {
            throw "Fan target readback was CPU $cpuReadback%, GPU $gpuReadback%."
        }
    }
    catch {
        $fanError = $_
        try {
            Set-FanBehavior -Gaming $Gaming -Behavior 0x00410009
        }
        catch {
            throw "$($fanError.Exception.Message) Restoring automatic fan control also failed: $($_.Exception.Message)"
        }

        throw $fanError
    }

    return Get-FanState -Gaming $Gaming -Mode 'Custom request accepted'
}

function Invoke-FanCommand {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'status') {
        return Get-FanState -Gaming $Gaming
    }

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'auto') {
        Set-FanBehavior -Gaming $Gaming -Behavior 0x00410009
        Start-Sleep -Milliseconds 300
        return Get-FanState -Gaming $Gaming -Mode 'Auto request accepted'
    }

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'max') {
        Set-FanBehavior -Gaming $Gaming -Behavior 0x00820009
        Start-Sleep -Milliseconds 300
        return Get-FanState -Gaming $Gaming -Mode 'Max request accepted'
    }

    if ($Arguments.Count -ne 2) {
        throw 'The fan command requires CPU and GPU percentages, auto, max, or status.'
    }

    $cpu = ConvertTo-Percentage -Value $Arguments[0]
    $gpu = ConvertTo-Percentage -Value $Arguments[1]
    return Set-CustomFans -Gaming $Gaming -CPU $cpu -GPU $gpu
}

function Get-KeyboardOptions {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    if ($Arguments.Count -ne 4) {
        throw 'The keyboard command requires color and brightness.'
    }

    $values = @{}
    for ($index = 0; $index -lt $Arguments.Count; $index += 2) {
        $name = $Arguments[$index].ToLowerInvariant()
        if ($name -notin @('color', 'brightness')) {
            throw "Unknown keyboard option '$name'."
        }
        if ($values.ContainsKey($name)) {
            throw "Keyboard option '$name' was specified more than once."
        }

        $values[$name] = $Arguments[$index + 1]
    }

    if (
        -not $values.ContainsKey('color') -or
        -not $values.ContainsKey('brightness')
    ) {
        throw 'The keyboard command requires color and brightness.'
    }

    $color = $values['color'].Trim().TrimStart('#')
    if ($color -notmatch '^[0-9A-Fa-f]{6}$') {
        throw "'$color' is not a six-digit RGB color."
    }

    return @{
        Red        = [Convert]::ToByte($color.Substring(0, 2), 16)
        Green      = [Convert]::ToByte($color.Substring(2, 2), 16)
        Blue       = [Convert]::ToByte($color.Substring(4, 2), 16)
        HexColor   = $color.ToUpperInvariant()
        Brightness = ConvertTo-Percentage -Value $values['brightness']
    }
}

function New-KeyboardPayload {
    param(
        [Parameter(Mandatory)][byte]$Mode,
        [Parameter(Mandatory)][byte]$Speed,
        [Parameter(Mandatory)][byte]$Brightness,
        [Parameter(Mandatory)][byte]$Red,
        [Parameter(Mandatory)][byte]$Green,
        [Parameter(Mandatory)][byte]$Blue
    )

    $payload = [byte[]]@(
        $Mode,
        $Speed,
        $Brightness,
        0,
        0,
        $Red,
        $Green,
        $Blue,
        0,
        1,
        0, 0, 0, 0, 0, 0
    )
    if ($payload.Length -ne 16) {
        throw 'The keyboard payload was not 16 bytes.'
    }

    return ,$payload
}

function Get-KeyboardZoneColor {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [uint32]$Zone
    )

    $value = Invoke-GamingGetUInt64 `
        -Gaming $Gaming `
        -Method 'GetGamingRgbKb' `
        -InputValue $Zone
    if (($value -band 0xFF) -ne 0) {
        throw ('GetGamingRgbKb returned status 0x{0:X2} for zone 0x{1:X2}.' -f `
            ($value -band 0xFF), $Zone)
    }

    return '#{0:X2}{1:X2}{2:X2}' -f `
        (($value -shr 8) -band 0xFF),
        (($value -shr 16) -band 0xFF),
        (($value -shr 24) -band 0xFF)
}

function Get-KeyboardState {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming
    )

    $output = Invoke-GamingMethod `
        -Gaming $Gaming `
        -Method 'GetGamingKBBacklight' `
        -InputValue ([uint32]1)
    if ($null -eq $output['gmReturn']) {
        throw 'GetGamingKBBacklight did not return a status.'
    }
    if ([byte]$output['gmReturn'] -ne 0) {
        throw ('GetGamingKBBacklight returned status 0x{0:X2}.' -f `
            [byte]$output['gmReturn'])
    }

    $data = [byte[]]$output['gmOutput']
    if ($data.Length -lt 8) {
        throw 'GetGamingKBBacklight returned incomplete data.'
    }

    $modeNames = @{
        0 = 'Static'
        1 = 'Breathing'
        2 = 'Neon'
        3 = 'Wave'
        4 = 'Shifting'
        5 = 'Zoom'
        6 = 'Meteor'
        7 = 'Twinkling'
    }
    $mode = if ($modeNames.ContainsKey([int]$data[0])) {
        $modeNames[[int]$data[0]]
    }
    else {
        "Unknown ($($data[0]))"
    }

    $colors = @(
        0x01, 0x02, 0x04, 0x08 | ForEach-Object {
            Get-KeyboardZoneColor -Gaming $Gaming -Zone $_
        }
    )

    return [pscustomobject]@{
        Controller = 'AcerGamingFunction'
        Mode       = $mode
        Color      = @($colors | Select-Object -Unique) -join ', '
        Brightness = "$($data[2])%"
    }
}

function Set-KeyboardState {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [hashtable]$Options
    )

    $static = New-KeyboardPayload `
        -Mode 0 `
        -Speed 0 `
        -Brightness $Options.Brightness `
        -Red $Options.Red `
        -Green $Options.Green `
        -Blue $Options.Blue

    foreach ($zone in 0x01, 0x02, 0x04, 0x08) {
        $rgbInput = [uint64]$zone `
            -bor ([uint64]$Options.Red -shl 8) `
            -bor ([uint64]$Options.Green -shl 16) `
            -bor ([uint64]$Options.Blue -shl 24)
        Invoke-GamingSet `
            -Gaming $Gaming `
            -Method 'SetGamingRgbKb' `
            -InputValue $rgbInput
    }
    Invoke-GamingSet `
        -Gaming $Gaming `
        -Method 'SetGamingKBBacklight' `
        -InputValue ([byte[]]$static)

    Start-Sleep -Milliseconds 300
    $state = Get-KeyboardState -Gaming $Gaming
    $requestedColor = "#$($Options.HexColor)"
    if (
        $state.Mode -ne 'Static' -or
        [int]$state.Brightness.TrimEnd('%') -ne $Options.Brightness -or
        $state.Color -ne $requestedColor
    ) {
        throw "Keyboard readback was mode '$($state.Mode)', color '$($state.Color)', brightness '$($state.Brightness)'."
    }

    return $state
}

function Invoke-KeyboardCommand {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'status') {
        return Get-KeyboardState -Gaming $Gaming
    }

    $options = Get-KeyboardOptions -Arguments $Arguments
    return Set-KeyboardState -Gaming $Gaming -Options $options
}

function Get-SupportedProfiles {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming
    )

    $value = Invoke-GamingGetUInt64 `
        -Gaming $Gaming `
        -Method 'GetGamingMiscSetting' `
        -InputValue 0x0A
    $mask = Get-ByteFromFirmwareResult -Value $value

    return @(
        $profileIds.Keys |
            Where-Object { ($mask -band (1 -shl $profileIds[$_])) -ne 0 }
    )
}

function Get-CurrentProfile {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming
    )

    $value = Invoke-GamingGetUInt64 `
        -Gaming $Gaming `
        -Method 'GetGamingMiscSetting' `
        -InputValue 0x0B
    $mode = Get-ByteFromFirmwareResult -Value $value

    return [pscustomobject]@{
        Profile = if ($profileNames.ContainsKey([int]$mode)) {
            $profileNames[[int]$mode]
        }
        else {
            "Unknown ($mode)"
        }
        ModeId = $mode
    }
}

function Set-Profile {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [string]$Profile
    )

    $mode = [byte]$profileIds[$Profile]
    $inputValue = [uint64]0x0B -bor ([uint64]$mode -shl 8)
    Invoke-GamingSet `
        -Gaming $Gaming `
        -Method 'SetGamingMiscSetting' `
        -InputValue $inputValue

    Start-Sleep -Milliseconds 300
    $current = Get-CurrentProfile -Gaming $Gaming
    if ($current.ModeId -ne $mode) {
        throw "Requested '$Profile', but firmware reports '$($current.Profile)'."
    }

    return $current
}

function Invoke-ProfileCommand {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    if ($Arguments.Count -ne 1) {
        throw 'The profile command requires a profile, next, or status.'
    }

    if ($Arguments[0] -eq 'status') {
        return Get-CurrentProfile -Gaming $Gaming
    }

    $supportedProfiles = @(Get-SupportedProfiles -Gaming $Gaming)
    if ($Arguments[0] -eq 'next') {
        $profileOrder = @(
            'Eco', 'Quiet', 'Balanced', 'Performance', 'Turbo'
        ) | Where-Object { $_ -in $supportedProfiles }
        if ($profileOrder.Count -eq 0) {
            throw 'The firmware did not report any supported profiles.'
        }

        $current = Get-CurrentProfile -Gaming $Gaming
        $currentIndex = [Array]::IndexOf(
            [string[]]$profileOrder,
            [string]$current.Profile
        )
        $requestedProfile = $profileOrder[
            ($currentIndex + 1) % $profileOrder.Count
        ]
    }
    else {
        $requestedProfile = $profileIds.Keys |
            Where-Object { $_ -ieq $Arguments[0] } |
            Select-Object -First 1
    }

    if (-not $requestedProfile) {
        throw "Unknown profile '$($Arguments[0])'."
    }
    if ($requestedProfile -notin $supportedProfiles) {
        throw "The '$requestedProfile' profile is not supported by this laptop."
    }

    return Set-Profile -Gaming $Gaming -Profile $requestedProfile
}

function Show-CombinedStatus {
    param(
        [Parameter(Mandatory)]
        [System.Management.ManagementObject]$Gaming
    )

    'Performance profile'
    Get-CurrentProfile -Gaming $Gaming | Format-Table -AutoSize
    'Fans'
    Get-FanState -Gaming $Gaming | Format-Table -AutoSize
    'Keyboard'
    Get-KeyboardState -Gaming $Gaming | Format-Table -AutoSize
}

$arguments = @($args)
if (
    $arguments.Count -eq 0 -or
    ($arguments.Count -eq 1 -and `
        $arguments[0] -in @('help', '--help', '-help', '-h', '/?'))
) {
    Show-Help
    if ($arguments.Count -eq 0) {
        exit 2
    }

    exit
}

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    if (Test-Administrator) {
        Invoke-WindowsPowerShell -Arguments $arguments
    }
    else {
        Invoke-Elevated -Arguments $arguments
    }
    exit
}

if (-not (Test-Administrator)) {
    Invoke-Elevated -Arguments $arguments
    exit
}

$gaming = Get-GamingInterface
$command = $arguments[0].ToLowerInvariant()
$commandArguments = @(
    $arguments | Select-Object -Skip 1 | ForEach-Object {
        if ($_.StartsWith('--')) {
            $_.Substring(2)
        }
        else {
            $_
        }
    }
)

switch ($command) {
    'fan' {
        Invoke-FanCommand `
            -Gaming $gaming `
            -Arguments $commandArguments |
            Format-Table -AutoSize
    }
    'keyboard' {
        Invoke-KeyboardCommand `
            -Gaming $gaming `
            -Arguments $commandArguments |
            Format-Table -AutoSize
    }
    'led' {
        Invoke-KeyboardCommand `
            -Gaming $gaming `
            -Arguments $commandArguments |
            Format-Table -AutoSize
    }
    'profile' {
        Invoke-ProfileCommand `
            -Gaming $gaming `
            -Arguments $commandArguments |
            Format-Table -AutoSize
    }
    'status' {
        if ($commandArguments.Count -ne 0) {
            throw 'The status command does not accept arguments.'
        }

        Show-CombinedStatus -Gaming $gaming
    }
    default {
        throw "Unknown command '$($arguments[0])'. Run with --help for usage."
    }
}
