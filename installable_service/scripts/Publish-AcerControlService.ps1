<#
PowerShell compatibility:
- Windows PowerShell 5.1: Supported on Windows.
- PowerShell 7.x: Supported on Windows.
#>

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [string]$OutputPath = (
        Join-Path $PSScriptRoot '..\artifacts\publish\AcerControlService'
    )
)

$ErrorActionPreference = 'Stop'

$solutionPath = Join-Path $PSScriptRoot '..\AcerControl.sln'
$projectPath = Join-Path `
    $PSScriptRoot `
    '..\src\AcerControl.Service\AcerControl.Service.csproj'

dotnet restore $solutionPath
if ($LASTEXITCODE -ne 0) {
    throw "dotnet restore exited with code $LASTEXITCODE."
}

dotnet test $solutionPath --configuration $Configuration --no-restore
if ($LASTEXITCODE -ne 0) {
    throw "dotnet test exited with code $LASTEXITCODE."
}

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

dotnet publish `
    $projectPath `
    --configuration $Configuration `
    --runtime win-x64 `
    --self-contained true `
    --output $OutputPath `
    --no-restore
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish exited with code $LASTEXITCODE."
}

Write-Host "Published Acer Control Service to $OutputPath"