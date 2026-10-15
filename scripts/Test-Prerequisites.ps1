#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Azure,
    [switch]$SkipSdk
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if ($Azure -and !(Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is missing. Install it from https://learn.microsoft.com/cli/azure/install-azure-cli?wt.mc_id=AI-MVP-5004753, then run az login. No deployment was started.'
}
if ($SkipSdk) { return }

$required = (Get-Content -LiteralPath (Join-Path $root 'global.json') -Raw | ConvertFrom-Json).sdk.version
$help = "Install .NET SDK $required from https://dotnet.microsoft.com/en-us/download/dotnet/11.0?wt.mc_id=AI-MVP-5004753 (not just the runtime), then rerun scripts/Test-Prerequisites.ps1. No app or deployment was started."
$local = Join-Path $root $(if ($IsWindows) { '.dotnet/dotnet.exe' } else { '.dotnet/dotnet' })
$dotnet = if (Test-Path -LiteralPath $local) { $local } else { (Get-Command dotnet -ErrorAction SilentlyContinue).Source }
if (!$dotnet) { throw ".NET SDK is missing. $help" }

# Let the SDK resolver honor global.json, including its roll-forward policy, from any caller directory.
Push-Location $root
try {
    $version = & $dotnet --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No usable SDK for global.json (requested $required). $help" }
    Write-Host "PASS: .NET SDK $version selected using global.json."
} finally { Pop-Location }
$dotnet
