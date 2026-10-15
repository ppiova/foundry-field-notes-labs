#Requires -Version 7.0
<#
.SYNOPSIS
Deploys the lab platform and the labs you select to your own Azure subscription and Microsoft Entra tenant. Only the
account that runs this script can open the apps.

.DESCRIPTION
1. Publishes a self-contained linux-x64 build of each selected lab with a locked restore, before anything is created.
2. Creates or reuses a single-tenant app registration for App Service sign-in, without a client secret.
3. Deploys infra/main.bicep at subscription scope: the resource group, the shared platform (Foundry resource,
   Microsoft-Decision-1 and chat model deployments, App Service plan, sign-in identity) and each selected lab. A
   redeployment keeps the plan's tier and each existing model deployment's type and capacity unless you pass new values.
4. Adds each app's redirect URI to the app registration, keeping existing ones, and trusts the platform's sign-in
   managed identity through the platform's own federated identity credential, so platforms that share a registration
   keep each other's trust.
5. Uploads each lab's build to its web app.

-WhatIfOnly runs the same reads and shows Azure what-if for the template, then stops. It creates and changes nothing,
also when the resource group does not exist yet.

Run it from any directory after az login. Nothing is read from or written to the repository except the lab builds.
#>
[CmdletBinding()]
param(
    # Name or ID of the subscription you chose. Required on purpose: the CLI default is never assumed.
    [Parameter(Mandatory)] [string]$Subscription,
    [string]$ResourceGroup = 'rg-foundry-field-notes-labs',
    # Used only when the resource group does not exist yet; an existing group keeps its region.
    [string]$Location = 'eastus2',
    # Lab numbers. 1 and 2 work too, because PowerShell reads an unquoted list such as 01,02 as numbers.
    [ValidatePattern('^0?[12]$')] [string[]]$Labs = @('01', '02'),
    [ValidateRange(1, 1000)] [int]$DecisionCapacity = 50,
    [ValidateSet('DataZoneStandard', 'GlobalStandard')] [string]$DecisionSku = 'DataZoneStandard',
    # Chat model (gpt-6-luna) capacity in thousands of tokens per minute.
    [ValidateRange(1, 1000)] [int]$ChatCapacity = 50,
    [ValidateSet('DataZoneStandard', 'GlobalStandard')] [string]$ChatSku = 'DataZoneStandard',
    # Preserve the plan's tier on redeployment unless the caller explicitly selects a new one.
    [ValidateSet('F1', 'B1')] [string]$AppServiceSku,
    # Reuse this app registration (client ID). Without it, the script reuses the registration the group's lab apps
    # already use, or creates one. It never selects a registration by name.
    [string]$AuthClientId,
    # Preview the template's changes with Azure what-if and stop. Nothing is created or changed.
    [switch]$WhatIfOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Select-DeploymentAccount.ps1')
. (Join-Path $PSScriptRoot 'Resolve-HostingTier.ps1')
. (Join-Path $PSScriptRoot 'Resolve-ModelDeployment.ps1')
. (Join-Path $PSScriptRoot 'Resolve-FederatedCredential.ps1')

function Invoke-Az {
    $output = & az @args
    if ($LASTEXITCODE -ne 0) { throw "az $($args[0]) $($args[1]) failed. See the error above." }
    $output
}

# Deployment names in infra/main.bicep; Test-AzureScripts.ps1 keeps them in sync.
$decisionDeployment = 'decision-1'
$chatDeployment = 'gpt-6-luna'
$registrationName = 'Foundry Field Notes Labs sign-in'
# Shown to what-if when no registration exists yet; never deployed.
$placeholderClientId = '00000000-0000-0000-0000-000000000000'
$catalog = [ordered]@{
    '01' = @{ Title = 'Lab 001 Support Signal'; Project = 'samples/01-support-signal/src/SupportSignal' }
    '02' = @{ Title = 'Lab 002 Bid Review Queue'; Project = 'samples/02-bid-review-queue/src/BidReviewQueue' }
}
$Labs = @($Labs | ForEach-Object { '{0:D2}' -f [int]$_ } | Select-Object -Unique | Sort-Object)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dotnet = & (Join-Path $repoRoot 'scripts/Test-Prerequisites.ps1') -Azure -SkipSdk:$WhatIfOnly
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work = [IO.Path]::GetFullPath((Join-Path $tempRoot "foundry-field-notes-deploy-$([guid]::NewGuid().ToString('N'))"))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$originalAccount = Invoke-Az account show --query id -o tsv

try {
    $account = Select-DeploymentAccount -Subscription $Subscription
    $sub = $account.id
    $userId = Invoke-Az ad signed-in-user show --query id -o tsv
    Write-Host "Subscription: $($account.name). Only the signed-in user ($userId) will be allowed to open the apps."
    Write-Host "Labs: $($Labs -join ', ')."

    # Everything below reads the group only if it exists; a fresh platform has nothing to keep. Every read names its
    # output format, so a user's Azure CLI default (even "none") cannot hide an existing platform.
    $groupExists = (Invoke-Az group exists --name $ResourceGroup --subscription $sub -o tsv) -eq 'true'
    $tiers = @(); $modelDeployments = @(); $foundryAccountName = $null; $clientIds = @(); $sites = @()
    if ($groupExists) {
        # Azure compares group names case-insensitively, but the template derives the web app suffix from the name it
        # receives. Use the name as Azure stored it, so another capitalization cannot create a second set of apps.
        $group = Invoke-Az group show --name $ResourceGroup --subscription $sub --query '{name: name, location: location}' -o json | ConvertFrom-Json
        $ResourceGroup = $group.name
        $Location = $group.location
        Write-Host "Resource group ${ResourceGroup}: existing, in $Location."
        $shared = "[?tags.project=='foundry-field-notes' && tags.scope=='shared']"
        $tiers = @(Invoke-Az appservice plan list --resource-group $ResourceGroup --subscription $sub --query "$shared.sku.name" -o json | ConvertFrom-Json)
        $accounts = @(Invoke-Az cognitiveservices account list --resource-group $ResourceGroup --subscription $sub --query "$shared.name" -o json | ConvertFrom-Json)
        if ($accounts.Count -gt 1) { throw 'This resource group has more than one shared Foundry resource. Stop before changing either.' }
        if ($accounts.Count -eq 1) {
            $foundryAccountName = $accounts[0]
            Write-Host "Reusing Foundry resource $foundryAccountName."
            $modelDeployments = @(Invoke-Az cognitiveservices account deployment list --resource-group $ResourceGroup --name $foundryAccountName `
                --subscription $sub --query '[].{name: name, sku: sku.name, capacity: sku.capacity}' -o json | ConvertFrom-Json)
        }
        $sites = @(Invoke-Az webapp list --resource-group $ResourceGroup --subscription $sub `
            --query "[?tags.project=='foundry-field-notes' && tags.lab].id" -o json | ConvertFrom-Json)
        foreach ($site in $sites) {
            $clientIds += Invoke-Az rest --method get --url "https://management.azure.com$site/config/authsettingsV2?api-version=2024-04-01" `
                --query properties.identityProviders.azureActiveDirectory.registration.clientId -o tsv
        }
        $clientIds = @($clientIds | Where-Object { $_ } | Select-Object -Unique)
    }
    else { Write-Host "Resource group ${ResourceGroup}: new, in $Location." }

    if (!$PSBoundParameters.ContainsKey('AppServiceSku')) {
        $AppServiceSku = Resolve-HostingTier -ExistingTiers $tiers
        Write-Host $(if ($tiers.Count -gt 0) { "Preserving hosting tier: $AppServiceSku." } else { "Hosting tier: $AppServiceSku (new plan)." })
    }
    else { Write-Host "Hosting tier: $AppServiceSku (chosen)." }

    # Azure refuses to move a plan to F1 while an app on it keeps Always On, and the template changes the plan before
    # the apps, so stop before changing anything.
    if ($AppServiceSku -eq 'F1' -and $tiers -contains 'B1') {
        $alwaysOn = @($sites | Where-Object { (Invoke-Az webapp config show --ids $_ --query alwaysOn -o tsv) -eq 'true' })
        if ($alwaysOn.Count -gt 0) {
            throw "Moving the plan from B1 to F1 fails while these apps keep Always On: $(($alwaysOn | ForEach-Object { $_.Split('/')[-1] }) -join ', '). Turn it off first with az webapp config set --ids <app-id> --always-on false, then run this script again."
        }
    }

    # Several labs call the model deployments, so keep their type and capacity unless chosen here. Microsoft-Decision-1
    # is deployed only with Lab 002, so its existing settings are read only then; otherwise the template ignores them.
    $decisionModel = if ('02' -in $Labs) {
        Resolve-ModelDeployment -Existing $modelDeployments -Name $decisionDeployment -Sku $DecisionSku -Capacity $DecisionCapacity `
            -SkuChosen:($PSBoundParameters.ContainsKey('DecisionSku')) -CapacityChosen:($PSBoundParameters.ContainsKey('DecisionCapacity'))
    }
    else { [pscustomobject]@{ Name = $decisionDeployment; Sku = $DecisionSku; Capacity = $DecisionCapacity; Kept = $false } }
    $chatModel = Resolve-ModelDeployment -Existing $modelDeployments -Name $chatDeployment -Sku $ChatSku -Capacity $ChatCapacity `
        -SkuChosen:($PSBoundParameters.ContainsKey('ChatSku')) -CapacityChosen:($PSBoundParameters.ContainsKey('ChatCapacity'))
    # The template deploys Microsoft-Decision-1 only with Lab 002, so Lab 001 alone needs no quota for it.
    foreach ($model in @(if ('02' -in $Labs) { $decisionModel }) + @($chatModel)) {
        $origin = if ($model.Kept) { 'existing deployment' } else { 'new deployment' }
        Write-Host "Model deployment $($model.Name): $($model.Sku), capacity $($model.Capacity) ($origin)."
    }

    # App registration for App Service sign-in. Display names are not unique, so reuse follows explicit IDs only.
    if (!$AuthClientId -and $clientIds.Count -gt 1) {
        throw "The lab apps in this resource group use different app registrations ($($clientIds -join ', ')). Pass -AuthClientId."
    }
    $appId = if ($AuthClientId) { $AuthClientId } elseif ($clientIds.Count -eq 1) { $clientIds[0] }
    if ($appId) {
        $appId = Invoke-Az ad app show --id $appId --query appId -o tsv
        Write-Host "Reusing app registration $appId."
    }
    elseif ($WhatIfOnly) {
        Write-Host "No app registration yet. A deployment would create '$registrationName'; this preview uses a placeholder client ID."
        $appId = $placeholderClientId
    }

    if (!$WhatIfOnly) {
        # Build first: a failed build must not leave half a deployment behind. The SDK follows global.json from the
        # working directory, so publish from the repository root, as Test-Prerequisites.ps1 checked it.
        Push-Location $repoRoot
        try {
            foreach ($lab in $Labs) {
                Write-Host "Publishing $($catalog[$lab].Title)..."
                # Locked restore: an out-of-date packages.lock.json fails the deployment instead of being regenerated.
                & $dotnet publish (Join-Path $repoRoot $catalog[$lab].Project) -c Release -r linux-x64 --self-contained -o (Join-Path $work "publish-$lab") --nologo -v q -p:RestoreLockedMode=true
                if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $($catalog[$lab].Title). Nothing was deployed." }
                Compress-Archive -Path (Join-Path $work "publish-$lab/*") -DestinationPath (Join-Path $work "app-$lab.zip") -Force
            }
        }
        finally { Pop-Location }
        if (!$appId) {
            $appId = Invoke-Az ad app create --display-name $registrationName --sign-in-audience AzureADMyOrg --enable-id-token-issuance true --query appId -o tsv
            Write-Host "Created app registration '$registrationName' ($appId). If this deployment fails, rerun with -AuthClientId $appId to reuse it."
        }
        Invoke-Az ad app update --id $appId --identifier-uris "api://$appId" -o none
    }

    $parameters = @{
        resourceGroupName = @{ value = $ResourceGroup }
        location = @{ value = $Location }
        labs = @{ value = $Labs }
        authClientId = @{ value = $appId }
        allowedPrincipalIds = @{ value = @($userId) }
        developerPrincipalId = @{ value = $userId }
        decisionCapacity = @{ value = $decisionModel.Capacity }
        decisionSku = @{ value = $decisionModel.Sku }
        chatCapacity = @{ value = $chatModel.Capacity }
        chatSku = @{ value = $chatModel.Sku }
        appServiceSku = @{ value = $AppServiceSku }
    }
    if ($foundryAccountName) { $parameters.foundryAccountName = @{ value = $foundryAccountName } }
    $parameterFile = Join-Path $work 'parameters.json'
    @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $parameters } |
        ConvertTo-Json -Depth 6 | Set-Content -Path $parameterFile -Encoding utf8
    $template = Join-Path $PSScriptRoot 'main.bicep'
    if ($WhatIfOnly) {
        Write-Host 'Previewing infrastructure changes (what-if). Nothing is deployed.'
        Invoke-Az deployment sub what-if --location $Location --subscription $sub --template-file $template --parameters "@$parameterFile"
        return
    }

    Write-Host 'Deploying the platform and labs (Bicep)...'
    $outputs = Invoke-Az deployment sub create --location $Location --subscription $sub --name "foundry-field-notes-labs-$(Get-Date -Format yyyyMMddHHmmss)" `
        --template-file $template --parameters "@$parameterFile" --query properties.outputs -o json | ConvertFrom-Json
    $webApps = @($outputs.webApps.value)

    # Redirect URIs and the federated identity credential that replaces a client secret. Keep every existing callback.
    $existingRedirects = @(Invoke-Az ad app show --id $appId --query web.redirectUris -o json | ConvertFrom-Json)
    $redirects = @(@($existingRedirects) + @($webApps | ForEach-Object { "https://$($_.hostName)/.auth/login/aad/callback" }) | Where-Object { $_ } | Select-Object -Unique)
    Invoke-Az ad app update --id $appId --web-redirect-uris @redirects -o none
    # Each platform keeps its own credential, so platforms that share a registration never replace each other's trust.
    $desired = @{
        name = Get-PlatformCredentialName -SubscriptionId $sub -ResourceGroup $ResourceGroup
        issuer = "https://login.microsoftonline.com/$($account.tenantId)/v2.0"
        subject = $outputs.signInIdentityPrincipalId.value
        audiences = @('api://AzureADTokenExchange')
        description = "App Service sign-in for the lab platform in resource group $ResourceGroup, through its sign-in managed identity instead of a client secret."
    }
    $fic = Join-Path $work 'federated-credential.json'
    $desired | ConvertTo-Json | Set-Content -Path $fic -Encoding utf8
    $credentials = @(Invoke-Az ad app federated-credential list --id $appId -o json | ConvertFrom-Json)
    $credential = Resolve-FederatedCredential -Existing $credentials -Desired $desired
    if ($credential.Action -eq 'create') {
        Invoke-Az ad app federated-credential create --id $appId --parameters "@$fic" -o none
        Write-Host "Added federated identity credential $($credential.Name) for this platform's sign-in identity."
    }
    elseif ($credential.Action -eq 'update') {
        # This platform was recreated and has a new sign-in identity; its old identity went with it.
        Invoke-Az ad app federated-credential update --id $appId --federated-credential-id $credential.Id --parameters "@$fic" -o none
        Write-Host "Updated federated identity credential $($credential.Name) to trust this platform's current sign-in identity."
    }

    foreach ($app in $webApps) {
        Write-Host "Uploading $($catalog[$app.lab].Title) to $($app.name)..."
        # The upload waits for the deployment itself. Startup tracking is off: on 2026-10-14 Azure CLI 2.85.0 kept
        # reporting "Starting the site" for minutes after the container had started, because the site's deployment
        # status list stayed empty. Test-AzureLabs.ps1 checks the running apps instead.
        Invoke-Az webapp deploy --resource-group $ResourceGroup --name $app.name --subscription $sub --src-path (Join-Path $work "app-$($app.lab).zip") `
            --type zip --track-status false -o none
    }

    Write-Host ''
    foreach ($app in $webApps) { Write-Host "$($catalog[$app.lab].Title): https://$($app.hostName)" }
    $checkCommand = "./scripts/Test-AzureLabs.ps1 -Subscription '$Subscription' -ResourceGroup '$ResourceGroup' -Labs $($Labs -join ',')" +
        $(if ('02' -in $Labs) { " -DecisionCapacity $($decisionModel.Capacity)" }) + " -ChatCapacity $($chatModel.Capacity)"
    Write-Host 'Each app can take a minute or two to start. Then check the labs you deployed, from the repository root:'
    Write-Host "  $checkCommand"
    Write-Host 'Sign in with the account that ran this script.'
    Write-Host 'Confirm live inference with one synthetic request per app; a successful deployment is not evidence of it.'
}
finally {
    if ([IO.Path]::GetDirectoryName($work) -ne $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) {
        throw 'Refusing to remove a deployment directory outside the temporary directory.'
    }
    Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
    if ($originalAccount) { Invoke-Az account set --subscription $originalAccount -o none }
}
