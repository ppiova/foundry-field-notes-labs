#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$preflight = Join-Path $PSScriptRoot 'Test-Prerequisites.ps1'
$startupState = @{
    Available = $true; AzureAvailable = $true; SdkExit = 0; AzureCalls = 0
    Runs = [Collections.Generic.List[object]]::new()
    Requested = (Get-Content (Join-Path $root 'global.json') -Raw | ConvertFrom-Json).sdk.version
}

function Get-Command {
    param([string]$Name, $ErrorAction)
    if ($Name -eq 'dotnet' -and $startupState.Available) { [pscustomobject]@{ Source = 'Invoke-TestDotnet' } }
    elseif ($Name -eq 'az' -and $startupState.AzureAvailable) { [pscustomobject]@{ Source = 'az' } }
}
function Test-Path {
    param([string]$LiteralPath)
    if ($LiteralPath -like '*.dotnet/dotnet*' -or $LiteralPath -like '*.dotnet\dotnet*') { return $false }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Invoke-TestDotnet {
    if ($args[0] -eq '--version') {
        if ((Get-Location).Path -ne $root) { throw 'SDK selection did not run at the repository root.' }
        $global:LASTEXITCODE = $startupState.SdkExit
        if ($startupState.SdkExit -eq 0) { $startupState.Requested } else { 'No compatible SDK found.' }
    } else {
        $startupState.Runs.Add(@($args))
        $global:LASTEXITCODE = 0
    }
}
function az { $startupState.AzureCalls++; throw 'Startup checks must never reach Azure.' }
function Assert([bool]$Condition, [string]$Message) { if (!$Condition) { throw "Startup check failed: $Message" } }
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $message = $null
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert ($message -like $Pattern) "Expected '$Pattern', got '$message'."
}

Push-Location $PSScriptRoot
try {
    Assert (((Get-Content (Join-Path $root 'global.json') -Raw | ConvertFrom-Json).sdk.rollForward) -eq 'disable') 'SDK roll-forward must stay disabled: a different prerelease changes implicit packages and breaks locked restore.'
    Assert ((& $preflight) -eq 'Invoke-TestDotnet') 'The selected SDK was not returned.'
    Assert ((Get-Location).Path -eq $PSScriptRoot) 'The caller directory was not restored.'
    $startupState.Available = $false
    Expect-Failure { & $preflight } '*SDK is missing*'
    $startupState.Available = $true
    $startupState.SdkExit = 1
    Expect-Failure { & $preflight } '*No usable SDK*'
    foreach ($labs in @('01'), @('02'), @('01', '02')) {
        Expect-Failure { & (Join-Path $root 'infra/Deploy-Labs.ps1') -Subscription 'selected-subscription' -Labs $labs } '*No usable SDK*'
    }
    Assert ($startupState.AzureCalls -eq 0) 'A deployment reached Azure before checking the SDK.'
    Assert ($null -eq (& $preflight -Azure -SkipSdk)) 'Preview prerequisites should not require an SDK.'
    $startupState.AzureAvailable = $false
    Expect-Failure { & $preflight -Azure -SkipSdk } '*Azure CLI is missing*'
    $startupState.SdkExit = 0
    foreach ($lab in 1, 2) { & (Join-Path $root 'Start-Demo.ps1') -Lab $lab -Offline }
    Assert ($startupState.Runs.Count -eq 2) 'Offline startup did not launch both apps.'
    Assert ($startupState.Runs[0] -contains '--FOUNDRY_PROJECT_ENDPOINT=' -and $startupState.Runs[0] -contains '--SUPPORT_SIGNAL_LIVE_ONLY=false') 'Offline Lab 001 retained live settings.'
    foreach ($setting in 'FOUNDRY_RESOURCE_ENDPOINT', 'FOUNDRY_DECISION_DEPLOYMENT', 'FOUNDRY_ESCALATION_DEPLOYMENT', 'BID_REVIEW_REPLAY_FILE', 'BID_REVIEW_ESCALATION_REPLAY_FILE') {
        Assert ($startupState.Runs[1] -contains "--$setting=") "Offline Lab 002 retained $setting."
    }
    & (Join-Path $root 'Start-Demo.ps1') -Lab 2
    Assert (!(@($startupState.Runs[2] | Where-Object { $_ -like '--FOUNDRY*' }).Count)) 'Normal startup changed live configuration.'
    $startupState.SdkExit = 1
    Expect-Failure { & (Join-Path $root 'Start-Demo.ps1') -Offline } '*No usable SDK*'
    Assert ($startupState.Runs.Count -eq 3) 'Startup continued after an SDK failure.'
} finally { Pop-Location }
Write-Output 'PASS: SDK diagnostics, working directory, pre-deployment checks, SDK-free preview and explicit offline startup; no Azure calls.'
$global:LASTEXITCODE = 0
