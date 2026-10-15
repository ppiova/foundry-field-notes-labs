#Requires -Version 7.0
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sample = Join-Path $root 'samples/01-support-signal'
$source = Join-Path $sample 'docs/guided-lab.md'
$destination = Join-Path $sample 'src/SupportSignal/wwwroot/guide.html'
$body = (ConvertFrom-Markdown -LiteralPath $source).Html.Replace('../src/SupportSignal/wwwroot/guide-assets/', '/guide-assets/')
$body = $body.Replace('href="../src/', 'href="https://github.com/ppiova/foundry-field-notes-labs/blob/main/samples/01-support-signal/src/').Replace('href="../tests/', 'href="https://github.com/ppiova/foundry-field-notes-labs/blob/main/samples/01-support-signal/tests/')
$body = $body.Replace('href="../README.md', 'href="https://github.com/ppiova/foundry-field-notes-labs/blob/main/samples/01-support-signal/README.md')
$body = [regex]::Replace($body, 'href="([a-z-]+\.md)(#[^"]*)?"', 'href="https://github.com/ppiova/foundry-field-notes-labs/blob/main/samples/01-support-signal/docs/$1$2"')
$html = @"
<!doctype html>
<html lang="en-US">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Guided lab · Support Signal</title><link rel="stylesheet" href="/guide.css"></head>
<body><main><nav><a href="/">← Back to Support Signal</a><span>FOUNDRY FIELD NOTES · LAB 001</span></nav>
$body
</main></body></html>
"@
$html = $html.Replace("`r`n", "`n") + "`n"
if ($Check) {
    if (!(Test-Path $destination) -or [IO.File]::ReadAllText($destination).Replace("`r`n", "`n") -ne $html) {
        throw 'The browser walkthrough is out of date. Run scripts/Build-SupportGuide.ps1.'
    }
    Write-Output 'PASS: Browser walkthrough matches its Markdown source'
} else { [IO.File]::WriteAllText($destination, $html) }
