param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][ValidateSet('Accepted','ChangesRequested')][string]$Result,
    [Parameter(Mandatory=$true)][string]$Feedback
)
. "$PSScriptRoot/../../scripts/Common.ps1"
$w=Get-Workspace; $ext=Get-Extension $w $Extension; $c=Initialize-ExtensionWorkflow $ext.Config
$now=(Get-Date).ToUniversalTime().ToString('o')
$c.validation.status=$Result; $c.validation.responded_at=$now; $c.validation.feedback=$Feedback
if ($Result -eq 'Accepted') {
    $c.workflow.phase='Completed'; $c.workflow.next_action='A new modification starts the next iteration'; $c.status='Completed'
} else {
    $c.workflow.phase='ChangesRequested'; $c.workflow.next_action='Apply user feedback and request review again'; $c.status='ChangesRequested'
}
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Closed review as $Result for $Extension / $($c.workflow.current_iteration). The extension remains Active and selectable."
