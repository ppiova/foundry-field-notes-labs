function Select-DeploymentAccount {
    param([Parameter(Mandatory)][string]$Subscription)
    $target = Invoke-Az account show --subscription $Subscription -o json | ConvertFrom-Json
    if (!$target.id -or !$target.tenantId) { throw 'The selected subscription must have an ID and tenant ID.' }
    # Microsoft Graph commands use the active CLI tenant, not an ARM --subscription argument.
    Invoke-Az account set --subscription $target.id -o none
    $active = Invoke-Az account show -o json | ConvertFrom-Json
    if ($active.id -ne $target.id -or $active.tenantId -ne $target.tenantId) {
        throw 'The active Azure CLI subscription and tenant do not match the deployment target.'
    }
    return $active
}
