function Resolve-HostingTier {
    param([string[]]$ExistingTiers)
    if ($ExistingTiers.Count -gt 1) { throw 'Multiple shared plans found. Specify -AppServiceSku explicitly.' }
    $tier = if ($ExistingTiers.Count -eq 1) { $ExistingTiers[0] } else { 'F1' }
    if ($tier -notin @('F1', 'B1')) { throw 'The existing plan tier is not supported by this template. Stop before changing it.' }
    return $tier
}
