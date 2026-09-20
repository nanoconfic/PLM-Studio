param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][string]$Summary,
    [string[]]$Artifact,
    [string]$KnowledgeFacet='Auto'
)
. "$PSScriptRoot/../../scripts/Common.ps1"
$w=Get-Workspace; $ext=Get-Extension $w $Extension; $c=Initialize-ExtensionWorkflow $ext.Config
if ($c.lifecycle.status -eq 'Archived') { throw 'Archived extensions cannot be delivered.' }
$readinessIssues=@(Get-PrototypeReadinessIssues $w $c)
if ($readinessIssues.Count) { throw "Prototype readiness gate is not satisfied:`n- $($readinessIssues -join "`n- ")" }
if ($c.workflow.phase -notin @('Implementation','ChangesRequested','PendingUserReview')) { throw 'Prototype preflight must pass before delivery.' }
Write-Output 'Loading applicable knowledge for the delivery check before changing iteration state.'
& "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $Extension -Facet $KnowledgeFacet
$now=(Get-Date).ToUniversalTime().ToString('o')
$c.result.summary=$Summary; $c.result.artifacts=@($Artifact); $c.result.completed_at=$now
$c.validation.status='PendingUserReview'; $c.validation.requested_at=$now; $c.validation.responded_at=$null; $c.validation.feedback=$null
$c.workflow.phase='PendingUserReview'; $c.workflow.next_action='User checks the result and replies Accepted or ChangesRequested'
$c.status='PendingUserReview'
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Delivered $Extension / $($c.workflow.current_iteration). Please check:"
$i=0; foreach($criterion in @($c.requirements.acceptance_criteria)) { $i++; Write-Output "$i. $criterion" }
Write-Output 'Reply with: Accepted + feedback, or ChangesRequested + specific changes.'
