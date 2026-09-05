#Requires -RunAsAdministrator

<#
.SYNOPSIS
Uninstalls the Acer Control Windows service.

.DESCRIPTION
Stops and removes AcerControlService, its installed binaries, and its shared API token. Desired settings remain in the registry by default so they are available after reinstalling.

.PARAMETER Purge
Also removes all Acer Control service configuration and desired settings under HKLM\SOFTWARE\AcerControl. Use this option when no settings should be retained for a future installation.

.EXAMPLE
.\Uninstall-AcerControlService.ps1

Uninstalls the service while retaining desired registry settings.

.EXAMPLE
.\Uninstall-AcerControlService.ps1 -Purge

Uninstalls the service and removes all retained registry settings.

.NOTES
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

param([switch]$Purge)

$ErrorActionPreference = 'Stop'

$serviceName = 'AcerControlService'
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($null -ne $service) {
    if ($service.Status -ne 'Stopped') {
        Stop-Service -Name $serviceName -Force
        $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }

    & sc.exe delete $serviceName | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Could not delete service '$serviceName'."
    }
}

$installPath = Join-Path $env:ProgramFiles 'AcerControl'
if (Test-Path -LiteralPath $installPath) {
    Remove-Item -LiteralPath $installPath -Recurse -Force
}

$dataPath = Join-Path $env:ProgramData 'AcerControl'
if (Test-Path -LiteralPath $dataPath) {
    Remove-Item -LiteralPath $dataPath -Recurse -Force
}

if ($Purge) {
    $registryPath = 'HKLM:\SOFTWARE\AcerControl'
    if (Test-Path -LiteralPath $registryPath) {
        Remove-Item -LiteralPath $registryPath -Recurse -Force
    }
}

Write-Host 'Acer Control Service uninstalled.'
if (-not $Purge) {
    Write-Host 'Desired registry state was preserved. Use -Purge to remove it.'
}