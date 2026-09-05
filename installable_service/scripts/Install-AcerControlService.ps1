#Requires -RunAsAdministrator

<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

param(
    [string]$PublishPath = (
        Join-Path $PSScriptRoot '..\artifacts\publish\AcerControlService'
    )
)

$ErrorActionPreference = 'Stop'

$serviceName = 'AcerControlService'
$installPath = Join-Path $env:ProgramFiles 'AcerControl'
$dataPath = Join-Path $env:ProgramData 'AcerControl'
$tokenPath = Join-Path $dataPath 'api-token'
if (-not (Test-Path -LiteralPath $PublishPath -PathType Container)) {
    throw "Publish output was not found at '$PublishPath'. Run .\scripts\Publish-AcerControlService.ps1 first."
}
$sourcePath = (Resolve-Path -LiteralPath $PublishPath).Path
$sourceExecutable = Join-Path $sourcePath 'AcerControlService.exe'
if (-not (Test-Path -LiteralPath $sourceExecutable -PathType Leaf)) {
    throw "AcerControlService.exe was not found under '$sourcePath'. Run the publish script first."
}

function Invoke-Sc {
    param([Parameter(Mandatory)][string[]]$Arguments)

    & sc.exe @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "sc.exe $($Arguments -join ' ') exited with code $LASTEXITCODE."
    }
}

function Set-PathAcl {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$UsersCanRead
    )

    $grants = @(
        '*S-1-5-18:(OI)(CI)F',
        '*S-1-5-32-544:(OI)(CI)F'
    )
    if ($UsersCanRead) {
        $grants += '*S-1-5-32-545:(OI)(CI)RX'
    }

    & icacls.exe $Path '/inheritance:r' '/grant:r' $grants | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set permissions on '$Path'."
    }
}

function Initialize-Registry {
    $registryPath = 'HKLM:\SOFTWARE\AcerControl\Service'
    New-Item -Path $registryPath -Force | Out-Null
    $defaults = @{
        SchemaVersion   = 1
        ApiPort         = 46934
        RestoreOnStartup = 1
        RestoreOnResume = 1
    }
    foreach ($entry in $defaults.GetEnumerator()) {
        if ($null -eq (Get-ItemProperty -Path $registryPath -Name $entry.Key -ErrorAction SilentlyContinue)) {
            New-ItemProperty `
                -Path $registryPath `
                -Name $entry.Key `
                -Value $entry.Value `
                -PropertyType DWord | Out-Null
        }
    }

    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'SOFTWARE\AcerControl\Service',
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        [System.Security.AccessControl.RegistryRights]::ChangePermissions
    )
    try {
        $security = $key.GetAccessControl()
        $security.SetAccessRuleProtection($true, $false)
        foreach ($rule in @(
            [System.Security.AccessControl.RegistryAccessRule]::new(
                [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18'),
                [System.Security.AccessControl.RegistryRights]::FullControl,
                [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            ),
            [System.Security.AccessControl.RegistryAccessRule]::new(
                [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'),
                [System.Security.AccessControl.RegistryRights]::FullControl,
                [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            ),
            [System.Security.AccessControl.RegistryAccessRule]::new(
                [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),
                [System.Security.AccessControl.RegistryRights]::ReadKey,
                [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
        )) {
            $security.AddAccessRule($rule)
        }
        $key.SetAccessControl($security)
    }
    finally {
        $key.Dispose()
    }
}

$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($null -ne $existingService -and $existingService.Status -ne 'Stopped') {
    Stop-Service -Name $serviceName -Force
    $existingService.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
}

New-Item -ItemType Directory -Path $installPath -Force | Out-Null
Copy-Item -Path (Join-Path $sourcePath '*') -Destination $installPath -Recurse -Force
Set-PathAcl -Path $installPath

New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    $tokenBytes = [byte[]]::new(32)
    $randomNumberGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomNumberGenerator.GetBytes($tokenBytes)
    }
    finally {
        $randomNumberGenerator.Dispose()
    }
    [IO.File]::WriteAllText(
        $tokenPath,
        [Convert]::ToBase64String($tokenBytes),
        [Text.UTF8Encoding]::new($false)
    )
}
Set-PathAcl -Path $dataPath -UsersCanRead
Initialize-Registry

$executablePath = Join-Path $installPath 'AcerControlService.exe'
if ($null -eq $existingService) {
    Invoke-Sc @(
        'create', $serviceName,
        'binPath=', "`"$executablePath`"",
        'start=', 'delayed-auto',
        'obj=', 'LocalSystem',
        'DisplayName=', 'Acer Control Service'
    )
}
else {
    Invoke-Sc @(
        'config', $serviceName,
        'binPath=', "`"$executablePath`"",
        'start=', 'delayed-auto',
        'obj=', 'LocalSystem',
        'DisplayName=', 'Acer Control Service'
    )
}

Invoke-Sc @(
    'description', $serviceName,
    'Controls fan, keyboard lighting, and performance profile settings.'
)
Invoke-Sc @(
    'failure', $serviceName,
    'reset=', '86400',
    'actions=', 'restart/5000/restart/15000/restart/60000'
)
Invoke-Sc @('failureflag', $serviceName, '1')

Start-Service -Name $serviceName
$service = Get-Service -Name $serviceName
$service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))

$port = (Get-ItemProperty 'HKLM:\SOFTWARE\AcerControl\Service').ApiPort
$deadline = [DateTime]::UtcNow.AddSeconds(60)
$health = $null
do {
    try {
        $health = Invoke-RestMethod `
            -Uri "http://127.0.0.1:$port/healthz" `
            -Method Get `
            -TimeoutSec 2
    }
    catch {
        $health = $null
    }

    if ($null -ne $health -and $health.status -eq 'healthy') {
        break
    }
    if ([DateTime]::UtcNow -ge $deadline) {
        $lastStatus = if ($null -eq $health) {
            'The health endpoint was unavailable.'
        }
        else {
            "Last health status: $($health.status). $($health.message)"
        }
        throw "The service started, but the Acer firmware interface was not ready within 60 seconds. $lastStatus"
    }

    Start-Sleep -Milliseconds 500
} while ($true)

$token = [IO.File]::ReadAllText($tokenPath).Trim()
$headers = @{ Authorization = "Bearer $token" }
$fan = Invoke-RestMethod `
    -Uri "http://127.0.0.1:$port/api/v1/fan" `
    -Method Get `
    -Headers $headers
if ($null -eq $fan.mode) {
    Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/v1/fan" `
        -Method Put `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body '{"mode":"auto"}' | Out-Null
    Write-Host 'Default fan mode set to Auto. This preference was saved to the registry and will be restored at startup and resume.'
}
else {
    Write-Host 'Existing managed fan preference retained from the registry.'
}

Write-Host "Acer Control Service installed and running. Health: $($health.status)"