param([switch]$Json,[switch]$IncludeArchived)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace
$profiles=@()
foreach($property in $w.Config.profiles.PSObject.Properties) {
    $id=$property.Name; $p=$property.Value
    $missing=@()
    foreach($key in @('label','product.name','product.version','deployment.mode')) {
        $parts=$key.Split('.'); $value=$(if ($parts.Count -eq 1) {$p.($parts[0])} else {$p.($parts[0]).($parts[1])}); if ([string]::IsNullOrWhiteSpace([string]$value)) { $missing+=$key }
    }
    $profiles+=@([pscustomobject]@{
        id=$id;label=$(if ($p.label) {[string]$p.label} else {$id})
        product=$(if ($p.product.name) {[string]$p.product.name+' '+[string]$p.product.version} else {'Unconfigured'})
        deployment_mode=$(if ($p.deployment.mode) {[string]$p.deployment.mode} else {'Unconfigured'})
        deployment_host=[string]$p.deployment.host
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
$extensions=@($extensions | Sort-Object product,profile,id)
$result=[ordered]@{workspace_id=$w.Id;profiles=$profiles;extensions=$extensions;warnings=$warnings;actions=@('NewExtension','ModifyExtension')}
if ($Json) { $result | ConvertTo-Json -Depth 20; return }

Write-Output "PLM-Studio: $($w.Id)"
Write-Output ''
Write-Output '当前扩展：'
if (!$extensions.Count) { Write-Output '- 暂无' }
foreach($e in $extensions) {
    Write-Output "- $($e.id): $($e.title)"
}
if ($warnings.Count) { Write-Output ''; Write-Output 'Warnings:'; $warnings | ForEach-Object { Write-Output "- $_" } }
Write-Output ''
Write-Output '请选择：1) 新增扩展  2) 修改现有扩展（或直接输入扩展 ID）'
