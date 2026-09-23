param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][string]$Summary,
    [string[]]$Artifact,
    [string]$KnowledgeFacet='Auto'
)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace; $ext=Get-Extension $w $Extension; $c=Initialize-ExtensionWorkflow $ext.Config
if ($c.lifecycle.status -eq 'Archived') { throw 'Archived extensions cannot be delivered.' }
$integrationStage=($c.workflow.stage -eq 'integration' -and $c.workflow.capability_mode -in @('integration','linked'))
$readinessIssues=$(if ($integrationStage) {@(Get-IntegrationReadinessIssues $w $c)} else {@(Get-PrototypeReadinessIssues $w $c)})
if (@($readinessIssues).Count) { throw "Readiness gate is not satisfied:`n- $(@($readinessIssues) -join "`n- ")" }
if ($c.workflow.phase -notin @('Implementation','ChangesRequested','PendingUserReview')) { throw 'Prototype preflight must pass before delivery.' }
Assert-ControllerAction $w $c 'deliver' | Out-Null
if ($integrationStage) {
    $evidenceIssues=@(Get-IntegrationEvidenceIssues $w $c)
    if ($evidenceIssues.Count) { throw "Integration evidence is incomplete:`n- $($evidenceIssues -join "`n- ")" }
} elseif ($c.workflow.capability_mode -in @('prototype','linked')) {
    $html=@($Artifact | Where-Object { $_ -match '(?i)\.html?$' })
    if (!$html.Count) { throw 'Prototype delivery requires an HTML artifact.' }
    foreach($item in $html) {
        $path=$(if ([IO.Path]::IsPathRooted($item)) {$item} else {Join-Path $ext.Path $item})
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Prototype HTML artifact does not exist: $item" }
    }
}
Write-Output 'Loading applicable knowledge for the delivery check before changing iteration state.'
if ($KnowledgeFacet -eq 'Auto' -and $integrationStage) { $KnowledgeFacet='Integration,Environment,Business' }
elseif ($KnowledgeFacet -eq 'Auto' -and $c.workflow.capability_mode -in @('prototype','linked')) { $KnowledgeFacet='Style,Business,Data' }
& "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $Extension -Facet $KnowledgeFacet
$now=(Get-Date).ToUniversalTime().ToString('o')
$c.result.summary=$Summary; $c.result.artifacts=@($Artifact); $c.result.completed_at=$now
$c.validation.status='PendingUserReview'; $c.validation.requested_at=$now; $c.validation.responded_at=$null; $c.validation.feedback=$null
$c.workflow.phase='PendingUserReview'; $c.workflow.next_action='User checks the result and replies Accepted or ChangesRequested'
$c.status='PendingUserReview'
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Delivered $Extension / $($c.workflow.current_iteration). Please check:"
$criteria=$(if ($integrationStage) {@($c.integration_requirements.acceptance_criteria)} else {@($c.requirements.acceptance_criteria)})
$i=0; foreach($criterion in $criteria) { $i++; Write-Output "$i. $criterion" }
Write-Output 'Reply with: Accepted + feedback, or ChangesRequested + specific changes.'
