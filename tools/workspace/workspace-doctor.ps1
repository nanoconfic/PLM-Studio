param([string]$Extension)
. "$PSScriptRoot/../../tools/config/Common.ps1"
try {
    $w=Get-Workspace
    $e=$null
    if ($Extension) { $e=(Get-Extension $w $Extension).Config }
    $issues=@(Get-Issues $w $e)
    if ($issues.Count) { $issues | Write-Output; exit 2 }
    if ($Extension) { Write-Output "OK: workspace $($w.Id) / extension $Extension / profile $($e.profile) / $($e.delivery.mode)" }
    else { Write-Output "OK: workspace $($w.Id) / profiles $((Get-ConfiguredProfileNames $w) -join ', ')" }
} catch { Write-Output $_.Exception.Message; exit 2 }
