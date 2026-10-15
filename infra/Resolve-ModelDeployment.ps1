function Resolve-ModelDeployment {
    # Model deployments on the Foundry resource can serve other labs. A redeployment keeps an existing deployment's
    # type and capacity unless the caller passed new values; only a new deployment uses the defaults.
    param(
        [object[]]$Existing,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Sku,
        [Parameter(Mandatory)] [int]$Capacity,
        [switch]$SkuChosen,
        [switch]$CapacityChosen
    )
    $current = @($Existing | Where-Object { $_.name -eq $Name })
    if ($current.Count -eq 0) { return [pscustomobject]@{ Name = $Name; Sku = $Sku; Capacity = $Capacity; Kept = $false } }
    $resolvedSku = if ($SkuChosen) { $Sku } else { [string]$current[0].sku }
    $resolvedCapacity = if ($CapacityChosen) { $Capacity } else { [int]$current[0].capacity }
    if ($resolvedSku -notin @('DataZoneStandard', 'GlobalStandard')) {
        throw "Deployment $Name uses $resolvedSku, which this template does not support. Stop before changing it."
    }
    if ($resolvedCapacity -lt 1) { throw "Deployment $Name reports no capacity. Pass its capacity explicitly." }
    return [pscustomobject]@{ Name = $Name; Sku = $resolvedSku; Capacity = $resolvedCapacity; Kept = $true }
}
