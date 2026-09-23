param(
    [string]$Extension,
    [ValidateSet('inspect_workspace','create_extension','inspect_environment','inspect_knowledge','update_requirements','confirm_requirements','preflight','implement','deliver','review','start_iteration')][string]$Action,
    [switch]$Json
)
. "$PSScriptRoot/../tools/config/Common.ps1"
$w=Get-Workspace
if (!$Extension) {
    $entries=@()
    $extensionRoot=Join-Path $w.Path 'extensions'
    if (Test-Path -LiteralPath $extensionRoot) {
        foreach($dir in Get-ChildItem -LiteralPath $extensionRoot -Directory | Sort-Object Name) {
            $path=Join-Path $dir.FullName 'extension.yaml'
            if (!(Test-Path -LiteralPath $path)) { continue }
            $c=Initialize-ExtensionWorkflow (Read-Config $path)
            if ($c.lifecycle.status -eq 'Active') {
                $entries+=@([pscustomobject]@{id=$c.id;title=$c.title;capability_mode=$c.workflow.capability_mode;stage=$c.workflow.stage;phase=$c.workflow.phase})
            }
        }
    }
    $permitted=(!$Action -or $Action -in @('inspect_workspace','create_extension'))
    $overview=[pscustomobject]@{
        workspace=$w.Id;entry_modes=@('prototype','integration','linked');extensions=$entries
        allowed=@('inspect_workspace','create_extension','select_extension');action=$Action;permitted=$permitted
        next='Infer intent from natural language; select an active extension or create one with a capability mode.'
    }
    if ($Json) { $overview | ConvertTo-Json -Depth 10 }
    else {
        Write-Output "PLM-Studio: $($w.Id)"
        Write-Output '可选能力：原型设计 / 嵌入原产品 / 原型设计后嵌入'
        foreach($item in $entries) { Write-Output "- $($item.id): $($item.title) [$($item.capability_mode) / $($item.phase)]" }
    }
    if (!$permitted) { exit 2 }
    return
}
$ext=Get-Extension $w $Extension
$decision=Get-ControllerDecision $w $ext.Config $Action
if ($Json) {
    $decision | ConvertTo-Json -Depth 10
} else {
    Write-Output "$Extension / $($decision.iteration): $($decision.capability_mode) / $($decision.stage) / $($decision.phase)"
    Write-Output "requirements_confirmed: $($decision.requirements_confirmed.ToString().ToLowerInvariant())"
    Write-Output "allowed: $($decision.allowed -join ', ')"
    Write-Output "blocked: $($decision.blocked -join ', ')"
    if ($Action) { Write-Output "${Action}: $(if ($decision.permitted) {'allowed'} else {'blocked'})" }
    if ($decision.reason) { Write-Output "reason: $($decision.reason)" }
    if ($decision.missing.Count) { Write-Output '需补充：'; $decision.missing | ForEach-Object { Write-Output "- $_" } }
}
if ($Action -and !$decision.permitted) { exit 2 }
