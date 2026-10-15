#Requires -Version 7.0
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sample = Join-Path $root 'samples/02-bid-review-queue'
$source = Join-Path $sample 'docs/decision-model.md'
$destination = Join-Path $sample 'src/BidReviewQueue/wwwroot/model-guide.html'
$repo = 'https://github.com/ppiova/foundry-field-notes-labs/blob/main/samples/02-bid-review-queue'
$body = (ConvertFrom-Markdown -LiteralPath $source).Html
$body = $body.Replace('href="../src/', "href=`"$repo/src/")
$body = [regex]::Replace($body, 'href="([a-z-]+\.md)(#[^"]*)?"', "href=`"$repo/docs/`$1`$2`"")
$html = @"
<!doctype html>
<html lang="en-US">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Microsoft-Decision-1 in Foundry · Foundry Field Notes</title><link rel="stylesheet" href="/model-guide.css"></head>
<body><main><nav><a href="/">Back to Bid Review Queue</a><span>FOUNDRY FIELD NOTES · LAB 002</span></nav>
<p class="source-note">This walkthrough is included with the app. Source-code and companion-document links open GitHub; local copies are available in your checkout.</p>
$body
</main></body></html>
"@
$html = $html.Replace("`r`n", "`n") + "`n"
if ($Check) {
    if (!(Test-Path $destination) -or [IO.File]::ReadAllText($destination).Replace("`r`n", "`n") -ne $html) {
        throw 'The browser model guide is out of date. Run scripts/Build-BidReviewGuide.ps1.'
    }
    Write-Output 'PASS: Browser model guide matches its Markdown source'
} else { [IO.File]::WriteAllText($destination, $html) }
