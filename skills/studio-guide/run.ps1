param([switch]$Json,[switch]$IncludeArchived)
. "$PSScriptRoot/../../scripts/Common.ps1"
$w=Get-Workspace
$profiles=@()
foreach($property in $w.Config.profiles.PSObject.Properties) {
    $id=$property.Name; $p=$property.Value
    $missing=@()
    foreach($key in @('project.id','project.name','product.name','product.version')) {
        $parts=$key.Split('.'); if ([string]::IsNullOrWhiteSpace([string]$p.($parts[0]).($parts[1]))) { $missing+=$key }
    }
    $profiles+=@([pscustomobject]@{
        id=$id;label=$(if ($p.label) {[string]$p.label} else {$id})
        project=$(if ($p.project.name) {[string]$p.project.name} else {'Unconfigured'})
        product=$(if ($p.product.name) {[string]$p.product.name+' '+[string]$p.product.version} else {'Unconfigured'})
        configuration=$(if ($missing.Count) {'Incomplete'} else {'Configured'});missing=$missing
    })
}

$extensions=@(); $warnings=@()
$extensionRoot=Join-Path $w.Path 'extensions'
if (Test-Path -LiteralPath $extensionRoot) {
    foreach($dir in Get-ChildItem -LiteralPath $extensionRoot -Directory | Sort-Object Name) {
        $configPath=Join-Path $dir.FullName 'extension.yaml'
        if (!(Test-Path -LiteralPath $configPath)) { $warnings+="Missing extension.yaml: $($dir.Name)"; continue }
        try {
            $state=Get-ExtensionGuideState $w (Read-Config $configPath)
            if ($IncludeArchived -or $state.lifecycle -ne 'Archived') { $extensions+=$state }
        } catch { $warnings+="$($dir.Name): $($_.Exception.Message)" }
    }
}
$extensions=@($extensions | Sort-Object project,product,profile,id)
$result=[ordered]@{workspace_id=$w.Id;profiles=$profiles;extensions=$extensions;warnings=$warnings;actions=@('NewExtension','ModifyExtension','ContinueExtension','WorkspaceStatus')}
if ($Json) { $result | ConvertTo-Json -Depth 20; return }

Write-Output "PLM-Studio: $($w.Id)"
Write-Output ''
Write-Output 'Profiles:'
foreach($p in $profiles) { Write-Output "- $($p.id): $($p.project) / $($p.product) / $($p.label) [$($p.configuration)]" }
Write-Output ''
Write-Output 'Selectable extensions:'
if (!$extensions.Count) { Write-Output '- (none)' }
$lastGroup=$null
foreach($e in $extensions) {
    $group="$($e.project) / $($e.product) / $($e.profile_label)"
    if ($group -ne $lastGroup) { Write-Output "`n$group"; $lastGroup=$group }
    Write-Output "- $($e.id) $($e.title) | $($e.iteration) | $($e.phase) | next=$($e.next_action)"
}
if ($warnings.Count) { Write-Output ''; Write-Output 'Warnings:'; $warnings | ForEach-Object { Write-Output "- $_" } }
Write-Output ''
Write-Output 'Choose: 1) new extension  2) modify any extension  3) continue unfinished extension  4) workspace status'
Write-Output 'State selects the guidance branch; it never removes an Active extension from selection.'
