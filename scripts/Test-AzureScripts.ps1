#Requires -Version 7.0
# Offline checks of the Azure scripts: the platform's -WhatIfOnly preview and Test-AzureLabs.ps1 run against a fake Azure
# CLI and a fake web request. They prove that both stay read-only, restore the CLI subscription and report what they
# should. No network and no Azure.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$deploy = Join-Path $root 'infra/Deploy-Labs.ps1'
$check = Join-Path $PSScriptRoot 'Test-AzureLabs.ps1'
$foundryUser = '/subscriptions/sub-target/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d'

function New-Deployment([string]$Name, [int]$Capacity, [string]$Model, [string]$Version) {
    @{ name = $Name; sku = @{ name = 'DataZoneStandard'; capacity = $Capacity }; properties = @{ model = @{ name = $Model; version = $Version }; provisioningState = 'Succeeded' } }
}

# A Foundry resource as az cognitiveservices account list reports it. Its endpoints use the custom subdomain, which
# can differ from the resource name. The platform's resource is tagged scope=shared.
function New-Account([string]$Name, [string]$Subdomain = $Name, [string]$Scope = 'shared') {
    @{
        name = $Name; scope = $Scope; id = "/subscriptions/sub-target/resourceGroups/rg-test/providers/Microsoft.CognitiveServices/accounts/$Name"
        properties = @{ customSubDomainName = $Subdomain; endpoint = "https://$Subdomain.cognitiveservices.azure.com/"
            endpoints = @{ 'AI Foundry API' = "https://$Subdomain.services.ai.azure.com/" } }
    }
}

function New-Platform {
    $one = 'support-signal-test'; $two = 'bid-review-queue-test'
    $site = '/subscriptions/sub-target/resourceGroups/rg-test/providers/Microsoft.Web/sites'
    $plan = '/subscriptions/sub-target/resourceGroups/rg-test/providers/Microsoft.Web/serverfarms/plan-test'
    $auth = {
        @{
            platform = @{ enabled = $true }
            globalValidation = @{ requireAuthentication = $true; unauthenticatedClientAction = 'RedirectToLoginPage' }
            identityProviders = @{ azureActiveDirectory = @{
                    enabled = $true; registration = @{ clientId = 'client-1' }
                    validation = @{ defaultAuthorizationPolicy = @{ allowedPrincipals = @{ identities = @('user-1') } } } } }
        }
    }
    @{
        Active = 'sub-original'; Calls = [Collections.Generic.List[string]]::new(); Unexpected = [Collections.Generic.List[string]]::new()
        WhatIf = $null; WhatIfRaw = $null; GroupExists = 'true'
        Plans = @('B1'); Accounts = @(New-Account 'foundry-test')
        Apps = @(
            @{ name = $one; lab = '01'; state = 'Running'; host = "$one.azurewebsites.net"; plan = $plan; id = "$site/$one" },
            @{ name = $two; lab = '02'; state = 'Running'; host = "$two.azurewebsites.net"; plan = $plan; id = "$site/$two" })
        Settings = @{
            $one = @{ FOUNDRY_PROJECT_ENDPOINT = 'https://foundry-test.services.ai.azure.com/api/projects/proj-lab01-support-signal'; FOUNDRY_MODEL = 'gpt-6-luna'
                FOUNDRY_CREDENTIAL = 'managed-identity'; SUPPORT_SIGNAL_LIVE_ONLY = 'true' }
            $two = @{ FOUNDRY_RESOURCE_ENDPOINT = 'https://foundry-test.services.ai.azure.com'; FOUNDRY_DECISION_DEPLOYMENT = 'decision-1'
                FOUNDRY_CREDENTIAL = 'managed-identity'; FOUNDRY_ESCALATION_DEPLOYMENT = 'gpt-6-luna'; FOUNDRY_ESCALATION_MODEL = 'gpt-6-luna' }
        }
        Auth = @{ $one = & $auth; $two = & $auth }
        # Model deployments per Foundry resource, and Foundry User grants per identity and resource.
        Deployments = @{ 'foundry-test' = @(
                (New-Deployment 'decision-1' 300 'Microsoft-Decision-1' '1'),
                (New-Deployment 'gpt-6-luna' 100 'gpt-6-luna' '2026-09-22')) }
        Roles = @{ "principal-$one" = @{ 'foundry-test' = @($foundryUser) }; "principal-$two" = @{ 'foundry-test' = @($foundryUser) } }
        Redirects = @("https://$one.azurewebsites.net/.auth/login/aad/callback", "https://$two.azurewebsites.net/.auth/login/aad/callback")
        Anonymous = @{ "$one.azurewebsites.net" = 302; "$two.azurewebsites.net" = 302 }
        Locations = @{
            "$one.azurewebsites.net" = '/.auth/login/aad?post_login_redirect_uri=%2F'
            "$two.azurewebsites.net" = 'https://login.microsoftonline.com/tenant-1/oauth2/v2.0/authorize?client_id=client-1'
        }
    }
}

# The fakes live in this script's scope: the scripts under test run as its children, so they find these before any az
# or Invoke-WebRequest of a caller or the session, which stay untouched. Every call is logged. Anything outside these
# reads is recorded as unexpected and fails, as a write would.
function az {
    $a = [string[]]$args
    $p = $global:FakeAzure
    $p.Calls.Add($a -join ' ')
    $global:LASTEXITCODE = 0
    $value = { param($Name) $i = [Array]::IndexOf($a, $Name); if ($i -ge 0) { $a[$i + 1] } }
    $json = { param($Value) ConvertTo-Json -InputObject $Value -Depth 10 -Compress }
    $target = @{ id = 'sub-target'; tenantId = 'tenant-1'; name = 'Target subscription' }
    $command = $a[0..2] -join ' '
    if ($command -like 'account show*') {
        if ($a -contains 'tsv') { $p.Active }
        elseif ($a -contains '--subscription' -or $p.Active -eq 'sub-target') { & $json $target }
        else { & $json @{ id = $p.Active; tenantId = 'tenant-0'; name = 'Original subscription' } }
    }
    elseif ($command -like 'account set*') { $p.Active = & $value '--subscription' }
    elseif ($command -eq 'ad signed-in-user show') { 'user-1' }
    elseif ($command -like 'group exists*') { $p.GroupExists }
    elseif ($command -like 'group show*') { & $json @{ name = $(if ($p.GroupName) { $p.GroupName } else { & $value '--name' }); location = 'eastus2' } }
    elseif ($command -eq 'appservice plan list') { & $json @($p.Plans) }
    elseif ($command -eq 'appservice plan show') { 'B1' }
    elseif ($command -eq 'cognitiveservices account list') {
        # The preview asks for the shared resource's name; the platform check reads every resource in the group.
        if ($a -contains '--query') { & $json @($p.Accounts | Where-Object { $_.scope -eq 'shared' } | ForEach-Object { $_.name }) }
        else { & $json @($p.Accounts | ForEach-Object { @{ name = $_.name; id = $_.id; properties = $_.properties } }) }
    }
    elseif ($command -eq 'cognitiveservices account show') { "/subscriptions/sub-target/resourceGroups/rg-test/providers/Microsoft.CognitiveServices/accounts/$(& $value '--name')" }
    elseif ($command -eq 'cognitiveservices account deployment' -and $a[3] -eq 'list') {
        $all = @($p.Deployments[(& $value '--name')])
        if ($a -contains '--query') { & $json @($all | ForEach-Object { @{ name = $_.name; sku = $_.sku.name; capacity = $_.sku.capacity } }) }
        else { & $json $all }
    }
    elseif ($command -like 'webapp list *') {
        # The preview asks for every lab app's ID; the platform check reads the apps' details.
        if ((& $value '--query') -like '*].id') { & $json @($p.Apps | ForEach-Object { $_.id }) } else { & $json @($p.Apps) }
    }
    elseif ($command -eq 'webapp config appsettings' -and $a[3] -eq 'list') {
        $settings = $p.Settings[(& $value '--name')]
        & $json @($settings.Keys | ForEach-Object { @{ name = $_; value = $settings[$_]; slotSetting = $false } })
    }
    elseif ($command -eq 'webapp identity show') { "principal-$(& $value '--name')" }
    elseif ($command -eq 'webapp config show') { if ($p.AlwaysOn -and $p.AlwaysOn[((& $value '--ids') -split '/sites/')[1]]) { 'true' } else { 'false' } }
    elseif ($command -eq 'role assignment list') {
        $grants = $p.Roles[(& $value '--assignee')]
        & $json @(if ($grants) { $grants[((& $value '--scope') -split '/accounts/')[1]] })
    }
    elseif ($command -eq 'rest --method get') {
        $config = $p.Auth[((& $value '--url') -split '/sites/')[1].Split('/')[0]]
        if ($a -contains 'tsv') { $config.identityProviders.azureActiveDirectory.registration.clientId } else { & $json $config }
    }
    elseif ($command -eq 'ad app show') { if ((& $value '--query') -eq 'appId') { & $value '--id' } else { & $json @($p.Redirects) } }
    elseif ($command -eq 'deployment sub what-if') {
        $p.WhatIfRaw = Get-Content -Raw -LiteralPath (& $value '--parameters').TrimStart('@')
        $p.WhatIf = ($p.WhatIfRaw | ConvertFrom-Json).parameters
        'what-if output'
    }
    else { $p.Unexpected.Add($a -join ' '); $global:LASTEXITCODE = 1 }
}

function Invoke-WebRequest {
    [CmdletBinding()]
    param([string]$Uri, [int]$MaximumRedirection, [switch]$SkipHttpErrorCheck, [int]$TimeoutSec)
    $hostName = ([uri]$Uri).Host
    $status = $global:FakeAzure.Anonymous[$hostName]
    if (!$status) { throw "No such host: $hostName" }
    $headers = @{}
    if ($status -eq 302) { $headers.Location = @($global:FakeAzure.Locations[$hostName]) }
    [pscustomobject]@{ StatusCode = $status; Headers = $headers }
}

function Assert([bool]$Condition, [string]$Message) { if (!$Condition) { throw "Azure script check failed: $Message" } }
function Assert-ReadOnly([string]$What) {
    $p = $global:FakeAzure
    Assert ($p.Unexpected.Count -eq 0) "$What made a call outside the expected reads: $($p.Unexpected -join ' | ')"
    Assert ($p.Active -eq 'sub-original') "$What did not restore the original Azure CLI subscription."
}
function Invoke-Preview([hashtable]$Platform, [hashtable]$Extra = @{}) {
    $global:FakeAzure = $Platform
    $arguments = @{ Subscription = 'sub-target'; ResourceGroup = 'rg-test'; WhatIfOnly = $true } + $Extra
    # A write fails in the fake CLI, so name the call before passing the error on.
    try { & $deploy @arguments 6>&1 | Out-String } catch { Assert-ReadOnly 'The preview'; throw }
}
function Invoke-Check([hashtable]$Platform, [hashtable]$Expected = @{}) {
    $global:FakeAzure = $Platform
    $output = & $check -Subscription 'sub-target' -ResourceGroup 'rg-test' @Expected | Out-String
    [pscustomobject]@{ Output = $output; Failed = $LASTEXITCODE -ne 0 }
}

try {
    # On an existing platform the preview keeps the tier, both capacities, the Foundry resource and the registration.
    $platform = New-Platform
    $output = Invoke-Preview $platform
    Assert-ReadOnly 'The preview'
    Assert ($output -match 'Resource group rg-test: existing' -and $output -match 'Preserving hosting tier: B1' -and
        $output -match 'decision-1: DataZoneStandard, capacity 300 \(existing deployment\)' -and
        $output -match 'gpt-6-luna: DataZoneStandard, capacity 100 \(existing deployment\)' -and
        $output -match 'Reusing app registration client-1') "The preview did not report what it keeps: $output"
    $sent = $platform.WhatIf
    Assert ($sent.appServiceSku.value -eq 'B1' -and $sent.decisionCapacity.value -eq 300 -and $sent.chatCapacity.value -eq 100 -and
        $sent.foundryAccountName.value -eq 'foundry-test' -and $sent.authClientId.value -eq 'client-1' -and $sent.resourceGroupName.value -eq 'rg-test' -and
        (@($sent.labs.value) -join ',') -eq '01,02' -and $sent.allowedPrincipalIds.value -contains 'user-1') "What-if did not receive the existing platform: $($platform.WhatIfRaw)"

    # Before anything exists, the preview reads only, uses the free tier, new deployments and a placeholder registration.
    $fresh = New-Platform
    $fresh.GroupExists = 'false'
    $output = Invoke-Preview $fresh
    Assert-ReadOnly 'The preview of a new platform'
    Assert ($output -match 'Resource group rg-test: new' -and $output -match 'Hosting tier: F1 \(new plan\)' -and
        $output -match 'decision-1: DataZoneStandard, capacity 50 \(new deployment\)' -and $output -match 'No app registration yet') "The new-platform preview did not say what it would create: $output"
    Assert ($fresh.WhatIf.authClientId.value -eq '00000000-0000-0000-0000-000000000000' -and !$fresh.WhatIf.foundryAccountName -and
        $fresh.WhatIf.location.value -eq 'eastus2') "What-if of a new platform did not receive the placeholder registration and template defaults: $($fresh.WhatIfRaw)"
    $chosen = New-Platform
    $chosen.GroupExists = 'false'
    # -Labs 2 is what PowerShell passes for an unquoted 02 in a list; it must become the lab '02'.
    Invoke-Preview $chosen @{ AppServiceSku = 'B1'; DecisionCapacity = 200; ChatCapacity = 100; Labs = @(2) } | Out-Null
    Assert-ReadOnly 'The preview with chosen values'
    Assert ($chosen.WhatIf.appServiceSku.value -eq 'B1' -and $chosen.WhatIf.decisionCapacity.value -eq 200 -and $chosen.WhatIf.chatCapacity.value -eq 100 -and
        $chosen.WhatIfRaw -match '"labs":\s*\{\s*"value":\s*\[\s*"02"\s*\]') "What-if did not receive the chosen tier, capacities and a one-lab array: $($chosen.WhatIfRaw)"
    $both = New-Platform
    $both.GroupExists = 'false'
    Invoke-Preview $both @{ Labs = @(2, 1, '01') } | Out-Null
    Assert ((@($both.WhatIf.labs.value) -join ',') -eq '01,02') "-Labs 2,1,01 did not become 01,02: $($both.WhatIfRaw)"
    $rejected = $null
    try { Invoke-Preview (New-Platform) @{ Labs = @('03') } | Out-Null } catch { $rejected = $_.Exception.Message }
    Assert ($rejected -like '*Labs*') "An unknown lab was not rejected: $rejected"

    # Lab apps on different registrations stop the preview before what-if, unless -AuthClientId chooses one.
    $mixed = New-Platform
    $mixed.Auth['support-signal-test'].identityProviders.azureActiveDirectory.registration.clientId = 'client-2'
    $stopped = $null
    try { Invoke-Preview $mixed | Out-Null } catch { $stopped = $_.Exception.Message }
    Assert ($stopped -like '*use different app registrations*' -and !$mixed.WhatIf) "Different registrations did not stop the preview: $stopped"
    Assert-ReadOnly 'The preview with different registrations'
    $chosenRegistration = New-Platform
    $chosenRegistration.Auth['support-signal-test'].identityProviders.azureActiveDirectory.registration.clientId = 'client-2'
    Invoke-Preview $chosenRegistration @{ AuthClientId = 'client-1' } | Out-Null
    Assert-ReadOnly 'The preview with -AuthClientId over different registrations'
    Assert ($chosenRegistration.WhatIf.authClientId.value -eq 'client-1') "-AuthClientId did not override different registrations: $($chosenRegistration.WhatIfRaw)"

    # Lab 001 alone neither deploys nor reports Microsoft-Decision-1; the template decides from the labs.
    $lab01Only = New-Platform
    $lab01Only.GroupExists = 'false'
    $output = Invoke-Preview $lab01Only @{ Labs = @('01') }
    Assert ($output -notmatch 'Model deployment decision-1' -and $output -match 'Model deployment gpt-6-luna' -and
        (@($lab01Only.WhatIf.labs.value) -join ',') -eq '01') "A Lab 001 preview reported the decision model or the wrong labs: $output"
    # Reads name their output format, so an Azure CLI default of "none" cannot hide the existing group.
    Assert (@($platform.Calls | Where-Object { $_ -like 'group exists *' -and $_ -like '*-o tsv*' }).Count -gt 0) "The preview read the group without an explicit output format: $($platform.Calls -join ' | ')"
    # The group's stored capitalization names the platform, so another spelling cannot create a second set of apps.
    $cased = New-Platform
    $cased.GroupName = 'RG-Test'
    Invoke-Preview $cased | Out-Null
    Assert-ReadOnly 'The preview with another capitalization'
    Assert ($cased.WhatIf.resourceGroupName.value -ceq 'RG-Test') "What-if did not receive the group's stored name: $($cased.WhatIfRaw)"
    # Moving from B1 to F1 stops before any change while an app keeps Always On, and proceeds once none does.
    $downgrade = New-Platform
    $downgrade.AlwaysOn = @{ 'bid-review-queue-test' = $true }
    $stopped = $null
    try { Invoke-Preview $downgrade @{ AppServiceSku = 'F1' } | Out-Null } catch { $stopped = $_.Exception.Message }
    Assert ($stopped -like '*B1 to F1 fails while these apps keep Always On: bid-review-queue-test*' -and !$downgrade.WhatIf) "A B1-to-F1 move with Always On did not stop clearly: $stopped"
    Assert-ReadOnly 'The preview of a B1-to-F1 move with Always On'
    $ready = New-Platform
    $ready.AlwaysOn = @{}
    Invoke-Preview $ready @{ AppServiceSku = 'F1' } | Out-Null
    Assert ($ready.WhatIf.appServiceSku.value -eq 'F1') "A B1-to-F1 move without Always On did not reach what-if: $($ready.WhatIfRaw)"

    # An existing decision deployment the template cannot manage blocks Lab 002, but not Lab 001, which leaves it alone.
    $unsupported = New-Platform
    $unsupported.Deployments['foundry-test'][0].sku.name = 'Standard'
    $output = Invoke-Preview $unsupported @{ Labs = @('01') }
    Assert-ReadOnly 'The Lab 001 preview beside an unsupported decision deployment'
    Assert ($unsupported.WhatIf -and $output -notmatch 'Model deployment decision-1') "An unsupported decision deployment blocked or showed in a Lab 001 preview: $output"
    $stopped = $null
    try { Invoke-Preview (& { $p = New-Platform; $p.Deployments['foundry-test'][0].sku.name = 'Standard'; $p }) @{ Labs = @('02') } | Out-Null } catch { $stopped = $_.Exception.Message }
    Assert ($stopped -like '*decision-1 uses Standard*') "An unsupported decision deployment did not stop a Lab 002 preview: $stopped"
    $main = Get-Content -Raw (Join-Path $root 'infra/main.bicep')
    $platformBicep = Get-Content -Raw (Join-Path $root 'infra/platform.bicep')
    Assert ($main.Contains("deployDecisionModel: contains(labs, '02')") -and $platformBicep.Contains("= if (deployDecisionModel) {")) 'The template no longer ties Microsoft-Decision-1 to Lab 002.'
    Write-Output 'PASS: Deploy-Labs.ps1 -WhatIfOnly only reads, previews a platform that does not exist yet, keeps an existing tier, capacities and registration, honors -AuthClientId over conflicting registrations, leaves Microsoft-Decision-1 out for Lab 001 alone, names its output format, keeps the group''s stored name, stops a B1-to-F1 move while Always On is set, and restores the CLI subscription'

    # The platform check passes a healthy platform, with and without expected capacities, and only reads.
    $result = Invoke-Check (New-Platform)
    Assert (!$result.Failed -and $result.Output -notmatch 'FAIL') "A healthy platform did not pass: $($result.Output)"
    Assert-ReadOnly 'The platform check'
    $result = Invoke-Check (New-Platform) @{ DecisionCapacity = 300; ChatCapacity = 100 }
    Assert (!$result.Failed) "Matching capacities did not pass: $($result.Output)"
    $split = New-Platform
    $split.Settings['support-signal-test'].FOUNDRY_PROJECT_ENDPOINT = 'https://foundry-other.services.ai.azure.com/api/projects/proj-lab01-support-signal'
    $split.Settings['support-signal-test'].FOUNDRY_MODEL = 'support-chat'
    $split.Accounts += New-Account 'foundry-other' -Scope 'lab'
    $split.Deployments['foundry-other'] = @(New-Deployment 'support-chat' 100 'gpt-6-luna' '2026-09-22')
    $split.Roles['principal-support-signal-test'] = @{ 'foundry-other' = @($foundryUser) }
    $result = Invoke-Check $split @{ DecisionCapacity = 300; ChatCapacity = 100 }
    Assert (!$result.Failed -and $result.Output.Contains('Model deployment support-chat on foundry-other')) "Labs on separate Foundry resources did not pass: $($result.Output)"
    Assert-ReadOnly 'The platform check with separate Foundry resources'
    # A resource whose name differs from its subdomain, and settings with the spaces Lab 002 trims.
    $renamed = New-Platform
    $renamed.Accounts = @(New-Account 'foundry-resource' -Subdomain 'foundry-test')
    $renamed.Deployments = @{ 'foundry-resource' = $renamed.Deployments['foundry-test'] }
    foreach ($identity in @($renamed.Roles.Keys)) { $renamed.Roles[$identity] = @{ 'foundry-resource' = @($foundryUser) } }
    $renamed.Settings['bid-review-queue-test'].FOUNDRY_DECISION_DEPLOYMENT = ' decision-1 '
    $renamed.Settings['bid-review-queue-test'].FOUNDRY_ESCALATION_MODEL = ' gpt-6-luna '
    $result = Invoke-Check $renamed @{ DecisionCapacity = 300; ChatCapacity = 100 }
    Assert (!$result.Failed -and $result.Output.Contains('is Foundry resource foundry-resource')) "A resource named apart from its subdomain, or padded settings, did not pass: $($result.Output)"
    # A platform that hosts one lab passes with -Labs for that lab, and stops clearly without it.
    foreach ($only in '01', '02') {
        $single = New-Platform
        $single.Apps = @($single.Apps | Where-Object { $_.lab -eq $only })
        $result = Invoke-Check $single @{ Labs = @([int]$only); DecisionCapacity = 300; ChatCapacity = 100 }
        Assert (!$result.Failed -and $result.Output -notmatch 'FAIL' -and $result.Output -match "INFO Lab 00$([int]$only) runs on App Service plan") "A Lab $only platform did not pass with -Labs ${only}: $($result.Output)"
        Assert-ReadOnly "The platform check of a Lab $only platform"
        $stopped = $null
        try { Invoke-Check $single | Out-Null } catch { $stopped = $_.Exception.Message }
        Assert ($stopped -like '*Every selected lab must be deployed*') "A Lab $only platform checked for both labs did not stop clearly: $stopped"
        Assert-ReadOnly "The platform check of a Lab $only platform for both labs"
    }
    Write-Output 'PASS: Test-AzureLabs.ps1 passes a healthy platform, also with one Foundry resource per lab, a resource named apart from its subdomain, padded settings and single-lab platforms checked with -Labs; it only reads and restores the CLI subscription'

    # Each fault fails the check with a message that names it.
    $faults = [ordered]@{
        'a stopped app'                = { param($p) $p.Apps[0].state = 'Stopped' }, 'Lab 001: support-signal-test is Stopped'
        'a different model'            = { param($p) $p.Deployments['foundry-test'][1].properties.model.name = 'other-model' }, 'expected gpt-6-luna 2026-09-22'
        'an older model version'       = { param($p) $p.Deployments['foundry-test'][0].properties.model.version = '0' }, 'expected Microsoft-Decision-1 1'
        'a lowered capacity'           = { param($p) $p.Deployments['foundry-test'][1].sku.capacity = 50 }, 'expected capacity 100'
        'an unsupported type'          = { param($p) $p.Deployments['foundry-test'][0].sku.name = 'Standard' }, 'type not supported by the template'
        'a missing role'               = { param($p) $p.Roles['principal-support-signal-test'] = @{} }, 'FAIL Lab 001: the app''s identity holds Foundry User'
        'a missing callback'           = { param($p) $p.Redirects = @($p.Redirects[1]) }, 'FAIL Lab 001: the sign-in registration lists'
        'sign-in that returns 401'     = { param($p) $p.Auth['bid-review-queue-test'].globalValidation.unauthenticatedClientAction = 'Return401' }, 'FAIL Lab 002: sign-in required'
        'an anonymous 401'             = { param($p) $p.Anonymous['bid-review-queue-test.azurewebsites.net'] = 401 }, 'gets HTTP 401 (expected a redirect to sign-in)'
        'an anonymous 200'             = { param($p) $p.Anonymous['support-signal-test.azurewebsites.net'] = 200 }, 'gets HTTP 200 (expected a redirect to sign-in)'
        'an unreachable app'           = { param($p) $p.Anonymous.Remove('support-signal-test.azurewebsites.net') }, 'gets no response'
        'no second model'              = { param($p) $p.Settings['bid-review-queue-test'].Remove('FOUNDRY_ESCALATION_DEPLOYMENT') }, 'Lab 002 settings: no second model'
        'one deployment for both'      = { param($p) $p.Settings['bid-review-queue-test'].FOUNDRY_ESCALATION_DEPLOYMENT = 'decision-1' }, 'FAIL Lab 002 settings: the decision and second-model deployments differ'
        'Lab 001 on the decision model' = { param($p) $p.Settings['support-signal-test'].FOUNDRY_MODEL = 'decision-1' }, 'FAIL Model deployment decision-1 on foundry-test: the labs expect different models'
        'no label and another model'   = { param($p) $p.Settings['bid-review-queue-test'].Remove('FOUNDRY_ESCALATION_MODEL'); $p.Deployments['foundry-test'][1].properties.model.name = 'other-model' }, 'expected gpt-6-luna 2026-09-22'
        'a redirect to another site'   = { param($p) $p.Locations['bid-review-queue-test.azurewebsites.net'] = 'https://example.invalid/?next=login.microsoftonline.com' }, 'gets HTTP 302 to https://example.invalid/ (expected'
        'a sign-in path elsewhere'     = { param($p) $p.Locations['support-signal-test.azurewebsites.net'] = 'https://example.invalid/.auth/login/aad' }, 'gets HTTP 302 to https://example.invalid/.auth/login/aad (expected'
        'a Lab 001 HTTP endpoint'      = { param($p) $p.Settings['support-signal-test'].FOUNDRY_PROJECT_ENDPOINT = 'http://foundry-test.services.ai.azure.com/api/projects/support-signal' }, 'FAIL Lab 001 settings: HTTPS project endpoint'
        'a Lab 002 HTTP endpoint'      = { param($p) $p.Settings['bid-review-queue-test'].FOUNDRY_RESOURCE_ENDPOINT = 'http://foundry-test.services.ai.azure.com' }, 'FAIL Lab 002 settings: HTTPS resource endpoint'
        'a Lab 002 project endpoint'   = { param($p) $p.Settings['bid-review-queue-test'].FOUNDRY_RESOURCE_ENDPOINT = 'https://foundry-test.services.ai.azure.com/api/projects/bid-review' }, 'FAIL Lab 002 settings: HTTPS resource endpoint'
        'a Lab 001 credential in caps' = { param($p) $p.Settings['support-signal-test'].FOUNDRY_CREDENTIAL = 'Managed-Identity' }, 'FAIL Lab 001 settings: HTTPS project endpoint'
        'a Lab 002 credential in caps' = { param($p) $p.Settings['bid-review-queue-test'].FOUNDRY_CREDENTIAL = 'Managed-Identity' }, 'FAIL Lab 002 settings: HTTPS resource endpoint'
        'an API path without sign-in'  = { param($p) $p.Auth['bid-review-queue-test'].globalValidation.excludedPaths = @('/api/*') }, 'FAIL Lab 002: sign-in required on every path with a redirect to the sign-in page, 1 allowed user(s) (excluded: /api/*)'
        'an unrelated endpoint host'   = { param($p) $p.Settings['bid-review-queue-test'].FOUNDRY_RESOURCE_ENDPOINT = 'https://foundry-test.example.invalid' }, 'FAIL Lab 002: endpoint host foundry-test.example.invalid matches no Foundry resource in rg-test'
        'a callback in another case'   = { param($p) $p.Redirects[0] = 'https://support-signal-test.azurewebsites.net/.auth/login/aad/Callback' }, 'FAIL Lab 001: the sign-in registration lists'
        'a redirect over HTTP'         = { param($p) $p.Locations['support-signal-test.azurewebsites.net'] = 'http://support-signal-test.azurewebsites.net/.auth/login/aad' }, 'gets HTTP 302 to http://support-signal-test.azurewebsites.net/.auth/login/aad (expected'
        'a callback on another port'   = { param($p) $p.Redirects[0] = 'https://support-signal-test.azurewebsites.net:8443/.auth/login/aad/callback' }, 'FAIL Lab 001: the sign-in registration lists'
        'a sign-in on another port'    = { param($p) $p.Locations['support-signal-test.azurewebsites.net'] = 'https://support-signal-test.azurewebsites.net:8443/.auth/login/aad' }, 'gets HTTP 302 to https://support-signal-test.azurewebsites.net:8443/.auth/login/aad (expected'
        'Entra ID on another port'     = { param($p) $p.Locations['bid-review-queue-test.azurewebsites.net'] = 'https://login.microsoftonline.com:8443/tenant-1/oauth2/v2.0/authorize' }, 'gets HTTP 302 to https://login.microsoftonline.com:8443/tenant-1/oauth2/v2.0/authorize (expected'
    }
    foreach ($fault in $faults.Keys) {
        $platform = New-Platform
        & $faults[$fault][0] $platform
        $result = Invoke-Check $platform @{ DecisionCapacity = 300; ChatCapacity = 100 }
        Assert ($result.Failed -and $result.Output.Contains($faults[$fault][1])) "The check did not report $fault. Output: $($result.Output)"
        Assert-ReadOnly "The platform check with $fault"
    }
    Write-Output "PASS: Test-AzureLabs.ps1 reports each of $($faults.Count) faults, including a wrong model or capacity and a 401 instead of a sign-in redirect"
    foreach ($zero in @{ DecisionCapacity = 0 }, @{ ChatCapacity = 0 }) {
        $rejected = $false
        try { Invoke-Check (New-Platform) $zero | Out-Null } catch { $rejected = $_.Exception.Message -like '*DecisionCapacity*' -or $_.Exception.Message -like '*ChatCapacity*' }
        Assert $rejected "A capacity of 0 was accepted instead of rejected: $($zero.Keys)"
    }
    Write-Output 'PASS: Test-AzureLabs.ps1 rejects a capacity of 0 instead of skipping the comparison'

    # The fake only answers reads, so a write in either script cannot pass for one.
    foreach ($write in 'cognitiveservices account deployment create', 'cognitiveservices account deployment delete', 'webapp config appsettings set',
        'webapp config appsettings delete', 'group create', 'group delete', 'deployment group create', 'deployment sub create', 'role assignment create',
        'ad app create', 'ad app update', 'ad app federated-credential create', 'rest --method put', 'webapp deploy') {
        $global:FakeAzure = New-Platform
        az @($write -split ' ') --name test | Out-Null
        Assert ($LASTEXITCODE -eq 1 -and $global:FakeAzure.Unexpected.Count -eq 1) "The fake Azure CLI accepted '$write' as a read."
    }
    Write-Output 'PASS: The fake Azure CLI rejects writes, so the read-only checks above would catch one'

    # The models and deployment names the scripts expect are the ones the platform template deploys.
    $main = Get-Content -Raw (Join-Path $root 'infra/main.bicep')
    $platformBicep = Get-Content -Raw (Join-Path $root 'infra/platform.bicep')
    $checkText = Get-Content -Raw $check
    $deployText = Get-Content -Raw $deploy
    $chatName = [regex]::Match($main, "param chatModelName string = '([^']+)'").Groups[1].Value
    $chatVersion = [regex]::Match($main, "param chatModelVersion string = '([^']+)'").Groups[1].Value
    $decisionName = [regex]::Match($main, "var decisionDeploymentName = '([^']+)'").Groups[1].Value
    $decisionVersion = [regex]::Match($platformBicep, "name: 'Microsoft-Decision-1'\s+version: '([^']+)'").Groups[1].Value
    Assert ($chatName -and $chatVersion -and $checkText.Contains("`$chatModel = @{ Name = '$chatName'; Version = '$chatVersion' }")) 'Test-AzureLabs.ps1 expects a different chat model than infra/main.bicep.'
    Assert ($decisionVersion -and $checkText.Contains("Name = 'Microsoft-Decision-1'; Version = '$decisionVersion'")) 'Test-AzureLabs.ps1 expects a different decision model version than infra/platform.bicep.'
    Assert ($main.Contains('var chatDeploymentName = chatModelName') -and $decisionName -and $deployText.Contains("`$decisionDeployment = '$decisionName'") -and
        $deployText.Contains("`$chatDeployment = '$chatName'")) 'Deploy-Labs.ps1 reads different model deployment names than infra/main.bicep creates.'
    Write-Output 'PASS: Test-AzureLabs.ps1 and Deploy-Labs.ps1 expect the models, versions and deployment names that the platform template deploys'
}
finally {
    # The fakes end with this script's scope; only the shared state needs removing.
    Remove-Variable -Name FakeAzure -Scope Global -ErrorAction SilentlyContinue
    $global:LASTEXITCODE = 0
}
