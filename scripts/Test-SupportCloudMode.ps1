#Requires -Version 7.0
param([Parameter(Mandatory)][string]$Dotnet)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$url = "http://127.0.0.1:$port"
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $Dotnet
$info.WorkingDirectory = Join-Path $root 'samples/01-support-signal/src/SupportSignal'
$info.UseShellExecute = $false
$info.ArgumentList.Add('bin/Debug/net11.0/SupportSignal.dll')
$info.ArgumentList.Add('--urls')
$info.ArgumentList.Add($url)
$info.Environment['FOUNDRY_PROJECT_ENDPOINT'] = 'https://example.services.ai.azure.com/api/projects/example'
$info.Environment['FOUNDRY_MODEL'] = 'example-model'
$info.Environment['FOUNDRY_CREDENTIAL'] = 'managed-identity'
$info.Environment['WEBSITE_SITE_NAME'] = 'cloud-mode-check'
$process = [Diagnostics.Process]::Start($info)
try {
    $ready = $false
    for ($i=0; $i -lt 40; $i++) {
        try { $status = Invoke-RestMethod "$url/api/status" -TimeoutSec 1; $ready=$true; break }
        catch { Start-Sleep -Milliseconds 250 }
    }
    if (!$ready) { throw 'Cloud-mode test server did not start.' }
    if ($status.simulationEnabled -or $status.defaultMode -ne 'foundry' -or $status.hosting -ne 'Azure App Service') { throw 'Cloud-mode status is incorrect.' }
    $response = Invoke-WebRequest "$url/api/analyze" -Method Post -ContentType 'application/json' -Body '{"text":"The production portal is unavailable.","mode":"simulation"}' -SkipHttpErrorCheck
    if ($response.StatusCode -ne 400 -or $response.Content -notmatch 'Simulation is disabled') { throw 'Cloud mode accepted simulation.' }
    Write-Output 'PASS: Azure mode selects Foundry and rejects simulation at the API boundary; no model called'
} finally {
    if (!$process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    $process.Dispose()
}
