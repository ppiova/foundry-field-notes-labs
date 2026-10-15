#Requires -Version 7.0
<#
.SYNOPSIS
Checks that the selected labs, both by default, are configured and reachable on the lab platform. Read-only.

.DESCRIPTION
Reads the web apps, plan, app settings, sign-in configuration, model deployments, role assignments and the sign-in
registration's callbacks in the resource group you name, then requests each app anonymously and expects a redirect to
sign-in. It creates, changes and deletes nothing, signs in to no app and calls no model. To confirm live inference,
sign in to each app afterwards and run one synthetic request.

Pass -DecisionCapacity and -ChatCapacity with the values infra/Deploy-Labs.ps1 -WhatIfOnly printed to require them;
without them, capacities are reported but not compared.
#>
[CmdletBinding()]
param(
    # Name or ID of the subscription you chose. Required on purpose: the CLI default is never assumed.
    [Parameter(Mandatory)] [string]$Subscription,
    [string]$ResourceGroup = 'rg-foundry-field-notes-labs',
    # Labs to check, as deployed with Deploy-Labs.ps1 -Labs. 1 and 2 work too.
    [ValidatePattern('^0?[12]$')] [string[]]$Labs = @('01', '02'),
    # Expected capacity of the Microsoft-Decision-1 deployment (requests per minute).
    [ValidateRange(1, [int]::MaxValue)] [int]$DecisionCapacity,
    # Expected capacity of the chat model deployment (thousands of tokens per minute).
    [ValidateRange(1, [int]::MaxValue)] [int]$ChatCapacity
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../infra/Select-DeploymentAccount.ps1')

function Invoke-Az {
    $output = & az @args
    if ($LASTEXITCODE -ne 0) { throw "az $($args[0]) $($args[1]) failed. See the error above." }
    $output
}

# The apps accept only absolute HTTPS endpoints; Lab 002 also rejects a project endpoint.
function Test-HttpsUrl([string]$Value) {
    $parsed = $null
    [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$parsed) -and $parsed.Scheme -eq 'https'
}

# An endpoint names a Foundry resource when its host is one the resource reports, or the resource's custom subdomain
# under an Azure AI domain. The resource name alone is not enough: Lab 001 builds its endpoint from the subdomain.
function Find-FoundryAccount([object[]]$Accounts, [string]$Endpoint) {
    $hostName = ([uri]$Endpoint).Host
    foreach ($candidate in $Accounts) {
        $reported = @(@($candidate.properties.endpoint) + @($candidate.properties.endpoints.PSObject.Properties.Value) | Where-Object { $_ } |
            ForEach-Object { $parsed = $null; if ([uri]::TryCreate($_, [UriKind]::Absolute, [ref]$parsed)) { $parsed.Host } })
        $subdomain = $candidate.properties.customSubDomainName
        $bySubdomain = $subdomain -and @('services.ai.azure.com', 'cognitiveservices.azure.com', 'openai.azure.com' | Where-Object { $hostName -eq "$subdomain.$_" }).Count -gt 0
        if ($hostName -in $reported -or $bySubdomain) { return $candidate }
    }
}

$script:failures = 0
function Report([bool]$Passed, [string]$Label) {
    if (!$Passed) { $script:failures++ }
    Write-Output "$(if ($Passed) { 'PASS' } else { 'FAIL' }) $Label"
}

# Foundry User (formerly Azure AI User), the inference role both labs assign to their app identities.
$foundryUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
# What the platform template deploys (infra/platform.bicep and infra/main.bicep); Test-AzureScripts.ps1 keeps them in sync.
$decisionModel = @{ Name = 'Microsoft-Decision-1'; Version = '1' }
$chatModel = @{ Name = 'gpt-6-luna'; Version = '2026-09-22' }
$supportedSkus = @('DataZoneStandard', 'GlobalStandard')
$originalAccount = Invoke-Az account show --query id -o tsv
try {
    # Graph reads (the registration's callbacks) use the active CLI tenant, so select the target first.
    $account = Select-DeploymentAccount -Subscription $Subscription
    $sub = $account.id
    $apps = @(Invoke-Az webapp list --resource-group $ResourceGroup --subscription $sub `
        --query "[?tags.project=='foundry-field-notes'].{name: name, lab: tags.lab, state: state, host: defaultHostName, plan: appServicePlanId, id: id}" -o json | ConvertFrom-Json)
    $titles = @{ '01' = 'Lab 001'; '02' = 'Lab 002' }
    $labNames = [ordered]@{}
    foreach ($lab in @($Labs | ForEach-Object { '{0:D2}' -f [int]$_ } | Select-Object -Unique | Sort-Object)) { $labNames[$lab] = $titles[$lab] }
    $found = @{}
    foreach ($lab in $labNames.Keys) {
        $tagged = @($apps | Where-Object { $_.lab -eq $lab })
        Report ($tagged.Count -eq 1) "$($labNames[$lab]): exactly one web app tagged lab=$lab (found $($tagged.Count))"
        if ($tagged.Count -eq 1) {
            $found[$lab] = $tagged[0]
            Report ($tagged[0].state -eq 'Running') "$($labNames[$lab]): $($tagged[0].name) is $($tagged[0].state)"
        }
    }
    if ($found.Count -ne $labNames.Count) { throw 'Every selected lab must be deployed before the remaining checks can run. Pass -Labs with the labs you deployed.' }

    $plans = @($found.Values.plan | Select-Object -Unique)
    $tier = Invoke-Az appservice plan show --ids $plans[0] --query sku.name -o tsv
    if ($labNames.Count -gt 1) { Report ($plans.Count -eq 1) "Both labs share one App Service plan ($($plans[0].Split('/')[-1]), $tier)" }
    else { Write-Output "INFO $(@($labNames.Values)[0]) runs on App Service plan $($plans[0].Split('/')[-1]) ($tier)" }

    $settings = @{}
    $auth = @{}
    foreach ($lab in $labNames.Keys) {
        $app = $found[$lab]
        $values = @{}
        foreach ($setting in @(Invoke-Az webapp config appsettings list --resource-group $ResourceGroup --name $app.name --subscription $sub -o json | ConvertFrom-Json)) {
            $values[$setting.name] = $setting.value
        }
        $settings[$lab] = $values
        $auth[$lab] = Invoke-Az rest --method get --url "https://management.azure.com$($app.id)/config/authsettingsV2?api-version=2024-04-01" --query properties -o json | ConvertFrom-Json
    }
    $one = $settings['01']; $two = $settings['02']
    # Lab 002 trims its deployment names and model label, so the check does too.
    $decision = "$($two.FOUNDRY_DECISION_DEPLOYMENT)".Trim()
    $second = "$($two.FOUNDRY_ESCALATION_DEPLOYMENT)".Trim()
    $label = "$($two.FOUNDRY_ESCALATION_MODEL)".Trim()
    $oneEndpoint = if (Test-HttpsUrl $one.FOUNDRY_PROJECT_ENDPOINT) { $one.FOUNDRY_PROJECT_ENDPOINT }
    $twoValue = "$($two.FOUNDRY_RESOURCE_ENDPOINT)".Trim()
    $twoEndpoint = if ((Test-HttpsUrl $twoValue) -and ([uri]$twoValue).AbsolutePath -notlike '*/api/projects*') { $twoValue }
    # The apps compare these values case-sensitively, so the check does too.
    if ($labNames.Contains('01')) {
        Report ($oneEndpoint -and $one.FOUNDRY_MODEL -and $one.FOUNDRY_CREDENTIAL -ceq 'managed-identity' -and $one.SUPPORT_SIGNAL_LIVE_ONLY -ceq 'true') `
            "Lab 001 settings: HTTPS project endpoint, model deployment '$($one.FOUNDRY_MODEL)', managed identity, simulation disabled"
    }
    if ($labNames.Contains('02')) {
        Report ($twoEndpoint -and $decision -and $two.FOUNDRY_CREDENTIAL -ceq 'managed-identity') `
            "Lab 002 settings: HTTPS resource endpoint without /api/projects, decision deployment '$decision', managed identity"
        if ($second) {
            # The label only names the model on the page; the deployment itself is checked against the template below.
            Report ($label -eq $chatModel.Name) `
                "Lab 002 settings: second model deployment '$second', labeled '$label'$(if ($label -ne $chatModel.Name) { " (expected $($chatModel.Name))" })"
            Report ($second -ne $decision) "Lab 002 settings: the decision and second-model deployments differ ('$decision', '$second')"
        }
        else { Report $false 'Lab 002 settings: no second model. Redeploy with infra/Deploy-Labs.ps1.' }
    }

    $clientIds = @()
    foreach ($lab in $labNames.Keys) {
        $config = $auth[$lab]
        $aad = $config.identityProviders.azureActiveDirectory
        $allowed = @($aad.validation.defaultAuthorizationPolicy.allowedPrincipals.identities | Where-Object { $_ })
        # The templates exclude no path, so an exclusion could expose the billed inference API to anonymous callers.
        $excluded = @($config.globalValidation.excludedPaths | Where-Object { $_ })
        Report ($config.platform.enabled -and $config.globalValidation.requireAuthentication -and
            $config.globalValidation.unauthenticatedClientAction -eq 'RedirectToLoginPage' -and $excluded.Count -eq 0 -and $aad.enabled -and $allowed.Count -gt 0) `
            "$($labNames[$lab]): sign-in required on every path with a redirect to the sign-in page, $($allowed.Count) allowed user(s)$(if ($excluded) { " (excluded: $($excluded -join ', '))" })"
        $clientIds += $aad.registration.clientId
    }

    # Each lab is checked on the Foundry resource its own endpoint names, which must be in this resource group. Only
    # endpoints the apps would accept count; the others already failed above.
    $foundryAccounts = @(Invoke-Az cognitiveservices account list --resource-group $ResourceGroup --subscription $sub -o json | ConvertFrom-Json)
    $labAccount = [ordered]@{}
    foreach ($lab in $labNames.Keys) {
        $endpoint = if ($lab -eq '01') { $oneEndpoint } else { $twoEndpoint }
        if (!$endpoint) { continue }
        $match = Find-FoundryAccount $foundryAccounts $endpoint
        $hostName = ([uri]$endpoint).Host
        Report ([bool]$match) $(if ($match) { "$($labNames[$lab]): endpoint host $hostName is Foundry resource $($match.name)" } else { "$($labNames[$lab]): endpoint host $hostName matches no Foundry resource in $ResourceGroup" })
        if ($match) { $labAccount[$lab] = $match }
    }
    # The platform template manages every model deployment the labs call, so each must have the model, version and
    # type it deploys: Microsoft-Decision-1 for Lab 002's decisions, the chat model for Lab 001 and second opinions.
    $chatExpected = @{ Model = $chatModel.Name; Version = $chatModel.Version; Capacity = $ChatCapacity }
    $labDeployments = @{ '01' = [ordered]@{}; '02' = [ordered]@{} }
    if ($one.FOUNDRY_MODEL) { $labDeployments['01'][$one.FOUNDRY_MODEL] = $chatExpected }
    if ($decision) {
        $labDeployments['02'][$decision] = @{ Model = $decisionModel.Name; Version = $decisionModel.Version; Capacity = $DecisionCapacity }
    }
    # A second model sharing the decision deployment already failed above; keep the decision expectation for it.
    if ($second -and $second -ne $decision) { $labDeployments['02'][$second] = $chatExpected }
    foreach ($foundry in @($labAccount.Values | ForEach-Object { $_.name } | Select-Object -Unique)) {
        $labsHere = @($labAccount.Keys | Where-Object { $labAccount[$_].name -eq $foundry })
        $deployments = @(Invoke-Az cognitiveservices account deployment list --resource-group $ResourceGroup --name $foundry --subscription $sub -o json | ConvertFrom-Json)
        # Both labs may call one deployment (the chat model); they must then expect the same model of it.
        $expected = [ordered]@{}
        foreach ($lab in $labsHere) {
            foreach ($name in $labDeployments[$lab].Keys) {
                $want = $labDeployments[$lab][$name]
                if ($expected.Contains($name) -and $expected[$name].Model -ne $want.Model) {
                    Report $false "Model deployment ${name} on ${foundry}: the labs expect different models ($($expected[$name].Model), $($want.Model))"
                }
                if (!$expected.Contains($name) -or $lab -eq '02') { $expected[$name] = $want }
            }
        }
        foreach ($name in $expected.Keys) {
            $want = $expected[$name]
            $deployment = $deployments | Where-Object { $_.name -eq $name } | Select-Object -First 1
            $model = $deployment.properties.model
            $problems = @()
            if (!$deployment) { $problems += 'missing' }
            else {
                if ($deployment.properties.provisioningState -ne 'Succeeded') { $problems += "state $($deployment.properties.provisioningState)" }
                if ($want.Model -and ($model.name -ne $want.Model -or $model.version -ne $want.Version)) { $problems += "expected $($want.Model) $($want.Version)" }
                if ($want.Model -and $deployment.sku.name -notin $supportedSkus) { $problems += "type not supported by the template" }
                if ($want.Capacity -and $deployment.sku.capacity -ne $want.Capacity) { $problems += "expected capacity $($want.Capacity)" }
            }
            $shown = if ($deployment) { "$($model.name) $($model.version), $($deployment.sku.name), capacity $($deployment.sku.capacity), $($deployment.properties.provisioningState)" } else { 'missing' }
            Report ($problems.Count -eq 0) "Model deployment ${name} on ${foundry}: $shown$(if ($problems) { " ($($problems -join '; '))" })"
        }
        $foundryId = $labAccount[$labsHere[0]].id
        foreach ($lab in $labsHere) {
            $principal = Invoke-Az webapp identity show --resource-group $ResourceGroup --name $found[$lab].name --subscription $sub --query principalId -o tsv
            $roles = @(Invoke-Az role assignment list --assignee $principal --scope $foundryId --include-inherited --subscription $sub --query '[].roleDefinitionId' -o json | ConvertFrom-Json)
            Report (@($roles | Where-Object { $_ -like "*/$foundryUserRoleId" }).Count -gt 0) "$($labNames[$lab]): the app's identity holds Foundry User on $foundry"
        }
    }

    foreach ($clientId in @($clientIds | Select-Object -Unique)) {
        $redirects = @(Invoke-Az ad app show --id $clientId --query web.redirectUris -o json | ConvertFrom-Json)
        foreach ($lab in $labNames.Keys) {
            if ($auth[$lab].identityProviders.azureActiveDirectory.registration.clientId -ne $clientId) { continue }
            $callback = "https://$($found[$lab].host)/.auth/login/aad/callback"
            # Microsoft Entra ID matches the redirect path case-sensitively; the host is a DNS name. App Service uses the default port.
            $listed = @($redirects | Where-Object {
                    $parsed = $null
                    [uri]::TryCreate($_, [UriKind]::Absolute, [ref]$parsed) -and $parsed.Scheme -eq 'https' -and $parsed.IsDefaultPort -and $parsed.Host -eq $found[$lab].host -and
                    $parsed.AbsolutePath -ceq '/.auth/login/aad/callback' -and !$parsed.Query
                })
            Report ($listed.Count -gt 0) "$($labNames[$lab]): the sign-in registration lists $callback"
        }
    }

    foreach ($lab in $labNames.Keys) {
        $url = "https://$($found[$lab].host)/"
        $response = try { Invoke-WebRequest -Uri $url -MaximumRedirection 0 -SkipHttpErrorCheck -TimeoutSec 60 -ErrorAction SilentlyContinue } catch { $null }
        $location = if ($response) { @($response.Headers.Location)[0] } else { $null }
        $target = if ($location) { try { [uri]::new([uri]$url, $location) } catch { $null } }
        # App Service sends anonymous requests to the app's own sign-in endpoint, which hands over to Microsoft Entra ID.
        $redirected = $response.StatusCode -eq 302 -and $target -and $target.Scheme -eq 'https' -and $target.IsDefaultPort -and (
            ($target.Host -eq $found[$lab].host -and $target.AbsolutePath -eq '/.auth/login/aad') -or $target.Host -eq 'login.microsoftonline.com')
        $shown = if (!$response) { 'no response' } elseif ($target) { "HTTP $($response.StatusCode) to $($target.GetLeftPart([UriPartial]::Path))" } else { "HTTP $($response.StatusCode)" }
        Report $redirected "$($labNames[$lab]): an anonymous request to $url gets $shown (expected a redirect to sign-in)"
    }
}
finally {
    if ($originalAccount) { Invoke-Az account set --subscription $originalAccount -o none }
}
Write-Output ''
if ($script:failures) { Write-Output "$($script:failures) check(s) failed. Nothing was changed."; exit 1 }
Write-Output 'All platform checks passed. Nothing was changed. Sign in to each app and run one synthetic request to confirm live inference.'
