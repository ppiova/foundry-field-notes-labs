#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    & (Join-Path $PSScriptRoot 'Build-SupportGuide.ps1') -Check
    & (Join-Path $PSScriptRoot 'Build-BidReviewGuide.ps1') -Check
    & (Join-Path $PSScriptRoot 'Build-BidPresentation.ps1') -Check
    if (!(Get-Command node -ErrorAction SilentlyContinue)) { throw 'Presentation checks require Node.js 24.15.0 (pinned in CI).' }
    & node --test scripts/tests/site.test.cjs samples/01-support-signal/tests/presentation.test.cjs samples/02-bid-review-queue/tests/presentation.test.cjs
    if ($LASTEXITCODE -ne 0) { throw 'Static presentation checks failed.' }
    # Most deployment scripts cannot run without Azure, so prove that every script parses; the preview and the platform
    # check also run against a fake Azure CLI.
    foreach ($script in Get-ChildItem -Path scripts, infra, samples, Start-Demo.ps1 -Recurse -Filter *.ps1) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors) { throw "PowerShell syntax error in $($script.FullName): $($parseErrors[0].Message)" }
    }
    Write-Output 'PASS: Every PowerShell script parses'
    & (Join-Path $PSScriptRoot 'Test-Startup.ps1')
    & (Join-Path $PSScriptRoot 'Test-DeploymentAccount.ps1')
    # Run them from a scope with its own az and Invoke-WebRequest: the fakes must win, and these must survive.
    & {
        function az { throw 'The offline Azure checks reached the caller''s az.' }
        function Invoke-WebRequest { throw 'The offline Azure checks reached the caller''s Invoke-WebRequest.' }
        & (Join-Path $PSScriptRoot 'Test-AzureScripts.ps1')
        foreach ($name in 'az', 'Invoke-WebRequest') {
            if ((Get-Item -LiteralPath "Function:\$name").ScriptBlock.ToString() -notlike "*reached the caller*$name*") { throw "The offline Azure checks replaced the caller's $name." }
        }
    }
    # The platform template includes every lab template, so one build compiles them all. GitHub-hosted runners have the
    # Azure CLI; elsewhere the step is skipped and says so.
    if (Get-Command az -ErrorAction SilentlyContinue) {
        & az bicep build --file infra/main.bicep --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'The Bicep templates do not compile.' }
        Write-Output 'PASS: Bicep templates compile'
    }
    else { Write-Output 'SKIP: Azure CLI not found, so the Bicep templates were not compiled' }
    $dotnet = & (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1')
    & $dotnet restore FoundryFieldNotes.slnx --locked-mode
    if ($LASTEXITCODE -ne 0) { throw 'Locked restore failed.' }
    & $dotnet build FoundryFieldNotes.slnx --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Build failed. Stop the apps before rebuilding on Windows.' }
    & $dotnet run --no-build --project samples/01-support-signal/tests/SupportSignal.Checks
    if ($LASTEXITCODE -ne 0) { throw 'Support Signal provider-contract checks failed.' }
    & (Join-Path $PSScriptRoot 'Test-SupportCloudMode.ps1') -Dotnet $dotnet
    & $dotnet run --no-build --project samples/02-bid-review-queue/tests/BidReviewQueue.Checks
    if ($LASTEXITCODE -ne 0) { throw 'Bid Review Queue checks failed.' }
    $report = Join-Path ([IO.Path]::GetTempPath()) "bid-review-queue-validation-$PID.md"
    try {
        & $dotnet run --no-build --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- --escalation replay --out $report | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Bid Review Queue evaluation command failed on the bundled recordings.' }
        if (!(Select-String -LiteralPath $report -Pattern 'No new requests' -Quiet)) { throw 'The evaluation report does not say that it replays recorded responses.' }
        if (!(Select-String -LiteralPath $report -Pattern '## Second opinion from ' -Quiet)) { throw 'The evaluation report has no second-opinion section.' }
        Write-Output 'PASS: Evaluation command replays the bundled recordings, including second opinions, and labels its report'
    } finally { Remove-Item -LiteralPath $report -ErrorAction SilentlyContinue }

    function Test-Sample([string]$directory, [string]$dll, [string[]]$clearSettings, [string]$testScript) {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
        $url = "http://127.0.0.1:$port"
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $dotnet
        $info.WorkingDirectory = Join-Path $root $directory
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        foreach ($arg in @($dll, '--urls', $url) + ($clearSettings | ForEach-Object { "--$_=" })) { $info.ArgumentList.Add($arg) }
        $process = [Diagnostics.Process]::Start($info)
        try {
            $ready = $false
            for ($attempt = 0; $attempt -lt 40; $attempt++) {
                if ($process.HasExited) { throw "Temporary server for $directory exited before readiness." }
                try { $status = Invoke-RestMethod "$url/api/status" -TimeoutSec 1; $ready = $true; break } catch { Start-Sleep -Milliseconds 250 }
            }
            if (!$ready) { throw "Temporary server for $directory was not ready within the startup window." }
            if ($status.foundryConfigured) { throw 'Validation must not have Foundry configured.' }
            & (Join-Path $PSScriptRoot $testScript) -BaseUrl $url
        } finally {
            if (!$process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
        }
    }
    Test-Sample 'samples/01-support-signal/src/SupportSignal' 'bin/Debug/net11.0/SupportSignal.dll' @('FOUNDRY_PROJECT_ENDPOINT', 'FOUNDRY_MODEL') 'Test-Demo.ps1'
    Test-Sample 'samples/02-bid-review-queue/src/BidReviewQueue' 'bin/Debug/net11.0/BidReviewQueue.dll' @('FOUNDRY_RESOURCE_ENDPOINT', 'FOUNDRY_DECISION_DEPLOYMENT', 'FOUNDRY_ESCALATION_DEPLOYMENT', 'FOUNDRY_ESCALATION_MODEL', 'BID_REVIEW_REPLAY_FILE', 'BID_REVIEW_ESCALATION_REPLAY_FILE') 'Test-BidReviewQueue.ps1'

    $trackedMarkdown = & git ls-files --cached --others --exclude-standard '*.md'
    foreach ($path in $trackedMarkdown) {
        if (!(Test-Path -LiteralPath $path)) { continue }
        $file = Get-Item -LiteralPath $path
        foreach ($match in [regex]::Matches((Get-Content $file.FullName -Raw), '\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Split('#')[0]
            if (!$target -or $target -match '^https?://') { continue }
            if (!(Test-Path -LiteralPath (Join-Path $file.DirectoryName $target))) { throw "Broken Markdown link in ${path}: $target" }
        }
    }
    Write-Output 'Validation passed: build, offline checks, recorded-run evaluation, HTTP checks for both labs and local Markdown links. No live Azure calls.'
} finally { Pop-Location }
