param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][ValidateSet('Accepted','ChangesRequested')][string]$Result,
    [Parameter(Mandatory=$true)][string]$Feedback
)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace; $ext=Get-Extension $w $Extension; $c=Initialize-ExtensionWorkflow $ext.Config
Assert-ControllerAction $w $c 'review' | Out-Null
$now=(Get-Date).ToUniversalTime().ToString('o')
$c.validation.status=$Result; $c.validation.responded_at=$now; $c.validation.feedback=$Feedback
if ($Result -eq 'Accepted') {
    if ($c.workflow.capability_mode -eq 'linked' -and $c.workflow.stage -eq 'prototype') {
        $c.result.prototype_review=[ordered]@{status='Accepted';responded_at=$now;feedback=$Feedback;summary=$c.result.summary;artifacts=@($c.result.artifacts)}
        $html=@($c.result.artifacts | Where-Object { $_ -match '(?i)\.html?$' })
        if ($html.Count) { $c.integration_requirements.source_artifact=$html[0]; $c.integration_requirements.source_kind='extension' }
        $c.workflow.prototype_accepted=$true; $c.workflow.stage='integration'; $c.workflow.phase='Requirements'
        $c.workflow.requirements_confirmed=$false
        $c.workflow.next_action='Collect and confirm integration requirements for the accepted prototype'
        $c.validation=New-ValidationState
        $c.status='Requirements'
    } else {
        $c.workflow.phase='Completed'; $c.workflow.next_action='A new modification starts the next iteration'; $c.status='Completed'
    }
} else {
    $c.workflow.phase='ChangesRequested'; $c.workflow.next_action='Apply user feedback and request review again'; $c.status='ChangesRequested'
}
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Closed review as $Result for $Extension / $($c.workflow.current_iteration). The extension remains Active and selectable."
