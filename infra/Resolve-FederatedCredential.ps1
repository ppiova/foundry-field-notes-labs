function Resolve-FederatedCredential {
    # One federated identity credential per lab platform. A platform deployed with another platform's registration adds
    # its own trust instead of replacing the other platform's, and a recreated platform replaces only its own. A
    # credential counts only if its issuer, subject and audiences all match what App Service sign-in needs. Microsoft
    # Entra ID matches them case-sensitively, so the comparisons here do too.
    param(
        [object[]]$Existing,
        [Parameter(Mandatory)] [hashtable]$Desired
    )
    $audiences = (@($Desired.audiences) | Sort-Object -CaseSensitive) -join ' '
    $same = @($Existing | Where-Object { $_.issuer -ceq $Desired.issuer -and $_.subject -ceq $Desired.subject })
    $ready = @($same | Where-Object { ((@($_.audiences) | Sort-Object -CaseSensitive) -join ' ') -ceq $audiences })
    if ($ready.Count -gt 0) { return [pscustomobject]@{ Action = 'none'; Id = $ready[0].id; Name = $ready[0].name } }
    $own = @($Existing | Where-Object { $_.name -eq $Desired.name })
    if ($own.Count -gt 0) { return [pscustomobject]@{ Action = 'update'; Id = $own[0].id; Name = $own[0].name } }
    if ($same.Count -gt 0) {
        throw "Federated credential '$($same[0].name)' already trusts this platform's sign-in identity, but for audiences '$((@($same[0].audiences)) -join ', ')' instead of '$($audiences)'. Correct its audience or delete it in the app registration, then run the script again."
    }
    [pscustomobject]@{ Action = 'create'; Id = $null; Name = $Desired.name }
}

function Get-PlatformCredentialName {
    # Names allow letters, digits, '-' and '_', up to 120 characters. The readable part can collide after cleanup
    # (rg-labs.prod and rg-labs-prod) or truncation, so a hash of the exact subscription ID and group keeps names
    # unique. Azure treats both case-insensitively, and so does the hash.
    param([Parameter(Mandatory)] [string]$SubscriptionId, [Parameter(Mandatory)] [string]$ResourceGroup)
    $bytes = [Text.Encoding]::UTF8.GetBytes("$SubscriptionId/$ResourceGroup".ToLowerInvariant())
    # SHA256.HashData needs .NET 5; PowerShell 7.0, the scripts' minimum, runs on .NET Core 3.1.
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    $hash = -join ($digest[0..5] | ForEach-Object { $_.ToString('x2') })
    $readable = $ResourceGroup -replace '[^A-Za-z0-9_-]', '-'
    $readable = $readable.Substring(0, [Math]::Min($readable.Length, 120 - 'platform--'.Length - $hash.Length))
    "platform-$readable-$hash"
}
