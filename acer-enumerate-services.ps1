<#
.SYNOPSIS
Find Windows services that appear to be distributed by Acer.

.DESCRIPTION
Scores service names, executable paths, binary version metadata, and
Authenticode signers. By default, only running services with Likely or Strong
confidence are returned. Results are indicators, not proof of ownership.

.PARAMETER IncludeStopped
Inspect stopped services as well as running services.

.PARAMETER IncludePossible
Include candidates supported only by weaker evidence, such as Acer branding in
the service name without matching binary publisher metadata.

.PARAMETER AsJson
Return the result array as JSON instead of PowerShell objects.

.EXAMPLE
.\acer-enumerate-services.ps1

.EXAMPLE
.\acer-enumerate-services.ps1 -IncludeStopped -IncludePossible |
    Format-List

.EXAMPLE
.\acer-enumerate-services.ps1 -AsJson

.NOTES
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>
[CmdletBinding()]
param(
    [switch]$IncludeStopped,
    [switch]$IncludePossible,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Get-ServiceExecutablePath {
    param([AllowEmptyString()][string]$PathName)

    if ([string]::IsNullOrWhiteSpace($PathName)) {
        return $null
    }

    $expandedPath = [Environment]::ExpandEnvironmentVariables($PathName.Trim())
    $executablePath = if ($expandedPath -match '^"([^"]+\.exe)"') {
        $Matches[1]
    }
    elseif ($expandedPath -match '^(.+?\.exe)(?:\s|$)') {
        $Matches[1]
    }
    else {
        $null
    }

    if ([string]::IsNullOrWhiteSpace($executablePath)) {
        return $null
    }

    $executablePath = $executablePath -replace '^\\\?\?\\', ''
    if (-not [IO.Path]::IsPathRooted($executablePath)) {
        $systemExecutable = Join-Path $env:SystemRoot "System32\$executablePath"
        if (Test-Path -LiteralPath $systemExecutable -PathType Leaf) {
            return $systemExecutable
        }
    }

    return $executablePath
}

function Get-BinaryFacts {
    param([AllowNull()][string]$Path)

    $facts = [ordered]@{
        Exists          = $false
        CompanyName     = $null
        ProductName     = $null
        FileDescription = $null
        FileVersion     = $null
        SignatureStatus = 'NotChecked'
        Signer          = $null
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]$facts
    }

    $facts.Exists = $true
    try {
        $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        $facts.CompanyName = $versionInfo.CompanyName
        $facts.ProductName = $versionInfo.ProductName
        $facts.FileDescription = $versionInfo.FileDescription
        $facts.FileVersion = $versionInfo.FileVersion
    }
    catch {
        Write-Verbose "Could not read version metadata from '$Path': $($_.Exception.Message)"
    }

    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path
        $facts.SignatureStatus = [string]$signature.Status
        if ($null -ne $signature.SignerCertificate) {
            $facts.Signer = $signature.SignerCertificate.Subject
        }
    }
    catch {
        $facts.SignatureStatus = 'CheckFailed'
        Write-Verbose "Could not inspect the signature on '$Path': $($_.Exception.Message)"
    }

    return [pscustomobject]$facts
}

function Add-Evidence {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[string]]$Evidence,
        [Parameter(Mandatory)][ref]$Score,
        [Parameter(Mandatory)][int]$Points,
        [Parameter(Mandatory)][string]$Description
    )

    $Score.Value += $Points
    $Evidence.Add($Description)
}

$serviceFilter = if ($IncludeStopped) { $null } else { "State = 'Running'" }
$services = if ($null -eq $serviceFilter) {
    @(Get-CimInstance -ClassName Win32_Service)
}
else {
    @(Get-CimInstance -ClassName Win32_Service -Filter $serviceFilter)
}

$binaryCache = @{}
$results = foreach ($service in $services) {
    $executablePath = Get-ServiceExecutablePath -PathName $service.PathName
    $cacheKey = if ([string]::IsNullOrWhiteSpace($executablePath)) {
        "<unknown>:$($service.Name)"
    }
    else {
        $executablePath.ToLowerInvariant()
    }

    if (-not $binaryCache.ContainsKey($cacheKey)) {
        $binaryCache[$cacheKey] = Get-BinaryFacts -Path $executablePath
    }
    $binary = $binaryCache[$cacheKey]

    $score = 0
    $evidence = [Collections.Generic.List[string]]::new()
    $serviceIdentity = "$($service.Name) $($service.DisplayName)"
    if ($serviceIdentity -match '(?i)(^|\s)acer|^AASSvc\b|\b(nitro|predator)sense\b|\bcare center\b|\bquick access\b') {
        Add-Evidence -Evidence $evidence -Score ([ref]$score) -Points 2 `
            -Description 'Acer product branding appears in the service name or display name'
    }

    if ($executablePath -match '(?i)\\(?:acer|nitro|predator)[^\\]*\\|\\(?:acer|nitro|predator)[^\\]*\.inf_') {
        Add-Evidence -Evidence $evidence -Score ([ref]$score) -Points 2 `
            -Description 'Executable is installed in an Acer, Nitro, or Predator package path'
    }

    if ($binary.CompanyName -match '(?i)\bacer(?: incorporated| inc\.?)?\b') {
        Add-Evidence -Evidence $evidence -Score ([ref]$score) -Points 5 `
            -Description "Binary company metadata identifies '$($binary.CompanyName)'"
    }

    $productMetadata = "$($binary.ProductName) $($binary.FileDescription)"
    if ($productMetadata -match '(?i)\bacer\b|\b(nitro|predator)sense\b|\bcare center\b|\bquick access\b') {
        Add-Evidence -Evidence $evidence -Score ([ref]$score) -Points 3 `
            -Description 'Binary product metadata contains Acer product branding'
    }

    if ($binary.Signer -match '(?i)\bacer(?: incorporated| inc\.?)?\b') {
        Add-Evidence -Evidence $evidence -Score ([ref]$score) -Points 5 `
            -Description 'Authenticode signer identifies Acer'
    }

    if ($score -lt 2) {
        continue
    }

    $confidence = if ($score -ge 7) {
        'Strong'
    }
    elseif ($score -ge 4) {
        'Likely'
    }
    else {
        'Possible'
    }

    if (-not $IncludePossible -and $confidence -eq 'Possible') {
        continue
    }

    [pscustomobject]@{
        Confidence      = $confidence
        Score           = $score
        ServiceName     = $service.Name
        DisplayName     = $service.DisplayName
        State           = $service.State
        StartMode       = $service.StartMode
        ProcessId       = $service.ProcessId
        ExecutablePath  = $executablePath
        CompanyName     = $binary.CompanyName
        ProductName     = $binary.ProductName
        FileDescription = $binary.FileDescription
        FileVersion     = $binary.FileVersion
        SignatureStatus = $binary.SignatureStatus
        Signer          = $binary.Signer
        Evidence        = @($evidence)
    }
}

$results = @($results | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, ServiceName)
if ($AsJson) {
    ConvertTo-Json -InputObject $results -Depth 4
}
else {
    $results
}