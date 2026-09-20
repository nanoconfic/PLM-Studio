param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [ValidateSet('Auto','Resume','NewIteration')][string]$Action='Auto'
)
. "$PSScriptRoot/../../scripts/Common.ps1"
$w=Get-Workspace; $ext=Get-Extension $w $Extension; $c=Initialize-ExtensionWorkflow $ext.Config
$state=Get-ExtensionGuideState $w $c
if ($state.lifecycle -eq 'Archived') { throw "$Extension is archived. Restore it to Active before modification." }
$startNew=($Action -eq 'NewIteration') -or ($Action -eq 'Auto' -and $state.next_action -eq 'StartNewIteration')
if ($startNew) {
    $current=[string]$c.workflow.current_iteration
    if ($current -notmatch '^ITER-(\d+)$') { $current='ITER-001'; $number=1 } else { $number=[int]$Matches[1] }
    $history=@($c.iteration_history)
    $history+=@([ordered]@{
        id=$current;archived_at=(Get-Date).ToUniversalTime().ToString('o');requirements=$c.requirements
        validation=$c.validation;knowledge_capture=$c.knowledge_capture;style_context=$c.style_context;result=$c.result;final_status=$c.status
    })
    $next='ITER-{0:D3}' -f ($number+1)
    $c.iteration_history=$history
    $c.requirements=New-RequirementState
    $c.validation=New-ValidationState
    $c.knowledge_capture=New-KnowledgeCaptureState
    $c.style_context=New-StyleContextState
    $c.result=[ordered]@{summary=$null;artifacts=@();completed_at=$null}
    $c.workflow=[ordered]@{
        current_iteration=$next;phase='Requirements'
        delivery_confirmed=([string]$c.delivery.mode -in @('static','static-demo','embedded-static','backend'))
        requirements_confirmed=$false;next_action='Collect and confirm prototype design requirements; do not implement yet'
    }
    $c.status='Requirements'
    Write-Config (Join-Path $ext.Path 'extension.yaml') $c
    Write-Output "Started $Extension / $next using bound profile $($c.profile)."
} else {
    if ($c.workflow.phase -eq 'Draft') { $c.workflow.phase='Requirements' }
    if (!$c.workflow.next_action) { $c.workflow.next_action=$state.next_action }
    Write-Config (Join-Path $ext.Path 'extension.yaml') $c
    Write-Output "Resuming $Extension / $($c.workflow.current_iteration) at $($c.workflow.phase), using bound profile $($c.profile)."
}
Write-Output 'Ask only for missing items: change goal; current problem; user scenario; inputs; PLM click path; technical mount sequence; UI/interaction; data preview pattern; acceptance criteria; constraints; out of scope.'
Write-Output 'Do not design or implement until requirements are confirmed and prototype-preflight passes.'
Write-Output 'Loading applicable knowledge for discovery. Rerun with precise facets after requirements are confirmed.'
& "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $Extension -Facet Auto
