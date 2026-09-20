param([Parameter(Mandatory=$true)][string]$Extension)
. "$PSScriptRoot/../../scripts/Common.ps1"

$w=Get-Workspace
$ext=Get-Extension $w $Extension
$c=Initialize-ExtensionWorkflow $ext.Config
$matches=@(Get-ExactStyleKnowledgeMatches $w $c)
if ($matches.Count) {
    $c.style_context.status='knowledge-matched'
    $c.style_context.source='knowledge'
    $c.style_context.matched_knowledge_ids=@($matches | ForEach-Object {$_.id})
    $c.style_context.user_confirmed=$false
    $c.style_context.evidence=@($matches | ForEach-Object {$_.path})
    $c.style_context.confirmed_at=(Get-Date).ToUniversalTime().ToString('o')
    $c.style_context.basis="Exact PLM navigation path: $(Get-NormalizedNavigationPath $c.target.navigation_path)"
}

$issues=@(Get-PrototypeReadinessIssues $w $c)
if ($issues.Count) {
    Write-Output "Prototype preflight failed for ${Extension}:"
    $issues | ForEach-Object { Write-Output "- $_" }
    exit 2
}

$c.workflow.phase='Implementation'
$c.workflow.next_action='Implement the confirmed prototype using the resolved exact-path style context'
$c.status='Implementation'
Write-Config (Join-Path $ext.Path 'extension.yaml') $c
Write-Output "Prototype preflight passed for $Extension / $($c.workflow.current_iteration)."
Write-Output "Navigation path: $(Get-NormalizedNavigationPath $c.target.navigation_path)"
Write-Output "Style context: $($c.style_context.status) / $($c.style_context.source)"
if ($matches.Count) { Write-Output "Matched style knowledge: $(@($matches.id) -join ', ')" }
