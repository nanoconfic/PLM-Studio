function Get-ControllerDecision($W,$ExtensionConfig,[string]$Action) {
    $c=Initialize-ExtensionWorkflow $ExtensionConfig
    $phase=[string]$c.workflow.phase
    $stage=[string]$c.workflow.stage
    $mode=[string]$c.workflow.capability_mode
    $allowed=@()
    $reason=$null
    if ([string]$c.lifecycle.status -ne 'Active') {
        $reason='Extension lifecycle is not Active.'
    } elseif ($mode -notin @('legacy','prototype','integration','linked')) {
        $reason="Unknown capability mode: $mode"
    } elseif (($mode -eq 'prototype' -and $stage -ne 'prototype') -or ($mode -eq 'integration' -and $stage -ne 'integration') -or
        ($mode -eq 'linked' -and $stage -notin @('prototype','integration'))) {
        $reason="Invalid stage '$stage' for capability mode '$mode'."
    } elseif ($phase -notin @('Requirements','Draft','Implementation','ChangesRequested','PendingUserReview','Completed')) {
        $reason="Unknown workflow phase: $phase"
    } else {
        if ($phase -in @('Requirements','Draft')) {
            $allowed+=@('inspect_environment','inspect_knowledge','update_requirements')
            if ($c.workflow.delivery_confirmed -and [string]$c.delivery.mode -in @('static','static-demo','embedded-static','backend')) {
                $allowed+='confirm_requirements'
            }
            if ($c.workflow.requirements_confirmed -and $c.workflow.delivery_confirmed) { $allowed+='preflight' }
        }
        if ($phase -in @('Implementation','ChangesRequested')) {
            $allowed+=@('inspect_environment','inspect_knowledge')
            if ($phase -eq 'ChangesRequested') { $allowed+='update_requirements' }
            $readiness=$(if ($stage -eq 'integration' -and $mode -in @('integration','linked')) {
                @(Get-IntegrationReadinessIssues $W $c)
            } else { @(Get-PrototypeReadinessIssues $W $c) })
            if ($c.workflow.requirements_confirmed -and $c.workflow.delivery_confirmed -and @($readiness).Count -eq 0) {
                $allowed+=@('implement','deliver')
            }
        }
        if ($phase -eq 'PendingUserReview') { $allowed+='review' }
        if ($phase -eq 'Completed') { $allowed+='start_iteration' }
    }
    if ($Action -and $Action -notin $allowed) {
        if (!$reason) {
            $reason="Action '$Action' is blocked in phase '$phase' (requirements_confirmed=$($c.workflow.requirements_confirmed))."
        }
    }
    [pscustomobject]@{
        extension=[string]$c.id;iteration=[string]$c.workflow.current_iteration
        capability_mode=$mode;stage=$stage;phase=$phase;requirements_confirmed=[bool]$c.workflow.requirements_confirmed
        allowed=@($allowed);blocked=@((Get-WorkspaceActions) | Where-Object {$_ -notin $allowed})
        missing=@(Get-RequirementQuestions $c)
        action=$Action;permitted=(!$Action -or $Action -in $allowed);reason=$reason
    }
}
