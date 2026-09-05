#Requires -RunAsAdministrator

<#
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