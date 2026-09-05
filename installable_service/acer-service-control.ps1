<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

$ErrorActionPreference = 'Stop'

function Show-Help {
    @'
Control Acer hardware through the local Acer Control Windows service.

Usage:
  .\acer-service-control.ps1 status
  .\acer-service-control.ps1 fan status
  .\acer-service-control.ps1 fan auto
  .\acer-service-control.ps1 fan max
  .\acer-service-control.ps1 fan <CPU_PERCENT> <GPU_PERCENT>
  .\acer-service-control.ps1 keyboard status
  .\acer-service-control.ps1 keyboard color <RRGGBB> brightness <0-100>
  .\acer-service-control.ps1 profile status
  .\acer-service-control.ps1 profile next
  .\acer-service-control.ps1 profile <NAME>
  .\acer-service-control.ps1 settings apply
'@
}

function Get-ServiceTokenPath {
    if ($env:ACER_CONTROL_TOKEN_FILE) {
        return $env:ACER_CONTROL_TOKEN_FILE
    }

    return Join-Path $env:ProgramData 'AcerControl\api-token'
}

function Get-ServiceBaseUrl {
    if ($env:ACER_CONTROL_BASE_URL) {
        return $env:ACER_CONTROL_BASE_URL.TrimEnd('/')
    }

    return 'http://127.0.0.1:46934'
}

function Invoke-ServiceRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'PUT', 'POST')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )

    $tokenPath = Get-ServiceTokenPath
    if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
        throw "The Acer Control API token was not found at '$tokenPath'. Is the service installed?"
    }

    $token = (Get-Content -LiteralPath $tokenPath -Raw).Trim()
    $request = @{
        Uri         = "$(Get-ServiceBaseUrl)$Path"
        Method      = $Method
        Headers     = @{ Authorization = "Bearer $token" }
        ErrorAction = 'Stop'
    }
    if ($Method -ne 'GET') {
        $request.ContentType = 'application/json'
        $request.Body = if ($null -eq $Body) {
            '{}'
        }
        else {
            $Body | ConvertTo-Json -Compress
        }
    }

    try {
        return Invoke-RestMethod @request
    }
    catch {
        $response = $_.Exception.Response
        if ($null -ne $response) {
            $reader = [IO.StreamReader]::new($response.GetResponseStream())
            try {
                $details = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
            if (-not [string]::IsNullOrWhiteSpace($details)) {
                throw "Acer Control service request failed: $details"
            }
        }

        throw
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

function Invoke-FanCommand {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments)

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'status') {
        return Invoke-ServiceRequest -Method GET -Path '/api/v1/fan'
    }
    if ($Arguments.Count -eq 1 -and $Arguments[0] -in @('auto', 'max')) {
        return Invoke-ServiceRequest -Method PUT -Path '/api/v1/fan' -Body @{
            mode = $Arguments[0]
        }
    }

    if ($Arguments.Count -eq 3 -and $Arguments[0] -eq 'custom') {
        $Arguments = @($Arguments | Select-Object -Skip 1)
    }
    if ($Arguments.Count -ne 2) {
        throw 'The fan command requires status, auto, max, or CPU and GPU percentages.'
    }

    return Invoke-ServiceRequest -Method PUT -Path '/api/v1/fan' -Body @{
        mode       = 'custom'
        cpuPercent = ConvertTo-Percentage $Arguments[0]
        gpuPercent = ConvertTo-Percentage $Arguments[1]
    }
}

function Invoke-KeyboardCommand {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments)

    if ($Arguments.Count -eq 1 -and $Arguments[0] -eq 'status') {
        return Invoke-ServiceRequest -Method GET -Path '/api/v1/keyboard'
    }
    if ($Arguments.Count -ne 4) {
        throw 'The keyboard command requires color RRGGBB brightness 0-100.'
    }

    $options = @{}
    for ($index = 0; $index -lt $Arguments.Count; $index += 2) {
        $name = $Arguments[$index].ToLowerInvariant()
        if ($name -notin @('color', 'brightness') -or $options.ContainsKey($name)) {
            throw "Invalid or duplicate keyboard option '$name'."
        }
        $options[$name] = $Arguments[$index + 1]
    }
    if (-not $options.ContainsKey('color') -or -not $options.ContainsKey('brightness')) {
        throw 'The keyboard command requires color and brightness.'
    }

    $color = $options.color.Trim().TrimStart('#')
    if ($color -notmatch '^[0-9A-Fa-f]{6}$') {
        throw "'$color' is not a six-digit RGB color."
    }

    return Invoke-ServiceRequest -Method PUT -Path '/api/v1/keyboard' -Body @{
        color      = $color.ToUpperInvariant()
        brightness = ConvertTo-Percentage $options.brightness
    }
}

function Invoke-ProfileCommand {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments)

    if ($Arguments.Count -ne 1) {
        throw 'The profile command requires status, next, or a profile name.'
    }
    if ($Arguments[0] -eq 'status') {
        return Invoke-ServiceRequest -Method GET -Path '/api/v1/profile'
    }
    if ($Arguments[0] -eq 'next') {
        return Invoke-ServiceRequest -Method POST -Path '/api/v1/profile/next'
    }

    return Invoke-ServiceRequest -Method PUT -Path '/api/v1/profile' -Body @{
        profile = $Arguments[0]
    }
}

$arguments = @(
    $args | ForEach-Object {
        if ($_.StartsWith('--')) { $_.Substring(2) } else { $_ }
    }
)
if ($arguments.Count -eq 0 -or $arguments[0] -in @('help', '-h', '-help', '/?')) {
    Show-Help
    exit
}

$commandArguments = @($arguments | Select-Object -Skip 1)
switch ($arguments[0].ToLowerInvariant()) {
    'status' {
        if ($commandArguments.Count -ne 0) {
            throw 'The status command does not accept arguments.'
        }
        Invoke-ServiceRequest -Method GET -Path '/api/v1/status'
    }
    'fan' { Invoke-FanCommand $commandArguments }
    'keyboard' { Invoke-KeyboardCommand $commandArguments }
    'led' { Invoke-KeyboardCommand $commandArguments }
    'profile' { Invoke-ProfileCommand $commandArguments }
    'settings' {
        if ($commandArguments.Count -ne 1 -or $commandArguments[0] -ne 'apply') {
            throw 'The settings command requires apply.'
        }
        Invoke-ServiceRequest -Method POST -Path '/api/v1/settings/apply'
    }
    default { throw "Unknown command '$($arguments[0])'. Run with help for usage." }
}