#Requires -Version 7.0
param([ValidateRange(0, 65535)][int]$Port = 0, [ValidateSet(1, 2)][int]$Lab = 1, [switch]$Offline)
$ErrorActionPreference = 'Stop'
$labs = @{
    1 = @{ Project = 'samples/01-support-signal/src/SupportSignal'; Port = 5187 }
    2 = @{ Project = 'samples/02-bid-review-queue/src/BidReviewQueue'; Port = 5190 }
}
if ($Port -eq 0) { $Port = $labs[$Lab].Port }
Push-Location $PSScriptRoot
try {
    $sdk = & (Join-Path $PSScriptRoot 'scripts/Test-Prerequisites.ps1')
    $settings = @()
    if ($Offline) {
        $settings = if ($Lab -eq 1) {
            @('--FOUNDRY_PROJECT_ENDPOINT=', '--FOUNDRY_MODEL=', '--FOUNDRY_CREDENTIAL=azure-cli', '--SUPPORT_SIGNAL_LIVE_ONLY=false')
        } else {
            @('--FOUNDRY_RESOURCE_ENDPOINT=', '--FOUNDRY_DECISION_DEPLOYMENT=', '--FOUNDRY_ESCALATION_DEPLOYMENT=',
                '--FOUNDRY_ESCALATION_MODEL=', '--BID_REVIEW_REPLAY_FILE=', '--BID_REVIEW_ESCALATION_REPLAY_FILE=')
        }
        Write-Host $(if ($Lab -eq 1) { 'OFFLINE: deterministic simulation, not AI inference.' } else { 'OFFLINE: bundled recorded responses, not new AI inference.' })
        Write-Host 'Live model configuration is disabled for this process. Package restore may still need internet access.'
    }
    & $sdk run --project $labs[$Lab].Project -- --urls "http://localhost:$Port" @settings
    if ($LASTEXITCODE -ne 0) { throw 'Demo failed to start. Check the pinned SDK and README.' }
} finally { Pop-Location }
