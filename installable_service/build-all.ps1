<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

$solutionPath = Join-Path $PSScriptRoot 'AcerControl.sln'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Acer Control can only be built on Windows.'
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'Acer Control requires 64-bit Windows.'
}

if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
    throw 'Building Acer Control requires Windows PowerShell 5.1 or PowerShell 7 or newer.'
}

$dotnetCommand = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $dotnetCommand) {
    throw 'The .NET 10 SDK (x64) is required, but dotnet.exe was not found in PATH.'
}

$installedSdks = & $dotnetCommand.Source --list-sdks
if ($LASTEXITCODE -ne 0) {
    throw "dotnet --list-sdks exited with code $LASTEXITCODE."
}

if (-not ($installedSdks | Where-Object { $_ -match '^10\.' })) {
    throw 'The .NET 10 SDK is required. Install an x64 .NET SDK version beginning with 10.'
}

$dotnetInfo = (& $dotnetCommand.Source --info) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw "dotnet --info exited with code $LASTEXITCODE."
}

if ($dotnetInfo -notmatch '(?im)^\s*Architecture:\s*x64\s*$') {
    throw 'The installed dotnet host must be x64.'
}

Write-Host 'Build prerequisites satisfied: Windows x64, supported PowerShell, and .NET 10 SDK x64.'

dotnet restore $solutionPath
if ($LASTEXITCODE -ne 0) {
    throw "dotnet restore exited with code $LASTEXITCODE."
}

dotnet build `
    $solutionPath `
    --configuration $Configuration `
    --no-restore
if ($LASTEXITCODE -ne 0) {
    throw "dotnet build exited with code $LASTEXITCODE."
}

Write-Host "Built all Acer Control projects ($Configuration)."