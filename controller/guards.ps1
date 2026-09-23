function Assert-ControllerAction($W,$ExtensionConfig,[string]$Action) {
    $decision=Get-ControllerDecision $W $ExtensionConfig $Action
    if (!$decision.permitted) { throw "Workspace Controller: $($decision.reason)" }
    $decision
}
