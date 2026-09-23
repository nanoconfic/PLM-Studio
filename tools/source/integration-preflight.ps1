param([Parameter(Mandatory=$true)][string]$Extension)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace
$ext=Get-Extension $w $Extension
$c=Initialize-ExtensionWorkflow $ext.Config
$issues=@(Get-IntegrationReadinessIssues $w $c)
if ($issues.Count) {
    Write-Output "Integration preflight failed for ${Extension}:"
    $issues | ForEach-Object { Write-Output "- $_" }
    exit 2
}
Assert-ControllerAction $w $c 'preflight' | Out-Null
Write-Output 'Loading integration, environment and business knowledge before implementation.'
& "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $Extension -Facet 'Integration,Environment,Business'
$c.workflow.phase='Implementation'
$c.workflow.next_action='Embed the confirmed HTML artifact within the approved paths; record backup, hash, diff, verification and rollback.'
$c.status='Implementation'
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Integration preflight passed for $Extension / $($c.workflow.current_iteration)."
