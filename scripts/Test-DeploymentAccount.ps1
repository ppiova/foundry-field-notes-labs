$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../infra/Resolve-HostingTier.ps1')
if ((Resolve-HostingTier -ExistingTiers @('B1')) -ne 'B1') { throw 'Redeployment would downgrade the shared paid plan.' }
if ((Resolve-HostingTier -ExistingTiers @()) -ne 'F1') { throw 'A fresh platform must default to the free tier.' }
foreach ($tiers in @(@('S1'), @('F1','B1'))) {
    $rejected = $false
    try { Resolve-HostingTier -ExistingTiers $tiers | Out-Null } catch { $rejected = $true }
    if (!$rejected) { throw 'Ambiguous or unsupported hosting tier was not rejected.' }
}
Write-Output 'PASS: Shared hosting tier is preserved; ambiguous and unsupported plans stop deployment'
. (Join-Path $PSScriptRoot '../infra/Resolve-ModelDeployment.ps1')
$deployed = @(
    [pscustomobject]@{ name = 'decision-1'; sku = 'DataZoneStandard'; capacity = 300 },
    [pscustomobject]@{ name = 'gpt-6-luna'; sku = 'GlobalStandard'; capacity = 100 })
$kept = Resolve-ModelDeployment -Existing $deployed -Name 'gpt-6-luna' -Sku 'DataZoneStandard' -Capacity 50
if (!$kept.Kept -or $kept.Sku -ne 'GlobalStandard' -or $kept.Capacity -ne 100) { throw 'Redeployment would change a shared model deployment.' }
$chosen = Resolve-ModelDeployment -Existing $deployed -Name 'decision-1' -Sku 'GlobalStandard' -Capacity 50 -CapacityChosen
if ($chosen.Capacity -ne 50 -or $chosen.Sku -ne 'DataZoneStandard') { throw 'An explicit capacity was ignored, or the type changed without being chosen.' }
$fresh = Resolve-ModelDeployment -Existing @() -Name 'gpt-6-luna' -Sku 'DataZoneStandard' -Capacity 50
if ($fresh.Kept -or $fresh.Sku -ne 'DataZoneStandard' -or $fresh.Capacity -ne 50) { throw 'A new deployment must use the defaults.' }
$rejected = $false
try { Resolve-ModelDeployment -Existing @([pscustomobject]@{ name = 'decision-1'; sku = 'Standard'; capacity = 10 }) -Name 'decision-1' -Sku 'DataZoneStandard' -Capacity 50 | Out-Null }
catch { $rejected = $true }
if (!$rejected) { throw 'An unsupported deployment type was not rejected.' }
Write-Output 'PASS: Existing model deployments keep their type and capacity unless chosen; unsupported types stop deployment'
. (Join-Path $PSScriptRoot '../infra/Resolve-FederatedCredential.ps1')
$issuer = 'https://login.microsoftonline.com/tenant-1/v2.0'
$subscriptionId = '12345678-aaaa-bbbb-cccc-1234567890ab'
$name = Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup 'rg-labs.(test)'
if ($name -notmatch '^platform-rg-labs--test--[0-9a-f]{12}$') { throw "Unexpected platform credential name: $name" }
$long = Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup ('r' * 200)
if ($long.Length -ne 120 -or $long -notmatch '-[0-9a-f]{12}$') { throw "A long credential name was not cut to 120 characters around its hash: $long" }
# Groups that read the same after cleanup or truncation get different names; one group in another case does not.
$dot = Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup 'rg-labs.prod'
$dash = Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup 'rg-labs-prod'
if ($dot -eq $dash) { throw "rg-labs.prod and rg-labs-prod share the credential name $dot." }
if ((Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup ('r' * 200 + 'a')) -eq (Get-PlatformCredentialName -SubscriptionId $subscriptionId -ResourceGroup ('r' * 200 + 'b'))) {
    throw 'Groups that differ only after truncation share a credential name.'
}
if ((Get-PlatformCredentialName -SubscriptionId $subscriptionId.ToUpperInvariant() -ResourceGroup 'RG-Labs-Prod') -ne $dash) { throw 'The same group in another case got another credential name.' }
$exchange = @('api://AzureADTokenExchange')
$collidingPlatform = [pscustomobject]@{ id = 'fic-dot'; name = $dot; issuer = $issuer; subject = 'identity-dot'; audiences = $exchange }
$next = Resolve-FederatedCredential -Existing @($collidingPlatform) -Desired @{ name = $dash; issuer = $issuer; subject = 'identity-dash'; audiences = $exchange }
if ($next.Action -ne 'create') { throw "A platform whose group reads the same after cleanup would replace the other's trust: $($next.Action)." }
$desired = @{ name = $name; issuer = $issuer; subject = 'identity-new'; audiences = $exchange }
$otherPlatform = [pscustomobject]@{ id = 'fic-other'; name = 'platform-rg-other-0123456789ab'; issuer = $issuer; subject = 'identity-other'; audiences = $exchange }
$legacy = [pscustomobject]@{ id = 'fic-legacy'; name = 'app-service-sign-in'; issuer = $issuer; subject = 'identity-new'; audiences = $exchange }
$recreated = [pscustomobject]@{ id = 'fic-own'; name = $name; issuer = $issuer; subject = 'identity-deleted'; audiences = $exchange }
if ((Resolve-FederatedCredential -Existing @() -Desired $desired).Action -ne 'create') { throw 'A first platform did not get a credential.' }
$beside = Resolve-FederatedCredential -Existing @($otherPlatform) -Desired $desired
if ($beside.Action -ne 'create') { throw "Another platform's credential would be replaced instead of kept: $($beside.Action)." }
if ((Resolve-FederatedCredential -Existing @($otherPlatform, $legacy) -Desired $desired).Action -ne 'none') { throw 'A credential that already trusts this identity was not reused.' }
$own = Resolve-FederatedCredential -Existing @($otherPlatform, $recreated) -Desired $desired
if ($own.Action -ne 'update' -or $own.Id -ne 'fic-own') { throw 'A recreated platform did not update only its own credential.' }
# A credential that trusts the identity for another audience cannot sign in: repair this platform's, stop on another's.
$ownWrongAudience = [pscustomobject]@{ id = 'fic-own'; name = $name; issuer = $issuer; subject = 'identity-new'; audiences = @('api://other') }
$repair = Resolve-FederatedCredential -Existing @($ownWrongAudience) -Desired $desired
if ($repair.Action -ne 'update' -or $repair.Id -ne 'fic-own') { throw "This platform's credential with another audience was not repaired: $($repair.Action)." }
$lowercase = [pscustomobject]@{ id = 'fic-own'; name = $name; issuer = $issuer; subject = 'identity-new'; audiences = @('api://azureadtokenexchange') }
if ((Resolve-FederatedCredential -Existing @($lowercase) -Desired $desired).Action -ne 'update') { throw 'An audience that differs only in case was accepted instead of repaired.' }
$conflict = $null
try { Resolve-FederatedCredential -Existing @([pscustomobject]@{ id = 'fic-x'; name = 'manual'; issuer = $issuer; subject = 'identity-new'; audiences = @('api://other') }) -Desired $desired | Out-Null }
catch { $conflict = $_.Exception.Message }
if ($conflict -notlike "*'manual' already trusts this platform's sign-in identity, but for audiences 'api://other'*") { throw "Another credential with the wrong audience was accepted or reported unclearly: $conflict" }
Write-Output "PASS: Each platform keeps its own federated credential with the sign-in audience; another platform's trust is never replaced"
. (Join-Path $PSScriptRoot '../infra/Select-DeploymentAccount.ps1')
$script:active = @{ id = 'original-subscription'; tenantId = 'original-tenant' }
$script:target = @{ id = 'target-subscription'; tenantId = 'target-tenant' }
$script:ignoreSelection = $false
function Invoke-Az {
    if ($args[0] -ne 'account') { throw 'Unexpected command in offline test.' }
    if ($args[1] -eq 'set') {
        if (!$script:ignoreSelection) { $script:active = $script:target }
    } elseif ($args -contains '--subscription') { $script:target | ConvertTo-Json }
    else { $script:active | ConvertTo-Json }
}
$selected = Select-DeploymentAccount -Subscription 'target-subscription'
if ($selected.tenantId -ne 'target-tenant') { throw 'Cross-tenant selection failed.' }
Write-Output 'PASS: Deployment selects the target subscription and tenant before Graph commands'
$script:ignoreSelection = $true
$script:active = @{ id = 'original-subscription'; tenantId = 'original-tenant' }
$rejected = $false
try { Select-DeploymentAccount -Subscription 'target-subscription' | Out-Null }
catch { $rejected = $_.Exception.Message -like '*do not match*' }
if (!$rejected) { throw 'Mismatched active tenant was not rejected.' }
Write-Output 'PASS: Deployment stops when the active tenant does not match'
